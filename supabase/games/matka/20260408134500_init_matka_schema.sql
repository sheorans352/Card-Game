-- Init Matka Schema
-- Standing Rule: Schema Isolation (lib/games/matka owns the 'matka' schema)

CREATE SCHEMA IF NOT EXISTS matka;

-- 1. Rooms Table
CREATE TABLE IF NOT EXISTS matka.rooms (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  code text NOT NULL,
  status text NOT NULL DEFAULT 'waiting', -- waiting | dealing | betting | round_result | shuffling | ended
  host_id uuid, -- Settled after first player (host) joins
  deck_count integer NOT NULL DEFAULT 1,
  ante_amount integer NOT NULL DEFAULT 100,
  pot_amount integer NOT NULL DEFAULT 0,
  current_player_index integer NOT NULL DEFAULT 0,
  shoe text[] NOT NULL DEFAULT '{}',
  shoe_ptr integer NOT NULL DEFAULT 0,
  left_pillar text,
  right_pillar text,
  middle_card text,
  current_bet integer,
  round_number integer NOT NULL DEFAULT 1,
  created_at timestamptz DEFAULT now()
);

-- 2. Players Table
CREATE TABLE IF NOT EXISTS matka.players (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  room_id uuid REFERENCES matka.rooms(id) ON DELETE CASCADE,
  name text NOT NULL,
  net_chips integer NOT NULL DEFAULT 0,
  seat_index integer NOT NULL DEFAULT 0,
  is_host boolean NOT NULL DEFAULT false,
  is_ready boolean NOT NULL DEFAULT false,
  last_action text, -- pass | bet | win | loss | post
  last_bet_amount integer,
  joined_at timestamptz DEFAULT now()
);

-- 3. Add Host FK Constraint to Rooms
ALTER TABLE matka.rooms 
  ADD CONSTRAINT fk_host_player 
  FOREIGN KEY (host_id) REFERENCES matka.players(id) ON DELETE SET NULL;

-- 4. Rounds Table (History)
CREATE TABLE IF NOT EXISTS matka.rounds (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  room_id uuid REFERENCES matka.rooms(id) ON DELETE CASCADE,
  round_number integer NOT NULL,
  player_id uuid REFERENCES matka.players(id) ON DELETE SET NULL,
  left_pillar text NOT NULL,
  right_pillar text NOT NULL,
  middle_card text,
  bet_amount integer,
  result text, -- win | loss | post | pass
  chips_delta integer NOT NULL DEFAULT 0,
  created_at timestamptz DEFAULT now()
);

-- 5. Enable Row Level Security
ALTER TABLE matka.rooms ENABLE ROW LEVEL SECURITY;
ALTER TABLE matka.players ENABLE ROW LEVEL SECURITY;
ALTER TABLE matka.rounds ENABLE ROW LEVEL SECURITY;

-- 6. Staging/Dev Policies (Allow anonymous/authenticated access for rapid testing)
-- In production, these should be tightened based on room_id/auth.uid()
CREATE POLICY "Staging: Allow all operations on matka.rooms" ON matka.rooms FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "Staging: Allow all operations on matka.players" ON matka.players FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "Staging: Allow all operations on matka.rounds" ON matka.rounds FOR ALL USING (true) WITH CHECK (true);

-- 7. Schema Permissions
GRANT USAGE ON SCHEMA matka TO anon, authenticated, service_role;
GRANT ALL ON ALL TABLES IN SCHEMA matka TO anon, authenticated, service_role;
GRANT ALL ON ALL SEQUENCES IN SCHEMA matka TO anon, authenticated, service_role;
ALTER DEFAULT PRIVILEGES IN SCHEMA matka GRANT ALL ON TABLES TO anon, authenticated, service_role;
ALTER DEFAULT PRIVILEGES IN SCHEMA matka GRANT ALL ON SEQUENCES TO anon, authenticated, service_role;
