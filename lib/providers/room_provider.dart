import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:app_links/app_links.dart';
import '../services/lobby_service.dart';
import '../services/card_service.dart';
import '../models/game_models.dart';

final appLinksProvider = Provider((ref) => AppLinks());

final appLinkStreamProvider = StreamProvider<Uri>((ref) {
  return ref.watch(appLinksProvider).uriLinkStream;
});

final lobbyServiceProvider = Provider((ref) => LobbyService());
final cardServiceProvider = Provider((ref) => CardService());

final currentRoomCodeProvider = StateProvider<String?>((ref) => null);
final localPlayerIdProvider = StateProvider<String?>((ref) => null);

final roomMetadataProvider = StreamProvider.family<Room?, String>((ref, code) {
  final supabase = Supabase.instance.client;
  return supabase
      .from('rooms')
      .stream(primaryKey: ['id'])
      .eq('code', code)
      .map((data) => data.isNotEmpty ? Room.fromMap(data.first) : null);
});

final playersStreamProvider = StreamProvider.family<List<Player>, String>((ref, roomId) {
  final supabase = Supabase.instance.client;
  return supabase
      .from('players')
      .stream(primaryKey: ['id'])
      .eq('room_id', roomId)
      .order('joined_at', ascending: true)
      .map((data) => data.map((map) => Player.fromMap(map)).toList());
});

final isLocalPlayerTurnProvider = Provider.family<bool, String>((ref, code) {
  final roomAsync = ref.watch(roomMetadataProvider(code));
  final localPlayerId = ref.watch(localPlayerIdProvider);
  
  return roomAsync.when(
    data: (room) {
      if (room == null || localPlayerId == null) return false;
      final playersAsync = ref.watch(playersStreamProvider(room.id));
      return playersAsync.when(
        data: (players) {
          if (room.turnIndex >= players.length) return false;
          return players[room.turnIndex].id == localPlayerId;
        },
        loading: () => false,
        error: (_, __) => false,
      );
    },
    loading: () => false,
    error: (_, __) => false,
  );
});

final playerHandProvider = StreamProvider.family<List<Map<String, dynamic>>, String>((ref, playerId) {
  final supabase = Supabase.instance.client;
  return supabase
      .from('player_cards')
      .stream(primaryKey: ['id'])
      .eq('player_id', playerId)
      .eq('is_played', false)
      .map((data) => List<Map<String, dynamic>>.from(data));
});

final playedCardsProvider = StreamProvider.family<List<Map<String, dynamic>>, String>((ref, roomId) {
  final supabase = Supabase.instance.client;
  return supabase
      .from('player_cards')
      .stream(primaryKey: ['id'])
      .eq('room_id', roomId)
      .eq('is_played', true)
      .order('played_at', ascending: true)
      .map((data) => List<Map<String, dynamic>>.from(data));
});
