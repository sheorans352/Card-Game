CREATE OR REPLACE FUNCTION public.start_deal_round(p_room_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
    v_deck text[];
    v_player_ids uuid[];
    v_dealer_idx int;
    v_host_id uuid;
    v_p_idx int;
    v_hand_size int := 5;
    v_curr_round int;
    v_deck_ptr int := 0;
BEGIN
    -- Get room state
    SELECT shuffled_deck, current_round, host_id
    INTO v_deck, v_curr_round, v_host_id
    FROM rooms WHERE id = p_room_id;

    -- Get players ordered by join time
    SELECT array_agg(id ORDER BY joined_at ASC, id ASC) INTO v_player_ids FROM players WHERE room_id = p_room_id;

    -- For FIRST ROUND: Dealer is the Host
    IF v_curr_round = 1 THEN
        v_dealer_idx := array_position(v_player_ids, v_host_id) - 1;
    ELSE
        -- For subsequent rounds, dealer is set by score calculation logic
        SELECT dealer_index INTO v_dealer_idx FROM rooms WHERE id = p_room_id;
    END IF;

    -- Clear existing hands for this room
    DELETE FROM hands WHERE room_id = p_room_id;
    DELETE FROM played_cards WHERE room_id = p_room_id;

    -- Initial Deal (5 cards each) starting with the Cutter (left of dealer)
    FOR i IN 0..3 LOOP
        v_p_idx := (v_dealer_idx + 1 + i) % 4;
        FOR j IN 1..v_hand_size LOOP
            INSERT INTO hands (room_id, player_id, card_value, round_number)
            VALUES (p_room_id, v_player_ids[v_p_idx + 1], v_deck[v_deck_ptr+1], v_curr_round);
            v_deck_ptr := v_deck_ptr + 1;
        END LOOP;
    END LOOP;

    -- Update room state
    UPDATE rooms SET 
        status = 'bidding',
        current_phase = 'bidding',
        deck_ptr = v_deck_ptr,
        highest_bid = 0,
        highest_bidder_id = NULL,
        pass_count = 0,
        dealer_index = v_dealer_idx, -- Save the newly assigned dealer
        turn_index = (v_dealer_idx + 1) % 4 -- Cutter is left of dealer and bids first
    WHERE id = p_room_id;
END;
$function$;

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
BEGIN
    SELECT * INTO v_room FROM rooms WHERE id = p_room_id FOR UPDATE;
    
    v_player_ids := ARRAY(SELECT id FROM players WHERE room_id = p_room_id ORDER BY joined_at ASC, id ASC);
    v_new_dealer_id := v_player_ids[v_room.dealer_index + 1];

    -- Initialize lowest score with the current dealer's score so they win ties
    SELECT (total_score + round_score) INTO v_lowest_score 
    FROM players WHERE id = v_new_dealer_id;
    
    FOR v_player IN (SELECT *, (total_score + round_score) as new_s FROM players WHERE room_id = p_room_id) LOOP
        UPDATE players SET 
            total_score = new_s,
            bid = NULL,
            tricks_won = 0,
            round_score = 0,
            trump_bid_passed = FALSE,
            is_ready = FALSE
        WHERE id = v_player.id;
        
        IF v_player.new_s < v_lowest_score THEN
            v_lowest_score := v_player.new_s;
            v_new_dealer_id := v_player.id;
        END IF;
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


CREATE OR REPLACE FUNCTION public.finish_dealing(p_room_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
    v_room RECORD;
    v_cutter_idx int;
    v_turn_index int;
    v_player_ids UUID[];
BEGIN
    SELECT * INTO v_room FROM rooms WHERE id = p_room_id;
    
    SELECT array_agg(id ORDER BY joined_at ASC, id ASC) INTO v_player_ids
    FROM players WHERE room_id = p_room_id;

    v_cutter_idx := (v_room.dealer_index + 1) % 4;
    
    IF v_player_ids[v_cutter_idx + 1] = v_room.highest_bidder_id AND v_room.highest_bid >= 5 THEN
        -- Cutter was the highest bidder and bid >= 5, so start from player next to him
        v_turn_index := (v_cutter_idx + 1) % 4;
    ELSE
        -- Otherwise start from him (the cutter)
        v_turn_index := v_cutter_idx;
    END IF;

    UPDATE rooms SET 
        status = 'bidding_2',
        current_phase = 'bidding_2',
        pass_count = 0,
        turn_index = v_turn_index
    WHERE id = p_room_id;
END;
$function$;
