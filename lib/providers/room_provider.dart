import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/game_models.dart';
import '../models/card_model.dart';
import '../services/lobby_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/card_service.dart';
import '../config/env_config.dart';

SupabaseClient get supabase => Supabase.instance.client;

// Track cards locally played in the current round to bypass Realtime lag.
final localPlayedCardsProvider = StateProvider<Set<String>>((ref) => {});

// Session Persistence Keys
const String kRoomCodeKey = 'minus_last_room_code';
const String kPlayerIdKey = 'minus_last_player_id';
const String kPlayerNameKey = 'minus_last_player_name';

// Helper for Provider grouping
class RoomRound {
  final String roomId;
  final int roundNumber;
  RoomRound(this.roomId, this.roundNumber);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RoomRound &&
          runtimeType == other.runtimeType &&
          roomId == other.roomId &&
          roundNumber == other.roundNumber;

  @override
  int get hashCode => roomId.hashCode ^ roundNumber.hashCode;
}

class SessionNotifier extends StateNotifier<AsyncValue<void>> {
  SessionNotifier(this.ref) : super(const AsyncValue.data(null)) {
    _init();
  }

  final Ref ref;

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    final urlParams = Uri.base.queryParameters;

    final roomCode = urlParams['room'] ?? urlParams['code'] ?? prefs.getString(kRoomCodeKey);
    final playerId = urlParams['playerId'] ?? prefs.getString(kPlayerIdKey);
    final playerName = prefs.getString(kPlayerNameKey);

    if (roomCode != null) {
      ref.read(currentRoomCodeProvider.notifier).state = roomCode;
      await prefs.setString(kRoomCodeKey, roomCode);
    }
    if (playerId != null) {
      ref.read(localPlayerIdProvider.notifier).state = playerId;
      await prefs.setString(kPlayerIdKey, playerId);
    }
    if (playerName != null && playerName.isNotEmpty) {
      ref.read(localPlayerNameProvider.notifier).state = playerName;
    }
  }

  Future<void> saveSession(String roomCode, String playerId, String playerName) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(kRoomCodeKey, roomCode);
    await prefs.setString(kPlayerIdKey, playerId);
    await prefs.setString(kPlayerNameKey, playerName);
    ref.read(currentRoomCodeProvider.notifier).state = roomCode;
    ref.read(localPlayerIdProvider.notifier).state = playerId;
    ref.read(localPlayerNameProvider.notifier).state = playerName;
  }

  Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(kRoomCodeKey);
    await prefs.remove(kPlayerIdKey);
    ref.read(currentRoomCodeProvider.notifier).state = null;
    ref.read(localPlayerIdProvider.notifier).state = null;
  }
}

final sessionProvider = StateNotifierProvider<SessionNotifier, AsyncValue<void>>((ref) {
  return SessionNotifier(ref);
});

// Heartbeat Polling Provider
final heartbeatProvider = StreamProvider.family<void, String>((ref, roomId) async* {
  while (true) {
    await Future.delayed(const Duration(seconds: 3));
    // Quietly refresh the most critical data
    ref.invalidate(roomMetadataByIdProvider(roomId));
    // room_provider.dart:207 uses RoomRound, so for simplicity we just invalidate the room
    // which then forces the dependent playedCardsProvider to update based on current_round.
    yield null;
  }
});

// Mock Providers for Verification
final currentRoomCodeProvider = StateProvider<String?>((ref) {
  if (kIsWeb) {
    final uri = Uri.parse(Uri.base.toString().replaceFirst('/#/', '/'));
    return uri.queryParameters['room'];
  }
  return null;
});

final localPlayerIdProvider = StateProvider<String?>((ref) {
  if (kIsWeb) {
    final uri = Uri.parse(Uri.base.toString().replaceFirst('/#/', '/'));
    return uri.queryParameters['playerId'];
  }
  return null;
});

final localPlayerNameProvider = StateProvider<String?>((ref) => null);

// State tracking for optimistic UI updates
final pendingCardPlayProvider = StateProvider<Set<String>>((ref) => {});

// Core Providers

final roomMetadataByIdProvider = StreamProvider.family<Room?, String>((ref, roomId) {
  return supabase
      .from('rooms')
      .stream(primaryKey: ['id'])
      .eq('id', roomId)
      .map<Room?>((data) => data.isEmpty ? null : Room.fromJson(Map<String, dynamic>.from(data.first)))
      .handleError((error) {
        debugPrint('Supabase Stream Error (RoomById): $error');
        return null;
      });
});

