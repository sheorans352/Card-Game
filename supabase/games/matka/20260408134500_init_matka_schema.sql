-- Pivot to Public Schema with prefixes + Anti-Cheat RPCs
-- This replaces the old 'matka' schema setup to fix 'invalid schema' errors on staging.

-- 1. CLEANUP (Optional/Staging Only)
DROP TABLE IF EXISTS public.matka_rounds CASCADE;
DROP TABLE IF EXISTS public.matka_players CASCADE;
DROP TABLE IF EXISTS public.matka_rooms CASCADE;
DROP TABLE IF EXISTS public.matka_shoes CASCADE;

-- 2. PUBLIC TABLES (Prefixed)

-- Hidden table for the deck (No public access!)
CREATE TABLE public.matka_shoes (
  room_id uuid PRIMARY KEY,
  shoe text[] NOT NULL,
  shoe_ptr integer NOT NULL DEFAULT 0,
  updated_at timestamptz DEFAULT now()
);

-- Public rooms table (Excludes 'shoe')
CREATE TABLE public.matka_rooms (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  code text NOT NULL,
  status text NOT NULL DEFAULT 'waiting', -- waiting | betting | round_result | shuffling | ended
  host_id uuid,
  deck_count integer NOT NULL DEFAULT 1,
  ante_amount integer NOT NULL DEFAULT 100,
  pot_amount integer NOT NULL DEFAULT 0,
  current_player_index integer NOT NULL DEFAULT 0,
  left_pillar text,
  right_pillar text,
  middle_card text,
  current_bet integer,
  round_number integer NOT NULL DEFAULT 1,
  created_at timestamptz DEFAULT now()
);

-- Public players table
CREATE TABLE public.matka_players (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  room_id uuid REFERENCES public.matka_rooms(id) ON DELETE CASCADE,
  name text NOT NULL,
  net_chips integer NOT NULL DEFAULT 0,
  seat_index integer NOT NULL DEFAULT 0,
  is_host boolean NOT NULL DEFAULT false,
  is_ready boolean NOT NULL DEFAULT false,
  last_action text, -- pass | bet | win | loss | post
  last_bet_amount integer,
  joined_at timestamptz DEFAULT now()
);

ALTER TABLE public.matka_rooms 
  ADD CONSTRAINT fk_host_player 
  FOREIGN KEY (host_id) REFERENCES public.matka_players(id) ON DELETE SET NULL;

-- Public rounds table
CREATE TABLE public.matka_rounds (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  room_id uuid REFERENCES public.matka_rooms(id) ON DELETE CASCADE,
  round_number integer NOT NULL,
  player_id uuid REFERENCES public.matka_players(id) ON DELETE SET NULL,
  left_pillar text NOT NULL,
  right_pillar text NOT NULL,
  middle_card text,
  bet_amount integer,
  result text, 
  chips_delta integer NOT NULL DEFAULT 0,
  created_at timestamptz DEFAULT now()
);

-- 3. SECURITY & POLICIES

ALTER TABLE public.matka_rooms ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.matka_players ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.matka_rounds ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.matka_shoes ENABLE ROW LEVEL SECURITY;

-- Deny all direct access to matka_shoes via API
CREATE POLICY "Private: matka_shoes is hidden" ON public.matka_shoes FOR ALL USING (false);

-- Open access for staging (standard tables)
CREATE POLICY "Staging: matka_rooms allow all" ON public.matka_rooms FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "Staging: matka_players allow all" ON public.matka_players FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "Staging: matka_rounds allow all" ON public.matka_rounds FOR ALL USING (true) WITH CHECK (true);

-- 4. ANTI-CHEAT RPCS (Security Definer)

-- Helper: Build Shoe (Array of 52 * count cards)
CREATE OR REPLACE FUNCTION public.matka_generate_shoe(deck_count int) 
RETURNS text[] AS $$
DECLARE
  suits text[] := ARRAY['S', 'H', 'D', 'C'];
  ranks text[] := ARRAY['2', '3', '4', '5', '6', '7', '8', '9', '10', 'J', 'Q', 'K', 'A'];
  shoe text[] := ARRAY[]::text[];
  i int;
  s text;
  r text;
BEGIN
  FOR i IN 1..deck_count LOOP
    FOREACH s IN ARRAY suits LOOP
      FOREACH r IN ARRAY ranks LOOP
        shoe := array_append(shoe, r || s);
      END LOOP;
    END LOOP;
  END LOOP;
  -- Simple Fish-Yates shuffle approximation using ORDER BY random()
  SELECT array_agg(card) INTO shoe FROM (
    SELECT unnest(shoe) as card ORDER BY random()
  ) t;
  RETURN shoe;
