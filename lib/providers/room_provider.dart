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

// Shared state for Mock (In-memory to avoid dart:html conflicts)
class LocalStorageSync {
  static const String roomKey = 'minus_mock_room';
  static const String playersKey = 'minus_mock_players';
  static const String handsKey = 'minus_mock_hands';
  static const String playedCardsKey = 'minus_mock_played';

  static final Map<String, String> _storage = {};

  static void reset() {
    _storage.clear();
  }

  static T getData<T>(String key, T Function(dynamic) fromJson) {
    final data = _storage[key];
    if (data == null) return null as T;
    return fromJson(jsonDecode(data));
  }

  static void setData(String key, dynamic data) {
    _storage[key] = jsonEncode(data);
  }
}

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
  final config = ref.watch(appConfigProvider);
  if (config.useMock) {
    return Stream.value(null);
  } else {
    return supabase
        .from('rooms')
        .stream(primaryKey: ['id'])
        .eq('code', code)
        .map<Room?>((data) => data.isEmpty ? null : Room.fromJson(Map<String, dynamic>.from(data.first)))
        .handleError((error) {
          debugPrint('Supabase Stream Error (Room): $error');
          throw error;
        });
  }
});

final playersStreamProvider = StreamProvider.family<List<Player>, String>((ref, roomId) {
  final config = ref.watch(appConfigProvider);
  if (config.useMock) {
    return Stream.value([]);
  } else {
    return supabase
        .from('players')
        .stream(primaryKey: ['id'])
        .eq('room_id', roomId)
        .map((data) {
          final sorted = List<Map<String, dynamic>>.from(data);
          sorted.sort((a, b) => (a['joined_at'] as String).compareTo(b['joined_at'] as String));
          return sorted.map<Player>((p) => Player.fromJson(p)).toList();
        })
        .handleError((error) {
          debugPrint('Supabase Stream Error (Players): $error');
          throw error;
        });
  }
});

final playerHandProvider = StreamProvider.family<List<Map<String, dynamic>>, String>((ref, playerId) {
  final config = ref.watch(appConfigProvider);
  if (config.useMock) {
    return Stream.value([]);
  } else {
    return supabase
        .from('hands')
        .stream(primaryKey: ['id'])
        .eq('player_id', playerId)
        .map((data) => data.map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e)).toList())
        .handleError((error) {
          debugPrint('Supabase Stream Error (Hand): $error');
          throw error;
        });
  }
});

final playedCardsProvider = StreamProvider.family<List<Map<String, dynamic>>, String>((ref, roomId) {
  final config = ref.watch(appConfigProvider);
  if (config.useMock) {
    return Stream.value([]);
  } else {
    return supabase
        .from('played_cards')
        .stream(primaryKey: ['id'])
        .eq('room_id', roomId)
        .map((data) {
          final sorted = data.map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e)).toList();
          sorted.sort((a, b) => (a['created_at'] as String).compareTo(b['created_at'] as String));
          return sorted;
        })
        .handleError((error) {
          debugPrint('Supabase Stream Error (PlayedCards): $error');
          throw error;
        });
  }
});

