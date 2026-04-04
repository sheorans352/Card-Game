CREATE OR REPLACE FUNCTION public.start_deal_round(p_room_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
    v_player_ids uuid[];
    v_dealer_idx int;
    v_host_id uuid;
    v_curr_round int;
BEGIN
    SELECT current_round, host_id INTO v_curr_round, v_host_id FROM rooms WHERE id = p_room_id;

    SELECT array_agg(id ORDER BY joined_at ASC, id ASC) INTO v_player_ids FROM players WHERE room_id = p_room_id;

    -- For FIRST ROUND: Dealer is the Host
    IF v_curr_round = 1 THEN
        v_dealer_idx := array_position(v_player_ids, v_host_id) - 1;
    ELSE
        SELECT dealer_index INTO v_dealer_idx FROM rooms WHERE id = p_room_id;
    END IF;

    DELETE FROM hands WHERE room_id = p_room_id;
    DELETE FROM played_cards WHERE room_id = p_room_id;

    UPDATE rooms SET 
        status = 'dealing_phase_1',
        current_phase = 'dealing_phase_1',
        deck_ptr = 0,
        highest_bid = 0,
        highest_bidder_id = NULL,
        pass_count = 0,
        dealer_index = v_dealer_idx,
        turn_index = (v_dealer_idx + 1) % 4
    WHERE id = p_room_id;
    
    UPDATE players SET bid = NULL, trump_bid_passed = FALSE, tricks_won = 0, round_score = 0 WHERE room_id = p_room_id;
END;
$function$;

CREATE OR REPLACE FUNCTION public.finish_phase_1_dealing(p_room_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
BEGIN
    UPDATE rooms SET 
        status = 'bidding',
        current_phase = 'bidding'
    WHERE id = p_room_id;
END;
$function$;
