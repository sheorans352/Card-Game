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

import '../services/card_service.dart';
import '../config/env_config.dart';

SupabaseClient get supabase => Supabase.instance.client;

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
        sorted.sort((a, b) => (a['joined_at']?.toString() ?? '').compareTo(b['joined_at']?.toString() ?? ''));
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
      .map((data) => data.map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e)).toList())
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
        sorted.sort((a, b) => (a['played_at'] as String).compareTo(b['played_at'] as String));
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

final playableCardsProvider = Provider.family<Set<String>, String>((ref, roomId) {
  final room = ref.watch(roomMetadataByIdProvider(roomId)).value;
  final localId = ref.watch(localPlayerIdProvider);
  if (room == null || localId == null || room.status != 'playing') return {};
  
  final players = ref.watch(playersStreamProvider(room.id)).value;
  if (players == null) return {};

  final hand = ref.watch(playerHandProvider(localId)).value ?? [];
  final playedCards = ref.watch(playedCardsProvider(room.id)).value ?? [];
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
        final r = _getRankValue(cVal.substring(0, cVal.length - 1));
        if (r > highestRank) highestRank = r;
      }
    }
    
    final winners = cardsOfLeadSuit.where((c) => _getRankValue(c.substring(0, c.length - 1)) > highestRank).toList();
    if (winners.isNotEmpty) return winners.toSet(); // Forced to win if possible
    return cardsOfLeadSuit.toSet(); // Must follow suit
  }
  
  // 3. No lead suit -> Can play Trump or anything
  if (trumpSuit != null) {
     final trumps = cardsInHand.where((c) => c.endsWith(trumpSuit)).toList();
     if (trumps.isNotEmpty) return trumps.toSet(); // Forced to trump if possible
  }

  return cardsInHand.toSet();
});

int _getRankValue(String v) {
  if (v == 'A') return 14;
  if (v == 'K') return 13;
  if (v == 'Q') return 12;
  if (v == 'J') return 11;
  return int.parse(v);
}

final isLocalPlayerTurnProvider = Provider.family<bool, String>((ref, code) {
  final room = ref.watch(roomMetadataProvider(code)).value;
  final players = ref.watch(playersStreamProvider(room?.id ?? "")).value;
  final localId = ref.watch(localPlayerIdProvider);
  if (room == null || players == null || localId == null) return false;
  if (room.status == 'waiting') return false;
  if (room.status == 'cutting') {
    final cutterIndex = (room.dealerIndex + 1) % players.length;
    return players[cutterIndex].id == localId;
  }
  if (room.status == 'bidding' || room.status == 'bidding_2' || room.status == 'playing' || room.status == 'trump_selection') {
    // Scenario A: trump setter doesn't declare in bidding_2 (their Phase 1 bid is committed)
    if (room.status == 'bidding_2' && room.highestBidderId != null && localId == room.highestBidderId) {
      return false;
    }
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
