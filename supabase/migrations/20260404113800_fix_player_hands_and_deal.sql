CREATE OR REPLACE FUNCTION public.select_trump(p_room_id uuid, p_player_id uuid, p_suit text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
    v_room RECORD;
    v_player_ids UUID[];
BEGIN
    SELECT * INTO v_room FROM public.rooms WHERE id = p_room_id FOR UPDATE;
    
    -- Optimistic lock
    IF v_room.status != 'trump_selection' THEN 
        RETURN jsonb_build_object('success', false, 'error', 'Not in trump selection phase'); 
    END IF;

    -- Fetch players to check turn
    SELECT array_agg(id ORDER BY joined_at ASC, id ASC) INTO v_player_ids
    FROM public.players WHERE room_id = p_room_id;

    -- Check if it's the winner's turn
    IF v_player_ids[v_room.turn_index + 1] != p_player_id THEN
        RETURN jsonb_build_object('success', false, 'error', 'Not your turn');
    END IF;

    -- Check if hands are already full (Scenario B override)
    IF (SELECT count(*) FROM public.hands WHERE room_id = p_room_id) >= 52 THEN
        UPDATE public.rooms SET
            status = 'playing',
            current_phase = 'playing',
            trump_suit = p_suit,
            highest_bidder_id = NULL
        WHERE id = p_room_id;
    ELSE
        -- Scenario A: Start sequential dealing
        UPDATE public.rooms SET
            status = 'dealing_phase_2',
            current_phase = 'dealing_phase_2',
            trump_suit = p_suit
        WHERE id = p_room_id;
    END IF;

    RETURN jsonb_build_object('success', true);
END;
$function$;

CREATE OR REPLACE FUNCTION public.start_deal_round(p_room_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
    v_deck text[];
    v_player_ids uuid[];
    v_dealer_idx int;
    v_p_idx int;
    v_hand_size int := 5;
    v_curr_round int;
    v_deck_ptr int := 0;
BEGIN
    -- Get room state
    SELECT shuffled_deck, current_round 
    INTO v_deck, v_curr_round
    FROM rooms WHERE id = p_room_id;

    -- Get players ordered by join time
    SELECT array_agg(id ORDER BY joined_at ASC) INTO v_player_ids FROM players WHERE room_id = p_room_id;

    -- For FIRST ROUND: Dealer is the Host (first person, index 0)
    IF v_curr_round = 1 THEN
        v_dealer_idx := 0;
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

CREATE OR REPLACE FUNCTION public.deal_phase_2(p_room_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
    v_room rooms%ROWTYPE;
    v_player_ids UUID[];
    v_deck TEXT[];
    v_dealer_idx INTEGER;
    v_player_id UUID;
    v_p_idx INTEGER;
    v_i INTEGER;
BEGIN
    SELECT * INTO v_room FROM rooms WHERE id = p_room_id;
    v_deck := v_room.shuffled_deck;
    v_player_ids := ARRAY(SELECT id FROM players WHERE room_id = p_room_id ORDER BY joined_at ASC, id ASC);
    v_dealer_idx := v_room.dealer_index;

    -- Deal 4 cards from index 21 to 36
    FOR v_i IN 0..3 LOOP
        v_p_idx := (v_dealer_idx + 1 + v_i) % 4;
        v_player_id := v_player_ids[v_p_idx + 1];
        INSERT INTO hands (room_id, player_id, card_value, round_number)
        SELECT p_room_id, v_player_id, val, v_room.current_round
        FROM unnest(v_deck[(20 + v_i * 4 + 1) : (20 + v_i * 4 + 4)]) as val;
    END LOOP;

    UPDATE rooms SET status = 'bidding_2', current_phase = 'bidding_2', 
                   pass_count = 0, turn_index = (v_dealer_idx + 1) % 4
    WHERE id = p_room_id;
END;
$function$;

CREATE OR REPLACE FUNCTION public.deal_phase_3(p_room_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
    v_room rooms%ROWTYPE;
    v_player_ids UUID[];
    v_deck TEXT[];
    v_dealer_idx INTEGER;
    v_player_id UUID;
    v_p_idx INTEGER;
    v_i INTEGER;
BEGIN
    SELECT * INTO v_room FROM rooms WHERE id = p_room_id;
    v_deck := v_room.shuffled_deck;
    v_player_ids := ARRAY(SELECT id FROM players WHERE room_id = p_room_id ORDER BY joined_at ASC, id ASC);
    v_dealer_idx := v_room.dealer_index;

    -- Deal final 4 cards from index 37 to 52
    FOR v_i IN 0..3 LOOP
        v_p_idx := (v_dealer_idx + 1 + v_i) % 4;
        v_player_id := v_player_ids[v_p_idx + 1];
        INSERT INTO hands (room_id, player_id, card_value, round_number)
        SELECT p_room_id, v_player_id, val, v_room.current_round
        FROM unnest(v_deck[(36 + v_i * 4 + 1) : (36 + v_i * 4 + 4)]) as val;
    END LOOP;

    UPDATE rooms SET status = 'playing', current_phase = 'playing',
                   turn_index = (v_dealer_idx + 1) % 4, pass_count = 0
    WHERE id = p_room_id;
END;
$function$;

CREATE OR REPLACE FUNCTION public.deal_rest_cards(p_room_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
    v_room rooms%ROWTYPE;
    v_player_ids UUID[];
    v_i INTEGER;
    v_p_idx INTEGER;
    v_round INTEGER;
BEGIN
    SELECT * INTO v_room FROM rooms WHERE id = p_room_id;
    v_player_ids := ARRAY(SELECT id FROM players WHERE room_id = p_room_id ORDER BY joined_at ASC, id ASC);
    v_round := v_room.current_round;

    -- Phase 2 (4 cards each)
    FOR v_i IN 0..3 LOOP
        v_p_idx := (v_room.dealer_index + 1 + v_i) % 4;
        INSERT INTO hands (room_id, player_id, card_value, round_number)
        SELECT p_room_id, v_player_ids[v_p_idx + 1], val, v_round
        FROM unnest(v_room.shuffled_deck[21 + v_i*4 : 24 + v_i*4]) as val;
    END LOOP;

    -- Phase 3 (4 cards each)
    FOR v_i IN 0..3 LOOP
        v_p_idx := (v_room.dealer_index + 1 + v_i) % 4;
        INSERT INTO hands (room_id, player_id, card_value, round_number)
        SELECT p_room_id, v_player_ids[v_p_idx + 1], val, v_round
        FROM unnest(v_room.shuffled_deck[37 + v_i*4 : 40 + v_i*4]) as val;
    END LOOP;
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
    v_new_total INTEGER;
    v_lowest_score INTEGER := 9999;
    v_new_dealer_id UUID;
    v_player_ids UUID[];
BEGIN
    SELECT * INTO v_room FROM rooms WHERE id = p_room_id FOR UPDATE;
    
    FOR v_player IN (SELECT * FROM players WHERE room_id = p_room_id) LOOP
        v_new_total := v_player.total_score + v_player.round_score;
        
        UPDATE players SET 
            total_score = v_new_total,
            bid = NULL,
            tricks_won = 0,
            round_score = 0,
            trump_bid_passed = FALSE,
            is_ready = FALSE
        WHERE id = v_player.id;
        
        IF v_new_total < v_lowest_score THEN
            v_lowest_score := v_new_total;
            v_new_dealer_id := v_player.id;
        END IF;
    END LOOP;

    v_player_ids := ARRAY(SELECT id FROM players WHERE room_id = p_room_id ORDER BY joined_at ASC, id ASC);
    
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