final roomMetadataProvider = StreamProvider.family<Room?, String>((ref, code) {
  return supabase
      .from('rooms')
      .stream(primaryKey: ['id'])
      .eq('code', code)
      .map<Room?>((data) => data.isEmpty ? null : Room.fromJson(Map<String, dynamic>.from(data.first)))
      .handleError((error) {
        debugPrint('Supabase Stream Error (Room): $error');
        throw error;
      });
});

final playersStreamProvider = StreamProvider.family<List<Player>, String>((ref, roomId) {
  return supabase
      .from('players')
      .stream(primaryKey: ['id'])
      .eq('room_id', roomId)
      .map((data) {
        final sorted = List<Map<String, dynamic>>.from(data);
        sorted.sort((a, b) {
          final timeA = a['joined_at']?.toString() ?? '';
          final timeB = b['joined_at']?.toString() ?? '';
          final res = timeA.compareTo(timeB);
          if (res != 0) return res;
          return (a['id']?.toString() ?? '').compareTo(b['id']?.toString() ?? '');
        });
        return sorted.map<Player>((p) => Player.fromJson(p)).toList();
      })
      .handleError((error) {
        debugPrint('Supabase Stream Error (Players): $error');
        throw error;
      });
});

final playerHandProvider = StreamProvider.family<List<Map<String, dynamic>>, String>((ref, playerId) {
  return supabase
      .from('player_hands')
      .stream(primaryKey: ['id'])
      .eq('player_id', playerId)
      .map((data) {
        final hand = data.map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e)).toList();
        
        // Arrange cards in descending order by grouping them by suits
        const suitOrder = {'S': 0, 'H': 1, 'D': 2, 'C': 3};
        
        hand.sort((a, b) {
          final valA = a['card_value'] as String;
          final valB = b['card_value'] as String;
          final suitA = valA.substring(valA.length - 1).toUpperCase();
          final suitB = valB.substring(valB.length - 1).toUpperCase();
          
          if (suitA != suitB) {
            return (suitOrder[suitA] ?? 99).compareTo(suitOrder[suitB] ?? 99);
          }
          
          // Same suit: Descending rank (Ace first)
          return Player.getRankValue(valB).compareTo(Player.getRankValue(valA));
        });
        
        return hand;
      })
      .handleError((error) {
        debugPrint('Supabase Stream Error (Hand): $error');
        throw error;
      });
});

final playedCardsProvider = StreamProvider.family<List<Map<String, dynamic>>, RoomRound>((ref, rr) {
  // Note: Supabase StreamBuilder filtering is limited for non-primary keys in some versions.
  // We perform the final filtering in the .map() for maximum stability during migrations.
  return supabase
      .from('played_cards')
      .stream(primaryKey: ['id'])
      .eq('room_id', rr.roomId) 
      .map((data) {
        final filtered = data.where((e) => e['current_round'] == rr.currentRound).toList();
        final sorted = filtered.map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e)).toList();
        sorted.sort((a, b) {
          final timeA = a['played_at'] as String;
          final timeB = b['played_at'] as String;
          final res = timeA.compareTo(timeB);
          if (res != 0) return res;
          return (a['id'] as String).compareTo(b['id'] as String);
        });
        return sorted;
      })
      .handleError((error) {
        debugPrint('Supabase Stream Error (PlayedCards): $error');
        throw error;
      });
});

final roundResultsProvider = StreamProvider.family<List<Map<String, dynamic>>, String>((ref, roomId) {
  return supabase
      .from('round_results')
      .stream(primaryKey: ['id'])
      .eq('room_id', roomId)
      .map((data) => data.map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e)).toList())
      .handleError((error) {
        debugPrint('Supabase Stream Error (RoundResults): $error');
        throw error;
      });
});

