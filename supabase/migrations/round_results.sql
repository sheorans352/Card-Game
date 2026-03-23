-- Create round_results table to track historical bids and scores
CREATE TABLE IF NOT EXISTS public.round_results (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    room_id UUID REFERENCES public.rooms(id) ON DELETE CASCADE,
    round_number INT NOT NULL,
    player_id UUID REFERENCES public.players(id) ON DELETE CASCADE,
    bid INT NOT NULL,
    tricks_won INT NOT NULL,
    score_change INT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

-- Enable Realtime for scores
ALTER PUBLICATION supabase_realtime ADD TABLE round_results;
