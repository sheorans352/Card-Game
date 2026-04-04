CREATE OR REPLACE FUNCTION public.end_round(p_room_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
    v_room RECORD;
    v_player RECORD;
    v_lowest_score INTEGER;
    v_new_dealer_id UUID;
    v_player_ids UUID[];
    v_round_tricks INTEGER;
    v_round_bid INTEGER;
    v_new_total INTEGER;
BEGIN
    SELECT * INTO v_room FROM rooms WHERE id = p_room_id FOR UPDATE;
    
    v_player_ids := ARRAY(SELECT id FROM players WHERE room_id = p_room_id ORDER BY joined_at ASC, id ASC);
    v_new_dealer_id := v_player_ids[v_room.dealer_index + 1];

    -- Initialize lowest score with an arbitrarily high number
    v_lowest_score := 999999;
    
    FOR v_player IN (SELECT * FROM players WHERE room_id = p_room_id) LOOP
        v_round_tricks := COALESCE(v_player.tricks_won, 0);
        v_round_bid := COALESCE(v_player.bid, 0);
        v_new_total := COALESCE(v_player.total_score, 0);
        
        -- Score Logic: 10 points per trick bid + 1 point for extra trick
        -- If tricks < bid, lose 10 points per trick bid
        IF v_round_bid > 0 THEN
            IF v_round_tricks >= v_round_bid THEN
               v_new_total := v_new_total + (10 * v_round_bid) + (v_round_tricks - v_round_bid);
            ELSE
               v_new_total := v_new_total - (10 * v_round_bid);
            END IF;
        END IF;

        IF v_new_total < v_lowest_score THEN
            v_lowest_score := v_new_total;
            v_new_dealer_id := v_player.id;
        END IF;

        UPDATE players SET 
            total_score = v_new_total,
            bid = NULL,
            tricks_won = 0,
            trump_bid_passed = FALSE,
            is_ready = FALSE
        WHERE id = v_player.id;
    END LOOP;
    
    UPDATE rooms SET
        status = 'shuffling',
        current_phase = 'shuffling',
        current_round = v_room.current_round + 1,
        dealer_index = array_position(v_player_ids, v_new_dealer_id) - 1,
        trump_suit = NULL,
        trump_locked = FALSE,
        highest_bid = 0,
        highest_bidder_id = NULL,
        pass_count = 0,
        deck_cut_value = NULL,
        turn_index = (array_position(v_player_ids, v_new_dealer_id)) % 4
    WHERE id = p_room_id;

    DELETE FROM played_cards WHERE room_id = p_room_id;
    DELETE FROM hands WHERE room_id = p_room_id;
END;
$function$;