// === UNIFIED PREDICTIVE CARD STATE ===
// Combines server-side cards with local optimistic plays to provide a seamless state.
final predictivePlayedCardsProvider = Provider.family<List<Map<String, dynamic>>, String>((ref, roomId) {
  final room = ref.watch(roomMetadataByIdProvider(roomId)).value;
  if (room == null || room.status == 'shuffling' || room.status == 'bidding' || room.status == 'trump_selection' || room.status == 'dealing') {
    return []; // FORCE CLEAR table during these phases
  }

  final serverPlayed = ref.watch(playedCardsProvider(RoomRound(roomId, room.currentRound))).value ?? [];
  final localPlayed = ref.watch(localPlayedCardsProvider);
  final localId = ref.watch(localPlayerIdProvider);

  if (localPlayed.isEmpty) return serverPlayed;

  // Filter local cards that haven't hitting the server yet
  final serverCardIds = serverPlayed.map((m) => m['card_value'] as String).toSet();
  final localOnly = localPlayed.where((id) => !serverCardIds.contains(id)).toList();
  
  if (localOnly.isEmpty) return serverPlayed;

  // Merge: Server cards come first, then local ones (approximating true play order)
  final total = [...serverPlayed];
  
  // PRUNING SIDE-EFFECT: Remove cards from localPlayed that are already on server
  if (localPlayed.any((id) => serverCardIds.contains(id))) {
    Future.microtask(() {
       ref.read(localPlayedCardsProvider.notifier).update((state) => 
         state.where((id) => !serverCardIds.contains(id)).toSet()
       );
    });
  }

  for (var cardId in localOnly) {
     total.add({
       'card_id': 'opt_$cardId', // Unique local ID
       'card_value': cardId,
       'player_id': localId,
       'is_optimistic': true,
     });
  }
  return total;
});

// === UNIFIED PREDICTIVE TURN LOGIC ===
// Determines whose turn it is based on BOTH server state and local optimistic plays.
final predictiveTurnIdProvider = Provider.family<String?, String>((ref, roomId) {
  final room = ref.watch(roomMetadataByIdProvider(roomId)).value;
  if (room == null) return null;
  final players = ref.watch(playersStreamProvider(roomId)).value ?? [];
  if (players.isEmpty) return null;

  final cards = ref.watch(predictivePlayedCardsProvider(roomId));
  final totalCount = cards.length;
  
  if (totalCount == 0) {
    if (room.turnIndex < 0) return null;
    return players[room.turnIndex % players.length].id;
  }

  final trickSize = totalCount % 4;
  
  if (trickSize == 0) {
    // Current trick is complete! The winner of the LAST trick leads the NEW trick.
    final lastTrick = cards.sublist(totalCount - 4);
    final winnerId = Player.evaluateTrickWinner(lastTrick, room.trumpSuit, players);
    return winnerId;
  } else {
    // A trick is currently in progress. 
    // We find the leader of the CURRENT trick (the card at index `totalCount - trickSize`).
    final currentTrickStartIdx = (totalCount ~/ 4) * 4;
    final leaderId = cards[currentTrickStartIdx]['player_id'];
    
    if (leaderId == null) return players[room.turnIndex % players.length].id;
    
    final leaderIndex = players.indexWhere((p) => p.id == leaderId);
    if (leaderIndex == -1) return players[room.turnIndex % players.length].id;
    
    // The current turn is (leaderIndex + trickSize) % 4
    return players[(leaderIndex + trickSize.toInt()) % players.length].id;
  }
});

