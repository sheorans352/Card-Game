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

final playableCardsProvider = Provider.family<Set<String>, String>((ref, roomId) {
  final roomCode = ref.watch(currentRoomCodeProvider);
  if (roomCode == null) return <String>{};

  final roomAsync = ref.watch(roomMetadataProvider(roomCode));
  final playedCardsAsync = ref.watch(playedCardsProvider(roomId));
  final localPlayerId = ref.watch(localPlayerIdProvider);

  if (localPlayerId == null) return <String>{};

  return roomAsync.maybeWhen(
    data: (room) {
      if (room == null || room.currentPhase != 'playing') return <String>{};
      
      return playedCardsAsync.maybeWhen(
        data: (allPlayed) {
          final trickSize = allPlayed.length % 4;
          final trick = allPlayed.sublist(allPlayed.length - trickSize);
          
          final handsAsync = ref.watch(playerHandProvider(localPlayerId));
          return handsAsync.maybeWhen(
            data: (handMaps) {
              final hand = handMaps.map((m) => CardModel.fromId(m['card_value'] as String)).toList();
              if (hand.isEmpty) return <String>{};
              if (trickSize == 0) return hand.map((c) => c.id).toSet();

              final leadCard = CardModel.fromId(trick[0]['card_value'] as String);
              final leadSuit = leadCard.suit;
              final trumpSuitCode = room.trumpSuit;

              // 1. Identify best card currently on table
              CardModel bestOnTable = leadCard;
              for (var i = 1; i < trick.length; i++) {
                final current = CardModel.fromId(trick[i]['card_value'] as String);
                bool isBetter = false;
                if (current.suit.code == trumpSuitCode && bestOnTable.suit.code != trumpSuitCode) {
                  isBetter = true;
                } else if (current.suit == bestOnTable.suit && current.rank > bestOnTable.rank) {
                  isBetter = true;
                }
                if (isBetter) bestOnTable = current;
              }

              // Rule 1: MUST follow suit if possible
              final handLeadSuit = hand.where((c) => c.suit == leadSuit).toList();
              if (handLeadSuit.isNotEmpty) {
                // Must Play Higher for lead suit
                if (bestOnTable.suit == leadSuit) {
                  final higherLead = handLeadSuit.where((c) => c.rank > bestOnTable.rank).toList();
                  if (higherLead.isNotEmpty) {
                    return higherLead.map((c) => c.id).toSet();
                  }
                }
                return handLeadSuit.map((c) => c.id).toSet();
              }

              // Rule 2: If OUT of lead suit, player can play ANY SUIT.
              // Logic: If they choose to play a Spade, and can beat the table, they MUST play a higher Spade.
              final otherSuits = hand.where((c) => c.suit.code != 'S').toList();
              final spadsInHand = hand.where((c) => c.suit.code == 'S').toList();
              
              int maxSpadeOnTable = 0;
              for (var tc in trick) {
                final c = CardModel.fromId(tc['card_value'] as String);
                if (c.suit.code == 'S' && c.rank > maxSpadeOnTable) maxSpadeOnTable = c.rank;
              }

              final higherSpades = spadsInHand.where((c) => c.rank > maxSpadeOnTable).toList();
              
              final Set<String> validIds = otherSuits.map((c) => c.id).toSet();
              if (higherSpades.isNotEmpty) {
                validIds.addAll(higherSpades.map((c) => c.id));
              } else {
                validIds.addAll(spadsInHand.map((c) => c.id));
              }

              return validIds;
            },
            orElse: () => <String>{},
          );
        },
        orElse: () => <String>{},
      );
    },
    orElse: () => <String>{},
  );
});

final isCutterProvider = Provider.family<bool, String>((ref, code) {
  final roomAsync = ref.watch(roomMetadataProvider(code));
  final localPlayerId = ref.watch(localPlayerIdProvider);

  return roomAsync.maybeWhen(
    data: (room) {
      if (room == null || localPlayerId == null) return false;
      final playersAsync = ref.watch(playersStreamProvider(room.id));
      return playersAsync.maybeWhen(
        data: (players) {
          final cutterIndex = (room.dealerIndex - 1 + players.length) % players.length;
          return players[cutterIndex].id == localPlayerId;
        },
        orElse: () => false,
      );
    },
    orElse: () => false,
  );
});
