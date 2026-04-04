CREATE OR REPLACE FUNCTION public.calculate_end_of_round_scores(p_room_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
    v_player RECORD;
    v_min_score INTEGER;
    v_new_dealer_id UUID;
    v_new_dealer_idx INTEGER;
    v_player_ids UUID[];
    v_winner_id UUID := NULL;
    v_round_tricks INTEGER;
    v_round_bid INTEGER;
    v_new_total INTEGER;
BEGIN
    -- 1. Update total_score for each player in the room based on the round results
    FOR v_player IN (SELECT * FROM public.players WHERE room_id = p_room_id) LOOP
        v_round_tricks := COALESCE(v_player.tricks_won, 0);
        v_round_bid := COALESCE(v_player.bid, 0);
        v_new_total := COALESCE(v_player.total_score, 0);
        
        -- Score Logic: Add or subtract ONLY the exact bid amount. No points for overtricks.
        IF v_round_bid > 0 THEN
            IF v_round_tricks >= v_round_bid THEN
               v_new_total := v_new_total + v_round_bid;
            ELSE
               v_new_total := v_new_total - v_round_bid;
            END IF;
            
            UPDATE public.players SET total_score = v_new_total WHERE id = v_player.id;
        END IF;
    END LOOP;

    -- 2. Check for Ultimate Winner (Score >= 31)
    SELECT id INTO v_winner_id FROM public.players 
    WHERE room_id = p_room_id AND total_score >= 31 
    ORDER BY total_score DESC LIMIT 1;

    IF v_winner_id IS NOT NULL THEN
        UPDATE public.rooms SET 
            winner_id = v_winner_id,
            status = 'game_over',
            current_phase = 'game_over'
        WHERE id = p_room_id;
        RETURN; -- Exit, game is officially over
    END IF;

    -- 3. Round 2+ Setup: Select New Dealer (Least Total Scorer)
    SELECT min(total_score) INTO v_min_score FROM public.players WHERE room_id = p_room_id;
    
    -- Pick one of the players with the minimum score (using joined_at as tie-breaker)
    SELECT id INTO v_new_dealer_id FROM public.players 
    WHERE room_id = p_room_id AND total_score = v_min_score 
    ORDER BY joined_at ASC LIMIT 1;

    -- Get ordered player list to find dealer index
    SELECT array_agg(id ORDER BY joined_at ASC) INTO v_player_ids FROM public.players WHERE room_id = p_room_id;
    
    FOR i IN 1..cardinality(v_player_ids) LOOP
        IF v_player_ids[i] = v_new_dealer_id THEN
            v_new_dealer_idx := i - 1;
        END IF;
    END LOOP;

    -- 4. Update the Room to 'summary' phase (to allow 5s scoreboard view)
    UPDATE public.rooms SET 
        status = 'summary',
        current_phase = 'summary',
        dealer_index = v_new_dealer_idx,
        turn_index = (v_new_dealer_idx + 1) % cardinality(v_player_ids), -- Next cutter is left of dealer
        current_round = current_round + 1,
        highest_bid = 0,
        highest_bidder_id = NULL,
        pass_count = 0,
        trump_suit = NULL,
        trump_locked = false,
        deck_ptr = 0
    WHERE id = p_room_id;
END;
$function$;