final playableCardsProvider = Provider.family<Set<String>, String>((ref, roomId) {
  final room = ref.watch(roomMetadataByIdProvider(roomId)).value;
  final localId = ref.watch(localPlayerIdProvider);
  if (room == null || localId == null || room.status != 'playing') return {};
  
  final players = ref.watch(playersStreamProvider(room.id)).value ?? [];
  if (players.isEmpty) return {};

  final hand = ref.watch(playerHandProvider(localId)).value ?? [];
  final cards = ref.watch(predictivePlayedCardsProvider(roomId));
  
  // === TURN CHECK (Predictive) ===
  final currentTurnId = ref.watch(predictiveTurnIdProvider(roomId));
  if (currentTurnId != localId) return {};
  
  // Filter out cards already played (Optimistic + Ground Truth)
  final pendingPlays = ref.watch(pendingCardPlayProvider);
  final localPlayed = ref.watch(localPlayedCardsProvider);
  final serverPlayed = ref.watch(playedCardsProvider(RoomRound(roomId, room.currentRound))).value ?? [];
  final myPlayedIds = serverPlayed.where((m) => m['player_id'] == localId).map((m) => m['card_value'] as String).toSet();
  
  final cardsInHand = hand.map((c) => (c['card_value'] as String).trim().toUpperCase())
      .where((id) => !pendingPlays.contains(id) && !localPlayed.contains(id) && !myPlayedIds.contains(id))
      .toList();
  
  // Trick Logic
  final trickSize = cards.length % 4;
  
  // If no cards in the current trick, we are the leader! Can play ANY card.
  if (trickSize == 0) return cardsInHand.toSet(); 
  
  final currentTrick = cards.sublist(cards.length - trickSize);
  final leadCard = (currentTrick.first['card_value'] as String).trim().toUpperCase();
  final leadSuit = CardModel.getSuit(leadCard);
  final trump = (room.trumpSuit ?? 'S').toUpperCase().trim();
  final isTrumpOnTable = currentTrick.any((m) => CardModel.getSuit(m['card_value'] as String) == trump);

  final hasLeadSuit = cardsInHand.any((c) => CardModel.getSuit(c) == leadSuit);
  
  if (hasLeadSuit) {
    final cardsOfLeadSuit = cardsInHand.where((c) => CardModel.getSuit(c) == leadSuit).toSet();
    
    if (isTrumpOnTable) {
      // If trick is trumped, lead suit CANNOT win. Allow any card of lead suit.
      return cardsOfLeadSuit;
    } else {
      // Must beat highest lead suit card on table
      int highestLeadRank = 0;
      for (var m in currentTrick) {
        final val = m['card_value'] as String;
        if (CardModel.getSuit(val) == leadSuit) {
          final r = CardModel.getRankValue(val);
          if (r > highestLeadRank) highestLeadRank = r;
        }
      }
      final winners = cardsOfLeadSuit.where((c) => CardModel.getRankValue(c) > highestLeadRank).toSet();
      return winners.isNotEmpty ? winners : cardsOfLeadSuit;
    }
  } else {
    // No lead suit -> Option: ANY card is playable (Trump or Throwaway)
    return cardsInHand.toSet();
  }
});



int _getRankValue(String v) => Player.getRankValue(v);

final isLocalPlayerTurnProvider = Provider.family<bool, String>((ref, code) {
  final room = ref.watch(roomMetadataProvider(code)).value;
  if (room == null) return false;
  final localId = ref.watch(localPlayerIdProvider);
  if (localId == null) return false;

  if (room.status == 'waiting') return false;
  if (room.status == 'cutting') {
    final players = ref.watch(playersStreamProvider(room.id)).value ?? [];
    if (players.isEmpty) return false;
    final cutterIndex = (room.dealerIndex + 1) % players.length;
    return players[cutterIndex].id == localId;
  }
  
  if (room.status == 'bidding' || room.status == 'bidding_2' || room.status == 'playing' || room.status == 'trump_selection') {
    // Scenario A: trump setter doesn't declare in bidding_2
    if (room.status == 'bidding_2' && room.highestBidderId != null && localId == room.highestBidderId) {
      return false;
    }
    
    if (room.status == 'playing') {
      final turnId = ref.watch(predictiveTurnIdProvider(room.id));
      return turnId == localId;
    }

    final players = ref.watch(playersStreamProvider(room.id)).value ?? [];
    if (players.isEmpty) return false;
    final currentPlayer = players[room.turnIndex % players.length];
    return currentPlayer.id == localId;
  }
  return false;
});

final isCutterProvider = Provider.family<bool, String>((ref, code) {
  final room = ref.watch(roomMetadataProvider(code)).value;
  if (room == null) return false;
  final players = ref.watch(playersStreamProvider(room.id)).value;
  final localId = ref.watch(localPlayerIdProvider);
  if (players == null || localId == null) return false;
  // Cutter is the player to the left of the dealer (index + 1)
  final cutterIndex = (room.dealerIndex + 1) % players.length;
  return players[cutterIndex].id == localId;
});

final isLocalPlayerDealerProvider = Provider.family<bool, String>((ref, code) {
  final room = ref.watch(roomMetadataProvider(code)).value;
  if (room == null) return false;
  final players = ref.watch(playersStreamProvider(room.id)).value;
  final localId = ref.watch(localPlayerIdProvider);
  if (players == null || localId == null) return false;
  
  final dealerIndexInList = room.dealerIndex % players.length;
  return players[dealerIndexInList].id == localId;
});

final allPlayersReadyProvider = Provider.family<bool, String>((ref, roomId) {
  final players = ref.watch(playersStreamProvider(roomId)).value ?? [];
  if (players.length < 4) return false;
  return players.every((p) => p.isReady);
});

final lobbyServiceProvider = Provider<LobbyService>((ref) => SupabaseLobbyService());
final cardServiceProvider = Provider<CardService>((ref) => SupabaseCardService());
