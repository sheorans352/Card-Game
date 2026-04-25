import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/tehri_models.dart';

final supabase = Supabase.instance.client;

// Session Persistence Keys
const String kTehriRoomCodeKey = 'tehri_last_room_code';
const String kTehriPlayerIdKey = 'tehri_last_player_id';
const String kTehriPlayerNameKey = 'tehri_last_player_name';

// --- ID Providers ---
final currentTehriRoomIdProvider = StateProvider<String?>((ref) => null);
final currentTehriRoomCodeProvider = StateProvider<String?>((ref) => null);
final localTehriPlayerIdProvider = StateProvider<String?>((ref) => null);
final localTehriPlayerNameProvider = StateProvider<String?>((ref) => null);

// --- Dealer Selection State ---
final dealerSelectionCardProvider = StateProvider<Map<String, dynamic>?>((ref) => null);

// --- Stream Providers ---

final tehriRoomProvider = StreamProvider.family<TehriRoom?, String>((ref, roomId) {
  return supabase
      .from('tehri_rooms')
      .stream(primaryKey: ['id'])
      .eq('id', roomId)
      .map((data) => data.isEmpty ? null : TehriRoom.fromMap(data.first));
});

final tehriRoomByCodeProvider = StreamProvider.family<TehriRoom?, String>((ref, code) {
  return supabase
      .from('tehri_rooms')
      .stream(primaryKey: ['id'])
      .eq('code', code)
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

// --- Session Logic ---
final tehriSessionProvider = StateNotifierProvider<TehriSessionNotifier, AsyncValue<void>>((ref) {
  return TehriSessionNotifier(ref);
});

class TehriSessionNotifier extends StateNotifier<AsyncValue<void>> {
  TehriSessionNotifier(this.ref) : super(const AsyncValue.loading()) {
    _init();
  }
  final Ref ref;

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    final urlParams = Uri.base.queryParameters;

    final roomCode = urlParams['code'] ?? prefs.getString(kTehriRoomCodeKey);
    final playerId = urlParams['playerId'] ?? prefs.getString(kTehriPlayerIdKey);
    final playerName = prefs.getString(kTehriPlayerNameKey);

    if (roomCode != null) {
      ref.read(currentTehriRoomCodeProvider.notifier).state = roomCode;
      await prefs.setString(kTehriRoomCodeKey, roomCode);
    }
    if (playerId != null) {
      ref.read(localTehriPlayerIdProvider.notifier).state = playerId;
      await prefs.setString(kTehriPlayerIdKey, playerId);
    }
    if (playerName != null) {
      ref.read(localTehriPlayerNameProvider.notifier).state = playerName;
    }
    state = const AsyncValue.data(null);
  }

  Future<void> saveSession(String roomCode, String roomId, String playerId, String playerName) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(kTehriRoomCodeKey, roomCode);
    await prefs.setString(kTehriPlayerIdKey, playerId);
    await prefs.setString(kTehriPlayerNameKey, playerName);
    
    ref.read(currentTehriRoomCodeProvider.notifier).state = roomCode;
    ref.read(currentTehriRoomIdProvider.notifier).state = roomId;
    ref.read(localTehriPlayerIdProvider.notifier).state = playerId;
    ref.read(localTehriPlayerNameProvider.notifier).state = playerName;
  }

  Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(kTehriRoomCodeKey);
    await prefs.remove(kTehriPlayerIdKey);
    ref.read(currentTehriRoomCodeProvider.notifier).state = null;
    ref.read(currentTehriRoomIdProvider.notifier).state = null;
    ref.read(localTehriPlayerIdProvider.notifier).state = null;
  }
}

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

  Future<Map<String, String>> createRoom(String name) async {
    final code = (100000 + (DateTime.now().millisecondsSinceEpoch % 899999)).toString();
    
    final room = await supabase.from('tehri_rooms').insert({
      'code': code,
      'status': 'waiting',
    }).select().single();
    
    final player = await supabase.from('tehri_players').insert({
      'room_id': room['id'],
      'name': name,
      'seat_index': 0,
      'team_index': 0,
      'is_host': true,
    }).select().single();
    
    await supabase.from('tehri_rooms').update({'host_id': player['id']}).eq('id', room['id']);
    
    return {
      'roomId': room['id'] as String,
      'roomCode': code,
      'playerId': player['id'] as String,
    };
  }

  Future<Map<String, String>?> joinRoom(String code, String name, {String? existingPlayerId}) async {
    // 1. Find room
    final roomRes = await supabase.from('tehri_rooms').select().eq('code', code).eq('status', 'waiting');
    if (roomRes.isEmpty) return null;
    final room = roomRes.first;
    final roomId = room['id'];

    // 2. Check existing player
    if (existingPlayerId != null) {
      final pRes = await supabase.from('tehri_players').select().eq('id', existingPlayerId).eq('room_id', roomId);
      if (pRes.isNotEmpty) {
        return {
          'roomId': roomId,
          'playerId': existingPlayerId,
        };
      }
    }

    // 3. Check player count
    final players = await supabase.from('tehri_players').select().eq('room_id', roomId);
    if (players.length >= 4) return null;

    // 4. Join
    final seat = players.length;
    final player = await supabase.from('tehri_players').insert({
      'room_id': roomId,
      'name': name,
      'seat_index': seat,
      'team_index': seat % 2,
    }).select().single();

    return {
      'roomId': roomId,
      'playerId': player['id'] as String,
    };
  }

  Future<void> startGame(String roomId) async {
    await supabase.rpc('tehri_start_selection', params: {'rid': roomId});
  }

  Future<void> dealForSelection(String roomId) async {
    final res = await supabase.rpc('tehri_deal_for_selection', params: {'rid': roomId});
    // We could broadcast this via a table, but for now we'll just return and handle locally
    // Actually, it's better to use a dedicated table or column for selection history.
    // For now, let's just use the RPC result.
  }

  Future<void> initRound(String roomId, String dealerId) async {
    await supabase.rpc('tehri_init_round', params: {
      'rid': roomId,
      'did': dealerId,
    });
  }

  Future<void> cutDeck(String roomId, int cutIdx) async {
    await supabase.rpc('tehri_cut_deck', params: {
      'rid': roomId,
      'cut_idx': cutIdx,
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
