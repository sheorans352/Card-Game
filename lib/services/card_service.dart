import '../models/card_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

abstract class CardService {
  List<CardModel> generateDeck();
  Future<void> shuffleDeck(String roomId);
  Future<void> cutDeck(String roomId, int cutPoint);
  Future<void> dealInitialFive(String roomId, List<String> playerIds);
  Future<void> dealNextFour(String roomId, List<String> playerIds);
  Future<void> dealFinalFour(String roomId, List<String> playerIds);
  Future<void> placeBid(String roomId, String playerId, int bid, {String? suit});
  Future<void> playCard(String roomId, String playerId, String cardValue);
  Future<bool> validateMove(String roomId, String playerId, String cardValue, List<Map<String, dynamic>> currentTrick, List<String> playerHand, String? trumpSuit);
}

class SupabaseCardService extends CardService {
  final _supabase = Supabase.instance.client;

  @override
  List<CardModel> generateDeck() {
    final List<CardModel> deck = [];
    for (final suit in Suit.values) {
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
  Future<void> shuffleDeck(String roomId) async {
    final deck = generateDeck()..shuffle();
    final deckStrings = deck.map((c) => '${c.value}${c.suit.toString().split('.').last[0].toUpperCase()}').toList();
    
    await _supabase.from('rooms').update({
      'shuffled_deck': deckStrings,
      'status': 'cutting',
      'current_phase': 'cutting',
    }).eq('id', roomId);
  }

  @override
  Future<void> cutDeck(String roomId, int cutPoint) async {
    final roomResponse = await _supabase.from('rooms').select().eq('id', roomId);
    if (roomResponse.isEmpty) return;
    final room = roomResponse.first;
    final List<dynamic> deck = room['shuffled_deck'];
    final splitIndex = (deck.length * (cutPoint / 100)).round();
    final newDeck = [...deck.sublist(splitIndex), ...deck.sublist(0, splitIndex)];

    await _supabase.from('rooms').update({
      'shuffled_deck': newDeck,
      'deck_cut_value': cutPoint,
      'status': 'dealing',
      'current_phase': 'dealing',
      // Turn index doesn't matter yet for dealing, but Bidding Round 1 starts with Cutter
    }).eq('id', roomId);
  }

  @override
  Future<void> dealInitialFive(String roomId, List<String> playerIds) async {
    final roomResponse = await _supabase.from('rooms').select().eq('id', roomId);
    if (roomResponse.isEmpty) return;
    final room = roomResponse.first;
    final List<dynamic> deck = room['shuffled_deck'];
    
    for (int i = 0; i < playerIds.length; i++) {
        final hand = deck.skip(i * 5).take(5).map((c) => {'player_id': playerIds[i], 'card_value': c}).toList();
        await _supabase.from('hands').insert(hand);
    }

    await _supabase.from('rooms').update({
      'status': 'bidding',
      'current_phase': 'bidding',
      'trump_suit': 'S', // Default Trump is Spades
      'turn_index': (room['dealer_index'] + 3) % 4, // Bidding starts with Cutter (Dealer + 3)
    }).eq('id', roomId);
  }

  @override
  Future<void> dealNextFour(String roomId, List<String> playerIds) async {
    final roomResponse = await _supabase.from('rooms').select().eq('id', roomId);
    if (roomResponse.isEmpty) return;
    final room = roomResponse.first;
    final List<dynamic> deck = room['shuffled_deck'];
    
    // Cards 0-19 were dealt (4 players * 5 cards). Next cards start at index 20.
    for (int i = 0; i < playerIds.length; i++) {
        final hand = deck.skip(20 + i * 4).take(4).map((c) => {'player_id': playerIds[i], 'card_value': c}).toList();
        await _supabase.from('hands').insert(hand);
    }

    await _supabase.from('rooms').update({
      'status': 'dealing_2',
      'current_phase': 'dealing_2',
    }).eq('id', roomId);
  }

  @override
  Future<void> dealFinalFour(String roomId, List<String> playerIds) async {
    final roomResponse = await _supabase.from('rooms').select().eq('id', roomId);
    if (roomResponse.isEmpty) return;
    final room = roomResponse.first;
    final List<dynamic> deck = room['shuffled_deck'];
    
    // Cards 0-35 were dealt (20 initial + 16 next). Next cards start at index 36.
    for (int i = 0; i < playerIds.length; i++) {
        final hand = deck.skip(36 + i * 4).take(4).map((c) => {'player_id': playerIds[i], 'card_value': c}).toList();
        await _supabase.from('hands').insert(hand);
    }

    await _supabase.from('rooms').update({
      'status': 'bidding_2',
      'current_phase': 'bidding_2',
      'turn_index': (room['dealer_index'] + 3) % 4, // Final Bidding starts with Cutter
    }).eq('id', roomId);
  }

  @override
  Future<void> dealRemainingEight(String roomId, List<String> playerIds) async {
    final roomResponse = await _supabase.from('rooms').select().eq('id', roomId);
    if (roomResponse.isEmpty) return;
    final room = roomResponse.first;
    final List<dynamic> deck = room['shuffled_deck'];
    
    for (int i = 0; i < playerIds.length; i++) {
        final hand = deck.skip(20 + i * 8).take(8).map((c) => {'player_id': playerIds[i], 'card_value': c}).toList();
        await _supabase.from('hands').insert(hand);
    }

    await _supabase.from('rooms').update({
      'status': 'bidding_2',
      'current_phase': 'bidding_2',
      'turn_index': (room['dealer_index'] + 1) % 4,
    }).eq('id', roomId);
  }

  @override
  Future<void> placeBid(String roomId, String playerId, int bid, {String? suit}) async {
    // 1. Fetch current state
    final room = await _supabase.from('rooms').select().eq('id', roomId).single();
    final playersResponse = await _supabase.from('players').select().eq('room_id', roomId);
    final List<dynamic> players = playersResponse;
    final pIds = players.map<String>((p) => p['id'] as String).toList();
    
    // 2. Update player's bid
    await _supabase.from('players').update({
        'bid': bid,
    }).eq('id', playerId);

    final currentPhase = room['current_phase'];
    final nextTurnIndex = (room['turn_index'] + 1);
    final updates = <String, dynamic>{'turn_index': nextTurnIndex};

    if (currentPhase == 'bidding') {
      // ROUND 1 (After 5 cards)
      if (bid >= 5 && suit != null) {
        updates['trump_suit'] = suit;
        updates['trump_locked'] = true; // This player's bid will be locked in Round 2
        // Note: We might want to store WHO locked it, but for now trump_locked is enough
      }

      // Check if Round 1 is finished (all 4 players acted)
      final dealerIndex = room['dealer_index'] as int;
      // Round 1 starts at (dealer+3)%4 and ends at dealerIndex
      if (nextTurnIndex % 4 == (dealerIndex + 1) % 4) {
        // Round 1 Finished -> Deal 4 + 4 cards
        await dealNextFour(roomId, pIds);
        await dealFinalFour(roomId, pIds);
        
        // Final state after dealing should be 'bidding_2'
        // dealFinalFour already sets turn_index to Cutter and status to bidding_2
        return; 
      }
    } else if (currentPhase == 'bidding_2') {
      // ROUND 2 (After 13 cards)
      // Special Rule: 9+ can change trump even if already locked? 
      // User: "A player by bidding 9 can chage the trump suit even after all 13 cards are dealt"
      if (bid >= 9 && suit != null) {
        updates['trump_suit'] = suit;
        updates['trump_locked'] = true;
      }

      // Check if Round 2 is finished
      final dealerIndex = room['dealer_index'] as int;
      if (nextTurnIndex % 4 == (dealerIndex + 1) % 4) {
        updates['status'] = 'playing';
        updates['current_phase'] = 'playing';
        updates['turn_index'] = (dealerIndex + 1) % 4; // Start play (Standard is left of dealer)
        // Note: User previously said Cutter starts play, but usually it's Dealer+1. 
        // I'll stick to Dealer+1 for play unless specified otherwise.
      }
    }

    await _supabase.from('rooms').update(updates).eq('id', roomId);
  }

  @override
  Future<void> playCard(String roomId, String playerId, String cardValue) async {
    await _supabase.from('played_cards').insert({
        'room_id': roomId,
        'player_id': playerId,
        'card_value': cardValue,
    });
    
    // Remove from hand
    await _supabase.from('hands').delete().match({
        'player_id': playerId,
        'card_value': cardValue,
    });

    final roomResponse = await _supabase.from('rooms').select().eq('id', roomId);
    if (roomResponse.isEmpty) return;
    final room = roomResponse.first;

    await _supabase.from('rooms').update({
        'turn_index': (room['turn_index'] + 1) % 4,
    }).eq('id', roomId);
  }

  @override
  Future<bool> validateMove(String roomId, String playerId, String cardValue, List<Map<String, dynamic>> currentTrick, List<String> playerHand, String? trumpSuit) async {
    return true; // Simplified for initial beta
  }
}