final roundResultsProvider = StreamProvider.family<List<Map<String, dynamic>>, String>((ref, roomId) {
  final config = ref.watch(appConfigProvider);
  if (config.useMock) {
    return Stream.value([]);
  } else {
    return supabase
        .from('round_results')
        .stream(primaryKey: ['id'])
        .eq('room_id', roomId)
        .map((data) => data.map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e)).toList())
        .handleError((error) {
          debugPrint('Supabase Stream Error (RoundResults): $error');
          throw error;
        });
  }
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
    // 2. MUST WIN RULE: enforced in mock too!
    // Find highest card currently in trick of the lead suit
    int highestRank = 0;
    for (var m in currentTrick) {
      final cVal = m['card_value'] as String;
      if (cVal.endsWith(leadSuit)) {
        final r = _getRankValue(cVal.substring(0, cVal.length - 1));
        if (r > highestRank) highestRank = r;
      }
    }
    
    final winners = cardsOfLeadSuit.where((c) => _getRankValue(c.substring(0, c.length - 1)) > highestRank).toList();
    if (winners.isNotEmpty) return winners.toSet(); // Forced to win
    return cardsOfLeadSuit.toSet(); // Just follow suit
  }
  
  // 3. No lead suit -> Can play Trump or anything
  if (trumpSuit != null) {
     final trumps = cardsInHand.where((c) => c.endsWith(trumpSuit)).toList();
     if (trumps.isNotEmpty) return trumps.toSet(); // Simple mock: forced to trump if no lead suit
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

final lobbyServiceProvider = Provider<LobbyService>((ref) {
  final config = ref.watch(appConfigProvider);
  if (config.useMock) return MockLobbyService();
  return SupabaseLobbyService(); // Placeholder for future real service
});

final cardServiceProvider = Provider<CardService>((ref) {
  final config = ref.watch(appConfigProvider);
  if (config.useMock) return MockCardService();
  return SupabaseCardService(); // Placeholder for future real service
});

class MockLobbyService extends LobbyService {
  @override
  Future<Map<String, String>> createRoom(String hostName) async {
    LocalStorageSync.reset(); // Always start fresh for a new Host session
    final roomId = 'mock-room-${DateTime.now().millisecondsSinceEpoch}';
    final roomCode = (100000 + (DateTime.now().millisecondsSinceEpoch % 900000)).toString();
    const playerId = 'p1';
    final room = Room(id: roomId, code: roomCode, status: 'waiting', hostId: playerId, currentPhase: 'lobby', dealerIndex: 0, turnIndex: 0);
    final player = Player(id: playerId, roomId: roomId, name: hostName, isHost: true, totalScore: 0);
    LocalStorageSync.setData(LocalStorageSync.roomKey, room.toJson());
    LocalStorageSync.setData(LocalStorageSync.playersKey, [player.toJson()]);
    LocalStorageSync.setData(LocalStorageSync.handsKey, {});
    LocalStorageSync.setData(LocalStorageSync.playedCardsKey, []);
    return {'roomCode': roomCode, 'playerId': playerId};
  }

  @override
  Future<Map<String, String>?> joinRoom(String code, String playerName) async {
    final room = LocalStorageSync.getData(LocalStorageSync.roomKey, (j) => Room.fromJson(j));
    if (room == null || room.code != code) return null;
    final players = LocalStorageSync.getData<List<Player>>(LocalStorageSync.playersKey, (j) => (j as List).map<Player>((p) => Player.fromJson(p)).toList());
    if (players.length >= 4) return null;
    final playerId = 'p${players.length + 1}';
    final newPlayer = Player(id: playerId, roomId: room.id, name: playerName, isHost: false, totalScore: 0);
    players.add(newPlayer);
    LocalStorageSync.setData(LocalStorageSync.playersKey, players.map((p) => p.toJson()).toList());
    return {'playerId': playerId};
  }

  @override
  Future<void> startGame(String roomId) async {
    final room = LocalStorageSync.getData(LocalStorageSync.roomKey, (j) => Room.fromJson(j));
    final nextRoom = room.copyWith(status: 'shuffling', currentPhase: 'shuffling');
    LocalStorageSync.setData(LocalStorageSync.roomKey, nextRoom.toJson());
    await MockCardService().shuffleDeck(roomId);
  }
}

class MockCardService extends CardService {
  @override
  Future<void> shuffleDeck(String roomId) async {
    final suits = ['S', 'H', 'D', 'C'];
    final values = ['2', '3', '4', '5', '6', '7', '8', '9', '10', 'J', 'Q', 'K', 'A'];
    List<String> deck = [];
    for (var s in suits) for (var v in values) deck.add('$v$s');
    deck.shuffle();
    final room = LocalStorageSync.getData(LocalStorageSync.roomKey, (j) => Room.fromJson(j));
    final nextRoom = room.copyWith(shuffledDeck: deck, status: 'cutting', currentPhase: 'cutting');
    LocalStorageSync.setData(LocalStorageSync.roomKey, nextRoom.toJson());
  }

  @override
  Future<void> cutDeck(String roomId, int cutPoint) async {
    final room = LocalStorageSync.getData(LocalStorageSync.roomKey, (j) => Room.fromJson(j));
    final deck = room.shuffledDeck;
    final splitIndex = (deck.length * (cutPoint / 100)).round();
    final newDeck = [...deck.sublist(splitIndex), ...deck.sublist(0, splitIndex)];
    final nextRoom = room.copyWith(shuffledDeck: newDeck, deckCutValue: cutPoint, status: 'dealing', currentPhase: 'dealing', turnIndex: (room.dealerIndex + 1) % 4);
    LocalStorageSync.setData(LocalStorageSync.roomKey, nextRoom.toJson());
    // Auto deal initial 5
    final players = LocalStorageSync.getData<List<Player>>(LocalStorageSync.playersKey, (j) => (j as List).map<Player>((p) => Player.fromJson(p)).toList());
    await dealInitialFive(roomId, players.map((p) => p.id).toList());
  }

  @override
  Future<void> dealInitialFive(String roomId, List<String> playerIds) async {
    final room = LocalStorageSync.getData(LocalStorageSync.roomKey, (j) => Room.fromJson(j));
    final deck = room.shuffledDeck;
    final hands = <String, dynamic>{};
    
    // Ordered Dealing: 5 to P1, then 5 to P2, etc. with deliberate delays
    for (int i = 0; i < playerIds.length; i++) {
      final pId = playerIds[i];
      final cardsForPlayer = deck.skip(i * 5).take(5).map((c) => {'card_value': c}).toList();
      hands[pId] = cardsForPlayer;
      LocalStorageSync.setData(LocalStorageSync.handsKey, hands);
      await Future.delayed(const Duration(milliseconds: 600)); // Deliberate pace
    }

    final nextRoom = room.copyWith(
      status: 'bidding', 
      currentPhase: 'bidding', 
      trumpSuit: 'S',
      turnIndex: (room.dealerIndex + 1) % 4, // Cutter starts
    );
    LocalStorageSync.setData(LocalStorageSync.roomKey, nextRoom.toJson());
  }

  @override
  Future<void> dealNextFour(String roomId, List<String> playerIds) async {
    final room = LocalStorageSync.getData(LocalStorageSync.roomKey, (j) => Room.fromJson(j));
    final deck = room.shuffledDeck;
    final hands = LocalStorageSync.getData(LocalStorageSync.handsKey, (j) => j as Map<String, dynamic>);
    
    // Sequential Dealing: 4 to each, one by one
    for (int i = 0; i < playerIds.length; i++) {
      final pId = playerIds[i];
      final existing = (hands[pId] as List).cast<Map<String, dynamic>>();
      final extra = deck.skip(20 + i * 4).take(4).map((c) => {'card_value': c}).toList();
      hands[pId] = [...existing, ...extra];
      LocalStorageSync.setData(LocalStorageSync.handsKey, hands);
      await Future.delayed(const Duration(milliseconds: 500)); // Deliberate pace
    }

    final nextRoom = room.copyWith(status: 'dealing_2', currentPhase: 'dealing_2');
    LocalStorageSync.setData(LocalStorageSync.roomKey, nextRoom.toJson());
  }

  @override
  Future<void> dealFinalFour(String roomId, List<String> playerIds) async {
    final room = LocalStorageSync.getData(LocalStorageSync.roomKey, (j) => Room.fromJson(j));
    final deck = room.shuffledDeck;
    final hands = LocalStorageSync.getData(LocalStorageSync.handsKey, (j) => j as Map<String, dynamic>);
    
    // Sequential Dealing: Final 4 to each
    for (int i = 0; i < playerIds.length; i++) {
      final pId = playerIds[i];
      final existing = (hands[pId] as List).cast<Map<String, dynamic>>();
      final extra = deck.skip(36 + i * 4).take(4).map((c) => {'card_value': c}).toList();
      hands[pId] = [...existing, ...extra];
      LocalStorageSync.setData(LocalStorageSync.handsKey, hands);
      await Future.delayed(const Duration(milliseconds: 500)); // Deliberate pace
    }

    final nextRoom = room.copyWith(
      status: 'bidding_2', 
      currentPhase: 'bidding_2', 
      turnIndex: (room.dealerIndex + 1) % 4 // Cutter starts
    );
    LocalStorageSync.setData(LocalStorageSync.roomKey, nextRoom.toJson());
  }

  @override
  Future<void> dealRemainingEight(String roomId, List<String> playerIds) async {}

  @override
  Future<void> selectTrump(String roomId, String playerId, String suit) async {}

  @override
  Future<void> placeBid(String roomId, String playerId, int bid) async {
    final players = LocalStorageSync.getData<List<Player>>(LocalStorageSync.playersKey, (j) => (j as List).map<Player>((p) => Player.fromJson(p)).toList());
    final room = LocalStorageSync.getData(LocalStorageSync.roomKey, (j) => Room.fromJson(j));
    final pIdx = players.indexWhere((p) => p.id == playerId);
    players[pIdx] = players[pIdx].copyWith(bid: bid);
    LocalStorageSync.setData(LocalStorageSync.playersKey, players.map((p) => p.toJson()).toList());
    var nextRoom = room.copyWith(turnIndex: room.turnIndex + 1);

    // In Round 1 (bidding), if everyone has acted:
    if (room.status == 'bidding') {
      if (nextRoom.turnIndex % 4 == (room.dealerIndex + 1) % 4) {
        // Simple mock: if someone bid 5, they win and pick trump (mock just picks S)
        // This is a mock so we just advance to Stage 2 for simplicity
        LocalStorageSync.setData(LocalStorageSync.roomKey, nextRoom.toJson());
        final pIds = players.map((p) => p.id).toList();
        await dealNextFour(roomId, pIds);
        await dealFinalFour(roomId, pIds);
        return;
      }
    } else if (room.status == 'bidding_2') {
      if (nextRoom.turnIndex % 4 == (room.dealerIndex + 1) % 4) {
        nextRoom = nextRoom.copyWith(status: 'playing', currentPhase: 'playing', turnIndex: (room.dealerIndex + 1) % 4);
      }
    }
    LocalStorageSync.setData(LocalStorageSync.roomKey, nextRoom.toJson());
  }

  @override
  Future<void> playCard(String roomId, String playerId, String cardValue) async {
    final allHands = LocalStorageSync.getData(LocalStorageSync.handsKey, (j) => j as Map<String, dynamic>);
    final hand = allHands[playerId] as List;
    hand.removeWhere((c) => c['card_value'] == cardValue);
    LocalStorageSync.setData(LocalStorageSync.handsKey, allHands);
    final playedCards = LocalStorageSync.getData<List<Map<String, dynamic>>>(LocalStorageSync.playedCardsKey, (j) => (j as List).cast<Map<String, dynamic>>());
    playedCards.add({'player_id': playerId, 'card_value': cardValue});
    LocalStorageSync.setData(LocalStorageSync.playedCardsKey, playedCards);
    final room = LocalStorageSync.getData(LocalStorageSync.roomKey, (j) => Room.fromJson(j));
    var nextRoom = room.copyWith(turnIndex: room.turnIndex + 1);
    if (playedCards.length % 4 == 0) {
      // Evaluate winner and scoring... (Phase 6)
      if (playedCards.length == 52) { // Round Finished
         final playersData = LocalStorageSync.getData<List<Player>>(LocalStorageSync.playersKey, (j) => (j as List).map<Player>((p) => Player.fromJson(p)).toList());
         // Simple mock score calc:
         for (int i = 0; i < playersData.length; i++) {
           final p = playersData[i];
           final scoreChange = (p.tricksWon >= (p.bid ?? 0)) ? (p.bid ?? 0) : -(p.bid ?? 0);
           playersData[i] = p.copyWith(totalScore: p.totalScore + scoreChange, bid: null, tricksWon: 0);
         }
         LocalStorageSync.setData(LocalStorageSync.playersKey, playersData.map((p) => p.toJson()).toList());
         nextRoom = nextRoom.copyWith(status: 'game_over', currentPhase: 'game_over');
      }
    }
    LocalStorageSync.setData(LocalStorageSync.roomKey, nextRoom.toJson());
  }

  @override
  List<CardModel> generateDeck() {
    final List<CardModel> deck = [];
    final suits = Suit.values;
    for (final suit in suits) {
      for (int r = 2; r <= 14; r++) {
        String val;
        if (r == 14) val = 'A';
        else if (r == 13) val = 'K';
        else if (r == 12) val = 'Q';
        else if (r == 11) val = 'J';
        else val = r.toString();
        deck.add(CardModel(suit: suit, value: val, rank: r));
      }
    }
    return deck;
  }

  @override
  Future<bool> validateMove(String roomId, String playerId, String cardValue, List<Map<String, dynamic>> currentTrick, List<String> playerHand, String? trumpSuit) async {
    // In mock, allow all moves for now to simplify testing
    return true;
  }
}
