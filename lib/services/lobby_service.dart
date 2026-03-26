import 'package:supabase_flutter/supabase_flutter.dart';
import 'card_service.dart';

abstract class LobbyService {
  Future<Map<String, String>> createRoom(String hostName);
  Future<Map<String, String>?> joinRoom(String code, String playerName);
  Future<void> startGame(String roomId);
}

class SupabaseLobbyService extends LobbyService {
  final _supabase = Supabase.instance.client;

  @override
  Future<Map<String, String>> createRoom(String hostName) async {
    final roomCode = (100000 + (DateTime.now().millisecondsSinceEpoch % 900000)).toString();
    
    final roomResponseList = await _supabase.from('rooms').insert({
      'code': roomCode,
      'status': 'waiting',
      'current_phase': 'lobby',
      'dealer_index': 0,
      'turn_index': 0,
    }).select();
    final roomResponse = roomResponseList.first;

    final playerResponseList = await _supabase.from('players').insert({
      'room_id': roomResponse['id'],
      'name': hostName,
      'is_host': true,
      'total_score': 0,
    }).select();
    final playerResponse = playerResponseList.first;

    // Update room with host_id
    await _supabase.from('rooms').update({
      'host_id': playerResponse['id'],
    }).eq('id', roomResponse['id']);

    return {
      'roomCode': roomCode,
      'playerId': playerResponse['id'],
    };
  }

  @override
  Future<Map<String, String>?> joinRoom(String code, String playerName) async {
    final roomResponse = await _supabase.from('rooms').select().eq('code', code);
    if (roomResponse.isEmpty || roomResponse.first['status'] != 'waiting') return null;
    final room = roomResponse.first;

    // Check current player count
    final playersResponse = await _supabase
        .from('players')
        .select('id')
        .eq('room_id', room['id']);
    
    if (playersResponse.length >= 4) return null;

    final playerResponseList = await _supabase.from('players').insert({
      'room_id': room['id'],
      'name': playerName,
      'is_host': false,
      'total_score': 0,
    }).select();
    final playerResponse = playerResponseList.first;

    return {
      'playerId': playerResponse['id'],
    };
  }

  @override
  Future<void> startGame(String roomId) async {
    await _supabase.from('rooms').update({
      'status': 'shuffling',
      'current_phase': 'shuffling',
    }).eq('id', roomId);
    
    // Automatically trigger shuffle after a brief delay for UI/Sync
    await Future.delayed(const Duration(milliseconds: 1500));
    final cardService = SupabaseCardService();
    await cardService.shuffleDeck(roomId);
  }
}
