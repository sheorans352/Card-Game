import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/tehri_models.dart';

final supabase = Supabase.instance.client;

// --- ID Providers ---
final currentTehriRoomIdProvider = StateProvider<String?>((ref) => null);
final localTehriPlayerIdProvider = StateProvider<String?>((ref) => null);

// --- Stream Providers ---

final tehriRoomProvider = StreamProvider.family<TehriRoom?, String>((ref, roomId) {
  return supabase
      .from('tehri_rooms')
      .stream(primaryKey: ['id'])
      .eq('id', roomId)
      .map((data) => data.isEmpty ? null : TehriRoom.fromMap(data.first));
});

final tehriPlayersProvider = StreamProvider.family<List<TehriPlayer>, String>((ref, roomId) {
  return supabase
      .from('tehri_players')
      .stream(primaryKey: ['id'])
      .eq('room_id', roomId)
      .map((data) => data.map((p) => TehriPlayer.fromMap(p)).toList()
        ..sort((a, b) => a.seatIndex.compareTo(b.seatIndex)));
});

final tehriHandProvider = StreamProvider.family<List<String>, String>((ref, playerId) {
  return supabase
      .from('tehri_hands')
      .stream(primaryKey: ['player_id'])
      .eq('player_id', playerId)
      .map((data) => data.isEmpty ? [] : List<String>.from(data.first['cards'] ?? []));
});

final tehriTricksProvider = StreamProvider.family<List<TehriTrick>, String>((ref, roomId) {
  return supabase
      .from('tehri_tricks')
      .stream(primaryKey: ['id'])
      .eq('room_id', roomId)
      .map((data) => data.map((t) => TehriTrick.fromMap(t)).toList());
});

// --- Logic Providers ---

final localTehriPlayerProvider = Provider.family<TehriPlayer?, String>((ref, roomId) {
  final players = ref.watch(tehriPlayersProvider(roomId)).value ?? [];
  final localId = ref.watch(localTehriPlayerIdProvider);
  if (localId == null) return null;
  return players.where((p) => p.id == localId).firstOrNull;
});

final isMyTehriTurnProvider = Provider.family<bool, String>((ref, roomId) {
  final room = ref.watch(tehriRoomProvider(roomId)).value;
  final me = ref.watch(localTehriPlayerProvider(roomId));
  if (room == null || me == null) return false;
  return room.currentTurnIndex == me.seatIndex;
});

// --- Game Operations ---

final tehriOpsProvider = Provider((ref) => TehriOperations());

class TehriOperations {
  Future<void> setInitialBid(String roomId, String playerId, int bid, String trump) async {
    await supabase.rpc('tehri_set_initial_bid', params: {
      'rid': roomId,
      'pid': playerId,
      'bid': bid,
      'trump': trump,
    });
  }

  Future<void> placeBid(String roomId, String playerId, int bid, String trump) async {
    await supabase.rpc('tehri_place_bid', params: {
      'rid': roomId,
      'pid': playerId,
      'bid': bid,
      'trump': trump,
    });
  }

  Future<void> playCard(String roomId, String playerId, String cardId) async {
    await supabase.rpc('tehri_play_card', params: {
      'rid': roomId,
      'pid': playerId,
      'card_id': cardId,
    });
  }

  Future<void> initRound(String roomId, String dealerId) async {
    await supabase.rpc('tehri_init_round', params: {
      'rid': roomId,
      'did': dealerId,
    });
  }

  Future<void> dealInitial(String roomId) async {
    await supabase.rpc('tehri_deal_initial', params: {
      'rid': roomId,
    });
  }

  Future<void> dealBatch(String roomId, String playerId, int count) async {
    await supabase.rpc('tehri_deal_batch', params: {
      'rid': roomId,
      'pid': playerId,
      'p_count': count,
    });
  }

  Future<void> finishInitialDealing(String roomId) async {
    await supabase.rpc('tehri_finish_initial_dealing', params: {
      'rid': roomId,
    });
  }

  Future<void> finishDealing(String roomId) async {
    await supabase.rpc('tehri_finish_dealing', params: {
      'rid': roomId,
    });
  }

  Future<void> dealRemaining(String roomId) async {
    await supabase.rpc('tehri_deal_remaining', params: {
      'rid': roomId,
    });
  }
}
