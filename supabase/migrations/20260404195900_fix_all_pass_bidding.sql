CREATE OR REPLACE FUNCTION public.place_bid(p_room_id uuid, p_player_id uuid, p_bid integer)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
    v_room RECORD;
    v_player_count INTEGER;
    v_new_pass_count INTEGER;
    v_player_ids UUID[];
    v_next_turn INTEGER;
    v_highest_bidder UUID;
    v_i INTEGER;
    v_is_passed BOOLEAN;
BEGIN
    -- Get room state with lock
    SELECT * INTO v_room FROM rooms WHERE id = p_room_id FOR UPDATE;
    IF NOT FOUND THEN RAISE EXCEPTION 'Room not found'; END IF;

    -- Get all player IDs in joined order
    v_player_ids := ARRAY(SELECT id FROM players WHERE room_id = p_room_id ORDER BY joined_at ASC, id ASC);
    v_player_count := array_length(v_player_ids, 1);

    -- PHASE 1: TRUMP SELECTION BIDDING (status = 'bidding')
    IF v_room.status = 'bidding' THEN
        IF p_bid = 0 THEN
            UPDATE players SET trump_bid_passed = TRUE WHERE id = p_player_id;
        ELSE
            IF p_bid <= v_room.highest_bid THEN RAISE EXCEPTION 'Bid must be higher than %', v_room.highest_bid; END IF;
            UPDATE rooms SET highest_bid = p_bid, highest_bidder_id = p_player_id WHERE id = p_room_id;
        END IF;

        -- Recalculate true pass count
        SELECT COUNT(*) INTO v_new_pass_count FROM players WHERE room_id = p_room_id AND trump_bid_passed = TRUE;

        -- Transition Check
        IF v_new_pass_count >= 3 AND (SELECT highest_bid FROM rooms WHERE id = p_room_id) > 0 THEN
            -- 3 Passed, 1 Winner -> Select Trump
            SELECT highest_bidder_id INTO v_highest_bidder FROM rooms WHERE id = p_room_id;
            UPDATE rooms SET 
                status = 'trump_selection', 
                current_phase = 'trump_selection',
                pass_count = v_new_pass_count,
                turn_index = (array_position(v_player_ids, v_highest_bidder) - 1)
            WHERE id = p_room_id;
        ELSIF v_new_pass_count >= 4 THEN
            -- ALL PASSED -> SPADES DEFAULT
            UPDATE rooms SET 
                status = 'dealing_phase_2', 
                current_phase = 'dealing_phase_2',
                trump_suit = 'S',
                pass_count = 0,
                highest_bid = 0,
                highest_bidder_id = NULL
            WHERE id = p_room_id;
            
            UPDATE players SET bid = NULL, trump_bid_passed = FALSE WHERE room_id = p_room_id;
        ELSE
            -- Next player who hasn't passed
            v_next_turn := (v_room.turn_index + 1) % v_player_count;
            FOR v_i IN 1..4 LOOP
                SELECT trump_bid_passed INTO v_is_passed FROM players WHERE id = v_player_ids[v_next_turn + 1];
                IF NOT v_is_passed THEN EXIT; END IF;
                v_next_turn := (v_next_turn + 1) % v_player_count;
            END LOOP;
            
            UPDATE rooms SET turn_index = v_next_turn, pass_count = v_new_pass_count WHERE id = p_room_id;
        END IF;

    -- PHASE 2: TRICK DECLARATION (status = 'bidding_2')
    ELSIF v_room.status = 'bidding_2' THEN
        IF p_bid < 1 THEN RAISE EXCEPTION 'Must declare at least 1 trick'; END IF;
        
        UPDATE players SET bid = p_bid WHERE id = p_player_id;
        v_new_pass_count := v_room.pass_count + 1;

        IF v_new_pass_count >= (CASE WHEN v_room.highest_bidder_id IS NOT NULL THEN 3 ELSE 4 END) THEN
            -- START PLAYING
            UPDATE rooms SET 
                status = 'playing', 
                current_phase = 'playing',
                pass_count = 0,
                turn_index = (CASE 
                    WHEN v_room.highest_bidder_id IS NOT NULL THEN 
                        (array_position(v_player_ids, v_room.highest_bidder_id) - 1)
                    ELSE (v_room.dealer_index + 1) % v_player_count
                END)
            WHERE id = p_room_id;
        ELSE
            -- Next bidder
            v_next_turn := (v_room.turn_index + 1) % v_player_count;
            IF v_room.highest_bidder_id IS NOT NULL AND v_player_ids[v_next_turn + 1] = v_room.highest_bidder_id THEN
                v_next_turn := (v_next_turn + 1) % v_player_count;
            END IF;
            UPDATE rooms SET turn_index = v_next_turn, pass_count = v_new_pass_count WHERE id = p_room_id;
        END IF;
    END IF;
END;
$function$;
