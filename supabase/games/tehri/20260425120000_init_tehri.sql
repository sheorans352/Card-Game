-- Tehri Game Schema
-- Following the pattern of public.matka_ suffix for staging compatibility

-- 1. CLEANUP
DROP TABLE IF EXISTS public.tehri_tricks CASCADE;
DROP TABLE IF EXISTS public.tehri_hands CASCADE;
DROP TABLE IF EXISTS public.tehri_players CASCADE;
DROP TABLE IF EXISTS public.tehri_rooms CASCADE;
DROP TABLE IF EXISTS public.tehri_shoes CASCADE;

-- 2. TABLES

-- Hidden table for the deck
CREATE TABLE public.tehri_shoes (
  room_id uuid PRIMARY KEY,
  shoe text[] NOT NULL,
  shoe_ptr integer NOT NULL DEFAULT 0,
  updated_at timestamptz DEFAULT now()
);

-- Main Rooms table
CREATE TABLE public.tehri_rooms (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  code text NOT NULL,
  status text NOT NULL DEFAULT 'waiting', -- waiting | dealing_initial | bidding_initial | dealing_remaining | bidding_final | playing | ended
  host_id uuid,
  dealer_id uuid,
  cutter_id uuid,
  current_bid integer DEFAULT 0,
  bidder_id uuid,
  trump_suit text, -- S | H | D | C
  current_turn_index integer NOT NULL DEFAULT 0,
  round_number integer NOT NULL DEFAULT 1,
  dealing_team_id integer, -- 0 or 1
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Players table
CREATE TABLE public.tehri_players (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  room_id uuid REFERENCES public.tehri_rooms(id) ON DELETE CASCADE,
  user_id uuid REFERENCES auth.users(id), -- If authenticated
  name text NOT NULL,
  seat_index integer NOT NULL, -- 0: Dealer, 1: Left (Cutter), 2: Partner, 3: Right
  team_index integer NOT NULL, -- 0: (0, 2), 1: (1, 3)
  points integer NOT NULL DEFAULT 0,
  tricks_won integer NOT NULL DEFAULT 0,
  is_host boolean NOT NULL DEFAULT false,
  is_ready boolean NOT NULL DEFAULT false,
  joined_at timestamptz DEFAULT now()
);

-- Private Hands (Security Definer access only)
CREATE TABLE public.tehri_hands (
  player_id uuid PRIMARY KEY REFERENCES public.tehri_players(id) ON DELETE CASCADE,
  cards text[] NOT NULL DEFAULT '{}'
);

-- Tricks table
CREATE TABLE public.tehri_tricks (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  room_id uuid REFERENCES public.tehri_rooms(id) ON DELETE CASCADE,
  trick_number integer NOT NULL,
  led_by uuid REFERENCES public.tehri_players(id),
  lead_suit text,
  cards text[] DEFAULT '{}', -- Array of card IDs played in order
  player_ids uuid[] DEFAULT '{}', -- Array of player IDs who played the cards
  winner_id uuid REFERENCES public.tehri_players(id),
  created_at timestamptz DEFAULT now()
);

-- 3. SECURITY & RLS

ALTER TABLE public.tehri_rooms ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tehri_players ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tehri_hands ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tehri_tricks ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tehri_shoes ENABLE ROW LEVEL SECURITY;

-- Deny direct access to shoes and hands via API
CREATE POLICY "Private: tehri_shoes hidden" ON public.tehri_shoes FOR ALL USING (false);
CREATE POLICY "Private: tehri_hands hidden" ON public.tehri_hands FOR ALL USING (false);

-- Open access for staging (standard tables)
CREATE POLICY "Staging: tehri_rooms allow all" ON public.tehri_rooms FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "Staging: tehri_players allow all" ON public.tehri_players FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "Staging: tehri_tricks allow all" ON public.tehri_tricks FOR ALL USING (true) WITH CHECK (true);

-- 4. RPCs (Security Definer)

-- Helper: Generate Shuffle Shoe
CREATE OR REPLACE FUNCTION public.tehri_generate_shoe() 
RETURNS text[] AS $$
DECLARE
  suits text[] := ARRAY['S', 'H', 'D', 'C'];
  ranks text[] := ARRAY['2', '3', '4', '5', '6', '7', '8', '9', '10', 'J', 'Q', 'K', 'A'];
  shoe text[] := ARRAY[]::text[];
  s text;
  r text;
BEGIN
  FOREACH s IN ARRAY suits LOOP
    FOREACH r IN ARRAY ranks LOOP
      shoe := array_append(shoe, r || s);
    END LOOP;
  END LOOP;
  SELECT array_agg(card) INTO shoe FROM (
    SELECT unnest(shoe) as card ORDER BY random()
  ) t;
  RETURN shoe;
END;
$$ LANGUAGE plpgsql;

-- RPC: Start Dealer Selection (J-Deal Phase)
-- This logic should be handled by the client or a simpler RPC that marks room as 'selecting_dealer'
-- and cards are dealt one by one until a J is found.

-- RPC: Initialize New Round
CREATE OR REPLACE FUNCTION public.tehri_init_round(rid uuid, did uuid)
RETURNS void AS $$
DECLARE
  new_shoe text[];
  pid uuid;
  cid uuid; -- cutter
BEGIN
  -- 1. Generate and save shoe
  new_shoe := public.tehri_generate_shoe();
  INSERT INTO public.tehri_shoes (room_id, shoe, shoe_ptr) 
  VALUES (rid, new_shoe, 0)
  ON CONFLICT (room_id) DO UPDATE SET shoe = EXCLUDED.shoe, shoe_ptr = 0;

  -- 2. Identify Cutter (Person Left of Dealer = (dealer_index + 1) % 4)
  SELECT id INTO cid FROM public.tehri_players 
  WHERE room_id = rid AND seat_index = (SELECT (seat_index + 1) % 4 FROM public.tehri_players WHERE id = did);

  -- 3. Reset player trick counts and hands
  UPDATE public.tehri_players SET tricks_won = 0 WHERE room_id = rid;
  DELETE FROM public.tehri_hands WHERE player_id IN (SELECT id FROM public.tehri_players WHERE room_id = rid);

  -- 4. Update Room
  UPDATE public.tehri_rooms SET 
    status = 'dealing_initial',
    dealer_id = did,
    cutter_id = cid,
    bidder_id = null,
    current_bid = 0,
    trump_suit = null,
    current_turn_index = (SELECT seat_index FROM public.tehri_players WHERE id = cid),
    dealing_team_id = (SELECT team_index FROM public.tehri_players WHERE id = did)
  WHERE id = rid;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- RPC: Deal Stage 1 (5 cards to everyone)
CREATE OR REPLACE FUNCTION public.tehri_deal_initial(rid uuid)
RETURNS void AS $$
DECLARE
  r record;
  s record;
  p record;
  card_subset text[];
  ptr int := 0;
BEGIN
  SELECT * INTO r FROM public.tehri_rooms WHERE id = rid FOR UPDATE;
  SELECT * INTO s FROM public.tehri_shoes WHERE room_id = rid FOR UPDATE;

  -- Deal 5 cards clockwise starting from cutter
  FOR i IN 0..3 LOOP
    -- Seat index logic: (r.current_turn_index + i) % 4
    SELECT * INTO p FROM public.tehri_players 
    WHERE room_id = rid AND seat_index = (r.current_turn_index + i) % 4;

    card_subset := s.shoe[ptr + 1 : ptr + 5];
    INSERT INTO public.tehri_hands (player_id, cards) VALUES (p.id, card_subset);
    ptr := ptr + 5;
  END LOOP;

  UPDATE public.tehri_shoes SET shoe_ptr = ptr WHERE room_id = rid;
  UPDATE public.tehri_rooms SET status = 'bidding_initial' WHERE id = rid;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- NEW: Deal Batch to a specific player (to support sequential UI)
CREATE OR REPLACE FUNCTION public.tehri_deal_batch(rid uuid, pid uuid, p_count int)
RETURNS void AS $$
DECLARE
  s record;
  card_subset text[];
BEGIN
  SELECT * INTO s FROM public.tehri_shoes WHERE room_id = rid FOR UPDATE;
  
  card_subset := s.shoe[s.shoe_ptr + 1 : s.shoe_ptr + p_count];
  
  INSERT INTO public.tehri_hands (player_id, cards) 
  VALUES (pid, card_subset)
  ON CONFLICT (player_id) DO UPDATE SET cards = tehri_hands.cards || EXCLUDED.cards;
  
  UPDATE public.tehri_shoes SET shoe_ptr = s.shoe_ptr + p_count WHERE room_id = rid;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- RPC: Finalize Initial Phase
CREATE OR REPLACE FUNCTION public.tehri_finish_initial_dealing(rid uuid)
RETURNS void AS $$
BEGIN
  UPDATE public.tehri_rooms SET status = 'bidding_initial' WHERE id = rid;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- RPC: Finalize Remaining Phase
CREATE OR REPLACE FUNCTION public.tehri_finish_dealing(rid uuid)
RETURNS void AS $$
DECLARE
  r record;
BEGIN
  SELECT * INTO r FROM public.tehri_rooms WHERE id = rid FOR UPDATE;
  UPDATE public.tehri_rooms SET 
    status = 'bidding_final',
    current_turn_index = (SELECT seat_index FROM public.tehri_players WHERE id = r.cutter_id)
  WHERE id = rid;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- RPC: Set Initial Bid (Cutter)
CREATE OR REPLACE FUNCTION public.tehri_set_initial_bid(rid uuid, pid uuid, bid int, trump text)
RETURNS void AS $$
BEGIN
  -- Validate Cutter
  IF NOT EXISTS (SELECT 1 FROM public.tehri_rooms WHERE id = rid AND cutter_id = pid) THEN
    RAISE EXCEPTION 'Only the cutter can set the initial bid';
  END IF;

  IF bid < 7 THEN
    RAISE EXCEPTION 'Minimum bid is 7';
  END IF;

  UPDATE public.tehri_rooms SET 
    current_bid = bid,
    bidder_id = pid,
    trump_suit = trump,
    status = 'dealing_remaining'
  WHERE id = rid;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- RPC: Deal Stage 2 & 3 (4 then 4)
CREATE OR REPLACE FUNCTION public.tehri_deal_remaining(rid uuid)
RETURNS void AS $$
DECLARE
  r record;
  s record;
  p record;
  card_subset text[];
  ptr int;
BEGIN
  SELECT * INTO r FROM public.tehri_rooms WHERE id = rid FOR UPDATE;
  SELECT * INTO s FROM public.tehri_shoes WHERE room_id = rid FOR UPDATE;
  ptr := s.shoe_ptr;

  -- Deal 4, then 4 (total 8 more)
  FOR j IN 1..2 LOOP
    FOR i IN 0..3 LOOP
      SELECT * INTO p FROM public.tehri_players 
      WHERE room_id = rid AND seat_index = (r.current_turn_index + i) % 4;

      card_subset := s.shoe[ptr + 1 : ptr + 4];
      UPDATE public.tehri_hands SET cards = cards || card_subset WHERE player_id = p.id;
      ptr := ptr + 4;
    END LOOP;
  END j;

  UPDATE public.tehri_shoes SET shoe_ptr = ptr WHERE room_id = rid;
  UPDATE public.tehri_rooms SET 
    status = 'bidding_final',
    current_turn_index = (SELECT seat_index FROM public.tehri_players WHERE id = r.cutter_id)
  WHERE id = rid;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- RPC: Place Final Bid
CREATE OR REPLACE FUNCTION public.tehri_place_bid(rid uuid, pid uuid, bid int, trump text)
RETURNS void AS $$
DECLARE
  r record;
  p record;
BEGIN
  SELECT * INTO r FROM public.tehri_rooms WHERE id = rid FOR UPDATE;
  SELECT * INTO p FROM public.tehri_players WHERE id = pid;

  IF r.status <> 'bidding_final' THEN
    RAISE EXCEPTION 'Not in bidding phase';
  END IF;

  IF p.seat_index <> r.current_turn_index THEN
    RAISE EXCEPTION 'Not your turn to bid';
  END IF;

  -- 0 means pass
  IF bid > 0 THEN
    IF bid <= r.current_bid THEN
      RAISE EXCEPTION 'Bid must be higher than %', r.current_bid;
    END IF;
    UPDATE public.tehri_rooms SET current_bid = bid, bidder_id = pid, trump_suit = trump WHERE id = rid;
  END IF;

  -- Move turn
  IF (r.current_turn_index + 1) % 4 = (SELECT seat_index FROM public.tehri_players WHERE id = r.cutter_id) THEN
    -- Bidding cycle complete
    UPDATE public.tehri_rooms SET 
      status = 'playing',
      current_turn_index = (SELECT seat_index FROM public.tehri_players WHERE id = bidder_id)
    WHERE id = rid;
  ELSE
    UPDATE public.tehri_rooms SET current_turn_index = (r.current_turn_index + 1) % 4 WHERE id = rid;
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- RPC: Play Card
CREATE OR REPLACE FUNCTION public.tehri_play_card(rid uuid, pid uuid, card_id text)
RETURNS void AS $$
DECLARE
  r record;
  tr record;
  p record;
  hand text[];
BEGIN
  SELECT * INTO r FROM public.tehri_rooms WHERE id = rid FOR UPDATE;
  SELECT * INTO p FROM public.tehri_players WHERE id = pid;
  
  IF r.status <> 'playing' THEN RAISE EXCEPTION 'Game not in playing state'; END IF;
  IF p.seat_index <> r.current_turn_index THEN RAISE EXCEPTION 'Not your turn'; END IF;

  -- 1. Check hand
  SELECT cards INTO hand FROM public.tehri_hands WHERE player_id = pid;
  IF NOT (card_id = ANY(hand)) THEN RAISE EXCEPTION 'Card not in hand'; END IF;

  -- 2. Get current trick
  SELECT * INTO tr FROM public.tehri_tricks 
  WHERE room_id = rid AND winner_id IS NULL 
  ORDER BY trick_number DESC LIMIT 1;

  IF tr IS NULL THEN
    -- Start NEW trick
    INSERT INTO public.tehri_tricks (room_id, trick_number, led_by, lead_suit, cards, player_ids)
    VALUES (rid, (SELECT coalesce(max(trick_number), 0) + 1 FROM public.tehri_tricks WHERE room_id = rid), pid, right(card_id, 1), ARRAY[card_id], ARRAY[pid]);
  ELSE
    -- Add to existing trick
    -- Validate Follow Suit (optional check if you want to enforce strict follow-suit logic here)
    -- ...
    UPDATE public.tehri_tricks SET 
      cards = array_append(cards, card_id),
      player_ids = array_append(player_ids, pid)
    WHERE id = tr.id;
    
    -- If 4 cards, resolve trick
    IF array_length(tr.cards, 1) = 3 THEN -- tr.cards is from before update
      PERFORM public.tehri_resolve_trick(tr.id);
      RETURN;
    END IF;
  END IF;

  -- Remove card from hand
  UPDATE public.tehri_hands SET cards = array_remove(hand, card_id) WHERE player_id = pid;
  
  -- Next turn
  UPDATE public.tehri_rooms SET current_turn_index = (r.current_turn_index + 1) % 4 WHERE id = rid;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Helper: Resolve Trick
CREATE OR REPLACE FUNCTION public.tehri_resolve_trick(tid uuid)
RETURNS void AS $$
DECLARE
  tr record;
  r record;
  best_card text;
  best_player uuid;
  current_card text;
  best_rank int := -1;
  current_rank int;
  is_trump boolean;
  trump_code text;
BEGIN
  SELECT * INTO tr FROM public.tehri_tricks WHERE id = tid;
  SELECT * INTO r FROM public.tehri_rooms WHERE id = tr.room_id;
  trump_code := r.trump_suit;

  FOR i IN 1..4 LOOP
    current_card := tr.cards[i];
    -- Rank logic (reusing standard A=14, K=13, etc)
    -- Simplified rank extraction for SQL:
    current_rank := CASE 
      WHEN left(current_card, 1) = 'A' THEN 14
      WHEN left(current_card, 1) = 'K' THEN 13
      WHEN left(current_card, 1) = 'Q' THEN 12
      WHEN left(current_card, 1) = 'J' THEN 11
      WHEN left(current_card, 2) = '10' THEN 10
      ELSE left(current_card, 1)::int
    END;

    is_trump := right(current_card, 1) = trump_code;

    IF i = 1 THEN
      best_card := current_card;
      best_player := tr.player_ids[i];
      best_rank := current_rank;
    ELSE
      -- Card is better if:
      -- 1. It is a trump and the previous best was not a trump
      -- 2. It is a trump and higher than previous best trump
      -- 3. It is same suit as lead and higher than previous best same-suit
      IF is_trump AND (right(best_card, 1) <> trump_code) THEN
        best_card := current_card;
        best_player := tr.player_ids[i];
        best_rank := current_rank;
      ELSIF is_trump AND (right(best_card, 1) = trump_code) AND (current_rank > best_rank) THEN
        best_card := current_card;
        best_player := tr.player_ids[i];
        best_rank := current_rank;
      ELSIF (right(current_card, 1) = tr.lead_suit) AND (right(best_card, 1) = tr.lead_suit) AND (current_rank > best_rank) THEN
        best_card := current_card;
        best_player := tr.player_ids[i];
        best_rank := current_rank;
      END IF;
    END IF;
  END LOOP;

  UPDATE public.tehri_tricks SET winner_id = best_player WHERE id = tid;
  UPDATE public.tehri_players SET tricks_won = tricks_won + 1 WHERE id = best_player;
  
  -- Next turn starts with winner
  UPDATE public.tehri_rooms SET 
    current_turn_index = (SELECT seat_index FROM public.tehri_players WHERE id = best_player)
  WHERE id = tr.room_id;

  -- If 13th trick, resolve round
  IF (SELECT count(*) FROM public.tehri_tricks WHERE room_id = tr.room_id AND winner_id IS NOT NULL) = 13 THEN
    PERFORM public.tehri_resolve_round(tr.room_id);
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Final Scoring Logic
CREATE OR REPLACE FUNCTION public.tehri_resolve_round(rid uuid)
RETURNS void AS $$
DECLARE
  r record;
  bidder record;
  bid_team int;
  is_dealing_team boolean;
  tricks_won_team int;
  score_delta int;
BEGIN
  SELECT * INTO r FROM public.tehri_rooms WHERE id = rid FOR UPDATE;
  SELECT * INTO bidder FROM public.tehri_players WHERE id = r.bidder_id;
  
  bid_team := bidder.team_index;
  is_dealing_team := (bid_team = r.dealing_team_id);
  
  SELECT sum(tricks_won) INTO tricks_won_team FROM public.tehri_players 
  WHERE room_id = rid AND team_index = bid_team;

  IF tricks_won_team >= r.current_bid THEN
    -- Success
    IF is_dealing_team THEN
      score_delta := -r.current_bid; -- Reduce dealing team's points
      UPDATE public.tehri_players SET points = points + score_delta WHERE room_id = rid AND team_index = bid_team;
    ELSE
      score_delta := r.current_bid; -- Increase dealing team's points
      UPDATE public.tehri_players SET points = points + score_delta WHERE room_id = rid AND team_index = r.dealing_team_id;
    END IF;
  ELSE
    -- Failure
    IF is_dealing_team THEN
      score_delta := 2 * r.current_bid; -- Increase dealing team's points
      UPDATE public.tehri_players SET points = points + score_delta WHERE room_id = rid AND team_index = bid_team;
    ELSE
      score_delta := -2 * r.current_bid; -- Decrease dealing team's points
      UPDATE public.tehri_players SET points = points + score_delta WHERE room_id = rid AND team_index = r.dealing_team_id;
    END IF;
  END IF;

  -- Check Win Condition
  IF EXISTS (SELECT 1 FROM public.tehri_players WHERE room_id = rid AND points >= 52) THEN
    UPDATE public.tehri_rooms SET status = 'ended' WHERE id = rid;
  ELSE
    -- Move to next dealer
    UPDATE public.tehri_rooms SET 
      dealer_id = (SELECT id FROM public.tehri_players WHERE room_id = rid AND seat_index = (SELECT (seat_index + 1) % 4 FROM public.tehri_players WHERE id = r.dealer_id)),
      status = 'waiting' -- Return to waiting or directly to next round
    WHERE id = rid;
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 5. ENABLE REALTIME
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_publication WHERE pubname = 'supabase_realtime') THEN
    CREATE PUBLICATION supabase_realtime;
  END IF;
  
  ALTER PUBLICATION supabase_realtime ADD TABLE 
    public.tehri_rooms, 
    public.tehri_players, 
    public.tehri_tricks;
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;
