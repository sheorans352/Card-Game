// Matka Riverpod providers — independent of lib/games/minus/

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/matka_models.dart';
import '../services/matka_lobby_service.dart';
import '../services/matka_game_service.dart';

SupabaseClient get _db => Supabase.instance.client;

// ── Persistence keys ──────────────────────────────────────────────────────
const _kRoomCode = 'matka_room_code';
const _kPlayerId = 'matka_player_id';
const _kPlayerName = 'matka_player_name';

// ── Local state ───────────────────────────────────────────────────────────
final matkaRoomCodeProvider = StateProvider<String?>((ref) => null);
final matkaPlayerIdProvider = StateProvider<String?>((ref) => null);
final matkaPlayerNameProvider = StateProvider<String?>((ref) => null);
final matkaSessionLoadedProvider = StateProvider<bool>((ref) => false);

// ── Session persistence ───────────────────────────────────────────────────
class MatkaSessionNotifier extends StateNotifier<void> {
  MatkaSessionNotifier(this.ref) : super(null) {
    _init();
  }

  final Ref ref;

  Future<void> _init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final code = prefs.getString(_kRoomCode);
      final pid = prefs.getString(_kPlayerId);
      final name = prefs.getString(_kPlayerName);
      if (code != null) ref.read(matkaRoomCodeProvider.notifier).state = code;
      if (pid != null) ref.read(matkaPlayerIdProvider.notifier).state = pid;
      if (name != null) ref.read(matkaPlayerNameProvider.notifier).state = name;
    } catch (e) {
      debugPrint('MatkaSession Init Error: $e');
    } finally {
      ref.read(matkaSessionLoadedProvider.notifier).state = true;
    }
  }

  Future<void> save(String code, String playerId, String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kRoomCode, code);
    await prefs.setString(_kPlayerId, playerId);
    await prefs.setString(_kPlayerName, name);
    ref.read(matkaRoomCodeProvider.notifier).state = code;
    ref.read(matkaPlayerIdProvider.notifier).state = playerId;
    ref.read(matkaPlayerNameProvider.notifier).state = name;
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kRoomCode);
    await prefs.remove(_kPlayerId);
    await prefs.remove(_kPlayerName);
    ref.read(matkaRoomCodeProvider.notifier).state = null;
    ref.read(matkaPlayerIdProvider.notifier).state = null;
    ref.read(matkaPlayerNameProvider.notifier).state = null;
  }
}

final matkaSessionProvider = StateNotifierProvider<MatkaSessionNotifier, void>(
  (ref) => MatkaSessionNotifier(ref),
);

// ── Supabase streams ──────────────────────────────────────────────────────

/// Stream the room by its join code.
final matkaRoomByCodeProvider =
    StreamProvider.family<MatkaRoom?, String>((ref, code) {
  return _db
      .from('matka_rooms')
      .stream(primaryKey: ['id'])
      .eq('code', code)
      .map<MatkaRoom?>((rows) =>
          rows.isEmpty ? null : MatkaRoom.fromMap(Map<String, dynamic>.from(rows.first)))
      .handleError((e) {
        debugPrint('matkaRoomByCode error: $e');
        return null;
      });
});

/// Stream the room by its UUID.
final matkaRoomByIdProvider =
    StreamProvider.family<MatkaRoom?, String>((ref, id) {
  return _db
      .from('matka_rooms')
      .stream(primaryKey: ['id'])
      .eq('id', id)
      .map<MatkaRoom?>((rows) =>
          rows.isEmpty ? null : MatkaRoom.fromMap(Map<String, dynamic>.from(rows.first)))
      .handleError((e) {
        debugPrint('matkaRoomById error: $e');
        return null;
      });
});

/// Stream players for a room, sorted by seat_index.
final matkaPlayersProvider =
    StreamProvider.family<List<MatkaPlayer>, String>((ref, roomId) {
  return _db
      .from('matka_players')
      .stream(primaryKey: ['id'])
      .eq('room_id', roomId)
      .map((rows) {
        final list = rows
            .map<MatkaPlayer>((r) => MatkaPlayer.fromMap(Map<String, dynamic>.from(r)))
            .toList();
        list.sort((a, b) => a.seatIndex.compareTo(b.seatIndex));
        return list;
      })
      .handleError((e) {
        debugPrint('matkaPlayers error: $e');
        return <MatkaPlayer>[];
      });
});

/// Stream recent round history for a room.
final matkaRoundsProvider =
    StreamProvider.family<List<MatkaRound>, String>((ref, roomId) {
  return _db
      .from('matka_rounds')
      .stream(primaryKey: ['id'])
      .eq('room_id', roomId)
      .map((rows) {
        final list = rows
            .map<MatkaRound>((r) => MatkaRound.fromMap(Map<String, dynamic>.from(r)))
            .toList();
        list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return list;
      });
});

// ── Derived providers ─────────────────────────────────────────────────────

/// Is the local player the host of this room?
final isMatkaHostProvider = Provider.family<bool, String>((ref, roomId) {
  final localId = ref.watch(matkaPlayerIdProvider);
  final players = ref.watch(matkaPlayersProvider(roomId)).value ?? [];
  if (localId == null) return false;
  return players.any((p) => p.id == localId && p.isHost);
});

/// Is it the local player's turn right now?
final isMyMatkaTurnProvider = Provider.family<bool, String>((ref, roomId) {
  final room = ref.watch(matkaRoomByIdProvider(roomId)).value;
  if (room == null || room.status != 'betting') return false;
  final localId = ref.watch(matkaPlayerIdProvider);
  if (localId == null) return false;
  final players = ref.watch(matkaPlayersProvider(roomId)).value ?? [];
  if (players.isEmpty) return false;
  final currentPlayer = players[room.currentPlayerIndex % players.length];
  return currentPlayer.id == localId;
});

/// The player whose turn it currently is.
final currentMatkaPlayerProvider =
    Provider.family<MatkaPlayer?, String>((ref, roomId) {
  final room = ref.watch(matkaRoomByIdProvider(roomId)).value;
  if (room == null) return null;
  final players = ref.watch(matkaPlayersProvider(roomId)).value ?? [];
  if (players.isEmpty) return null;
  return players[room.currentPlayerIndex % players.length];
});

/// The local player object.
final localMatkaPlayerProvider =
    Provider.family<MatkaPlayer?, String>((ref, roomId) {
  final localId = ref.watch(matkaPlayerIdProvider);
  if (localId == null) return null;
  final players = ref.watch(matkaPlayersProvider(roomId)).value ?? [];
  try {
    return players.firstWhere((p) => p.id == localId);
  } catch (_) {
    return null;
  }
});

// ── Service providers ─────────────────────────────────────────────────────
final matkaLobbyServiceProvider =
    Provider<MatkaLobbyService>((ref) => SupabaseMatkaLobbyService());

final matkaGameServiceProvider =
    Provider<MatkaGameService>((ref) => MatkaGameService());
