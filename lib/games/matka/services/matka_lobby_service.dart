// Matka lobby service — create/join rooms
// Independent of lib/games/minus/

import 'dart:math';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/card_model.dart';

SupabaseClient get _db => Supabase.instance.client;

abstract class MatkaLobbyService {
  Future<Map<String, String>> createRoom({
    required String name,
    required int deckCount,
    required int anteAmount,
  });
  Future<Map<String, String>?> joinRoom(String code, String name);
  Future<void> setReady(String playerId, bool ready);
}

class SupabaseMatkaLobbyService implements MatkaLobbyService {
  @override
  Future<Map<String, String>> createRoom({
    required String name,
    required int deckCount,
    required int anteAmount,
  }) async {
    final shoe = MatkaCard.shuffled(MatkaCard.buildShoe(deckCount));
    final code = _genCode();

    final roomRow = await _db.from('matka_rooms').insert({
      'code': code,
      'status': 'waiting',
      'host_id': null,
      'deck_count': deckCount,
      'ante_amount': anteAmount,
      'pot_amount': 0,
      'current_player_index': 0,
      'round_number': 1,
    }).select().single();

    final playerRow = await _db.from('matka_players').insert({
      'room_id': roomRow['id'],
      'name': name.trim(),
      'net_chips': 0,
      'seat_index': 0,
      'is_host': true,
      'is_ready': true,
    }).select().single();

    await _db
        .from('matka_rooms')
        .update({'host_id': playerRow['id']})
        .eq('id', roomRow['id']);

    return {
      'roomCode': code,
      'playerId': playerRow['id'],
      'roomId': roomRow['id'],
    };
  }

  @override
  Future<Map<String, String>?> joinRoom(String code, String name) async {
    final rooms = await _db
        .from('matka_rooms')
        .select()
        .eq('code', code.trim().toUpperCase())
        .eq('status', 'waiting')
        .limit(1);

    if (rooms.isEmpty) return null;
    final room = rooms.first;

    final existing = await _db
        .from('matka_players')
        .select('id')
        .eq('room_id', room['id']);
    if (existing.length >= 8) return null;

    final playerRow = await _db.from('matka_players').insert({
      'room_id': room['id'],
      'name': name.trim(),
      'net_chips': 0,
      'seat_index': existing.length,
      'is_host': false,
      'is_ready': false,
    }).select().single();

    return {
      'roomCode': code.trim().toUpperCase(),
      'playerId': playerRow['id'],
      'roomId': room['id'],
    };
  }

  @override
  Future<void> setReady(String playerId, bool ready) async {
    await _db
        .from('matka_players')
        .update({'is_ready': ready})
        .eq('id', playerId);
  }

  String _genCode() {
    final r = Random();
    return List.generate(6, (_) => r.nextInt(10)).join();
  }
}
