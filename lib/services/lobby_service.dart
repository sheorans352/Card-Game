import 'dart:math';
import 'package:supabase_flutter/supabase_flutter.dart';

class LobbyService {
  final _supabase = Supabase.instance.client;

  Future<Map<String, String>> createRoom(String hostName) async {
    final code = _generateRoomCode();
    
    final roomResponse = await _supabase.from('rooms').insert({
      'code': code,
      'status': 'lobby',
    }).select().single();

    final roomId = roomResponse['id'];

    final playerResponse = await _supabase.from('players').insert({
      'room_id': roomId,
      'name': hostName,
      'is_host': true,
    }).select().single();

    return {
      'roomCode': code,
      'playerId': playerResponse['id'],
    };
  }

  Future<Map<String, dynamic>?> joinRoom(String code, String playerName) async {
    final roomResponse = await _supabase
        .from('rooms')
        .select()
        .eq('code', code)
        .maybeSingle();

    if (roomResponse == null) return null;

    final roomId = roomResponse['id'];

    final playerResponse = await _supabase.from('players').insert({
      'room_id': roomId,
      'name': playerName,
      'is_host': false,
    }).select().single();

    return {
      'room': roomResponse,
      'playerId': playerResponse['id'],
    };
  }

  String _generateRoomCode() {
    final random = Random();
    return List.generate(6, (index) => random.nextInt(10)).join();
  }
}
