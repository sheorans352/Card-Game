import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/game_models.dart';
import '../models/card_model.dart';
import '../services/lobby_service.dart';
import '../services/card_service.dart';
import '../config/env_config.dart';

// Removed dart:html to fix Vercel compilation issues

SupabaseClient get supabase => Supabase.instance.client;

// Track cards locally played in the current round to bypass Realtime lag.
final localPlayedCardsProvider = StateProvider<Set<String>>((ref) => {});

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
      .from('hands')
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

final playedCardsProvider = StreamProvider.family<List<Map<String, dynamic>>, String>((ref, roomId) {
  return supabase
      .from('played_cards')
      .stream(primaryKey: ['id'])
      .eq('room_id', roomId)
      .map((data) {
        final sorted = data.map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e)).toList();
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

// === UNIFIED PREDICTIVE TURN LOGIC ===
// Determines whose turn it is based on BOTH server state and local optimistic plays.
final predictiveTurnIdProvider = Provider.family<String?, String>((ref, roomId) {
  final room = ref.watch(roomMetadataByIdProvider(roomId)).value;
  if (room == null) return null;
  final players = ref.watch(playersStreamProvider(roomId)).value ?? [];
  if (players.isEmpty) return null;

  final serverPlayedCards = ref.watch(playedCardsProvider(roomId)).value ?? [];
  final localPlayed = ref.watch(localPlayedCardsProvider);
  
  // Combine server cards with local plays that haven't hit the server yet
  final serverCardIds = serverPlayedCards.map((m) => m['card_value'] as String).toSet();
  final localOnly = localPlayed.where((id) => !serverCardIds.contains(id)).toList();
  
  // Total cards played in this round (Server + Optimistic Local)
  final totalPlayedCount = serverPlayedCards.length + localOnly.length;
  
  if (totalPlayedCount == 0) {
    // Round just started, use the server's initial turn
    if (room.turnIndex < 0) return null;
    return players[room.turnIndex % players.length].id;
  }

  final trickSize = totalPlayedCount % players.length;
  
  if (trickSize == 0) {
    // A trick just finished. The winner of that trick leads the next one.
    final lastTrick = serverPlayedCards.length >= 4 
        ? serverPlayedCards.sublist(serverPlayedCards.length - 4)
        : serverPlayedCards; 
    
    if (lastTrick.length < 4) return players[room.turnIndex % players.length].id;

    final winnerId = Player.evaluateTrickWinner(lastTrick, room.trumpSuit, players);
    return winnerId;
  } else {
    // Trick is in progress. 
    String? leaderId;
    if (serverPlayedCards.length % players.length == 0) {
      // Server hasn't seen the first card of the new trick yet, but we have localOnly.
      final lastServerTrick = serverPlayedCards.sublist(serverPlayedCards.length - 4);
      leaderId = Player.evaluateTrickWinner(lastServerTrick, room.trumpSuit, players);
    } else {
      // Server already has some cards for the current trick.
      final currentTrickStart = (serverPlayedCards.length ~/ players.length) * players.length;
      leaderId = serverPlayedCards[currentTrickStart]['player_id'];
    }

    if (leaderId == null) return players[room.turnIndex % players.length].id;
    
    final leaderIndex = players.indexWhere((p) => p.id == leaderId);
    if (leaderIndex == -1) return players[room.turnIndex % players.length].id;
    
    return players[(leaderIndex + trickSize) % players.length].id;
  }
});

final playableCardsProvider = Provider.family<Set<String>, String>((ref, roomId) {
  final room = ref.watch(roomMetadataByIdProvider(roomId)).value;
  final localId = ref.watch(localPlayerIdProvider);
  if (room == null || localId == null || room.status != 'playing') return {};
  
  final players = ref.watch(playersStreamProvider(room.id)).value ?? [];
  if (players.isEmpty) return {};

  final hand = ref.watch(playerHandProvider(localId)).value ?? [];
  final playedCards = ref.watch(playedCardsProvider(room.id)).value ?? [];
  
  // === TURN CHECK (Predictive) ===
  final currentTurnId = ref.watch(predictiveTurnIdProvider(roomId));
  if (currentTurnId != localId) return {};
  
  final cardsInHand = hand.map((c) => c['card_value'] as String).toList();
  
  // Trick Logic
  final trickSize = playedCards.length % 4;
  if (trickSize == 0) return cardsInHand.toSet(); // Lead any card
  
  final currentTrick = playedCards.sublist(playedCards.length - trickSize);
  final leadCard = currentTrick.first['card_value'] as String;
  final leadSuit = leadCard.substring(leadCard.length - 1);
  final trumpSuit = room.trumpSuit;

  // 1. Must follow suit
  final cardsOfLeadSuit = cardsInHand.where((c) => c.endsWith(leadSuit)).toList();
  
  if (cardsOfLeadSuit.isNotEmpty) {
    // 2. MUST WIN RULE: Find highest card currently in trick of the lead suit
    int highestRank = 0;
    for (var m in currentTrick) {
      final cVal = m['card_value'] as String;
      if (cVal.endsWith(leadSuit)) {
        final r = Player.getRankValue(cVal.substring(0, cVal.length - 1));
        if (r > highestRank) highestRank = r;
      }
    }
    
    final winners = cardsOfLeadSuit.where((c) => Player.getRankValue(c) > highestRank).toList();
    if (winners.isNotEmpty) return winners.toSet(); // Forced to win if possible
    return cardsOfLeadSuit.toSet(); // Must follow suit
  }
  
  // 3. No lead suit -> Can play ANY card (Trump or discard)
  return cardsInHand.toSet();
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

final lobbyServiceProvider = Provider<LobbyService>((ref) => SupabaseLobbyService());
final cardServiceProvider = Provider<CardService>((ref) => SupabaseCardService());
