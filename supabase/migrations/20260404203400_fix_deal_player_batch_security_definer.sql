CREATE OR REPLACE FUNCTION public.deal_player_batch(p_room_id uuid, p_player_id uuid, p_count integer)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
    v_deck text[];
    v_ptr int;
    v_curr_round int;
BEGIN
    SELECT shuffled_deck, deck_ptr, current_round INTO v_deck, v_ptr, v_curr_round 
    FROM rooms WHERE id = p_room_id;

    FOR i IN 1..p_count LOOP
        INSERT INTO hands (room_id, player_id, card_value, round_number)
        VALUES (p_room_id, p_player_id, v_deck[v_ptr + i], v_curr_round);
    END LOOP;

    UPDATE rooms SET deck_ptr = v_ptr + p_count WHERE id = p_room_id;
END;
$function$;