END;
$$ LANGUAGE plpgsql;

-- 5. RPC: Initialize Game
CREATE OR REPLACE FUNCTION public.matka_init_game(rid uuid, pid uuid)
RETURNS void AS $$
DECLARE
  r record;
  p_count int;
  total_ante int;
  new_shoe text[];
BEGIN
  -- 1. Auth check: pid must be host of rid
  IF NOT EXISTS (SELECT 1 FROM public.matka_players WHERE id = pid AND room_id = rid AND is_host = true) THEN
    RAISE EXCEPTION 'Unauthorized: Only host can start game';
  END IF;

  SELECT * INTO r FROM public.matka_rooms WHERE id = rid FOR UPDATE;
  SELECT count(*) INTO p_count FROM public.matka_players WHERE room_id = rid;
  total_ante := r.ante_amount * p_count;

  -- 2. Collect antes
  UPDATE public.matka_players SET net_chips = net_chips - r.ante_amount, is_ready = true 
  WHERE room_id = rid;

  -- 3. Generate Shoe
  new_shoe := public.matka_generate_shoe(r.deck_count);
  INSERT INTO public.matka_shoes (room_id, shoe, shoe_ptr) 
  VALUES (rid, new_shoe, 2) 
  ON CONFLICT (room_id) DO UPDATE SET shoe = EXCLUDED.shoe, shoe_ptr = 2;

  -- 4. Update Room with first pillars
  UPDATE public.matka_rooms SET 
    pot_amount = pot_amount + total_ante,
    current_player_index = 0,
    left_pillar = new_shoe[1],
    right_pillar = new_shoe[2],
    middle_card = null,
    current_bet = null,
    status = 'betting'
  WHERE id = rid;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 6. RPC: Draw Middle Card
CREATE OR REPLACE FUNCTION public.matka_draw_card(rid uuid, pid uuid, bet int)
RETURNS text AS $$
DECLARE
  r record;
  s record;
  middle_card text;
BEGIN
  -- 1. Get room and shoe
  SELECT * INTO r FROM public.matka_rooms WHERE id = rid FOR UPDATE;
  SELECT * INTO s FROM public.matka_shoes WHERE room_id = rid FOR UPDATE;

  -- 2. Draw card
  middle_card := s.shoe[s.shoe_ptr + 1];
  
  -- 3. Update hidden shoe ptr
  UPDATE public.matka_shoes SET shoe_ptr = shoe_ptr + 1 WHERE room_id = rid;

  -- 4. Update room middle card (client will see it now)
  -- Note: We don't advance the turn here; the client logic or another RPC handles result evaluation for now.
  -- To make it 100% secure, result evaluation should also be in RPC, but let's start here.
  UPDATE public.matka_rooms SET 
    middle_card = middle_card,
    current_bet = bet,
    status = 'round_result'
  WHERE id = rid;

  RETURN middle_card;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 7. RPC: Reshuffle
CREATE OR REPLACE FUNCTION public.matka_reshuffle(rid uuid, pid uuid, new_decks int)
RETURNS void AS $$
DECLARE
  new_shoe text[];
BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.matka_players WHERE id = pid AND room_id = rid AND is_host = true) THEN
    RAISE EXCEPTION 'Unauthorized';
  END IF;

  new_shoe := public.matka_generate_shoe(new_decks);
  INSERT INTO public.matka_shoes (room_id, shoe, shoe_ptr) 
  VALUES (rid, new_shoe, 2) 
  ON CONFLICT (room_id) DO UPDATE SET shoe = EXCLUDED.shoe, shoe_ptr = 2;

  UPDATE public.matka_rooms SET 
    deck_count = new_decks,
    left_pillar = new_shoe[1],
    right_pillar = new_shoe[2],
    middle_card = null,
    current_bet = null,
    status = 'betting'
  WHERE id = rid;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 8. ENABLE REALTIME
-- This is critical for Flutter's .stream() to receive updates when players join or game state changes.
-- We rebuild the publication to ensure it exists and has these tables.
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_publication WHERE pubname = 'supabase_realtime') THEN
    CREATE PUBLICATION supabase_realtime;
  END IF;
  
  ALTER PUBLICATION supabase_realtime ADD TABLE 
    public.matka_rooms, 
    public.matka_players, 
    public.matka_rounds;
EXCEPTION
  WHEN duplicate_object THEN NULL; -- Table already in publication
END $$;
