import '../models/card_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

abstract class CardService {
  List<CardModel> generateDeck();
  Future<void> shuffleDeck(String roomId);
  Future<void> cutDeck(String roomId, int cutPoint);
  Future<void> dealInitialFive(String roomId, List<String> playerIds);
  Future<void> dealRemainingEight(String roomId, List<String> playerIds);
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
    final room = await _supabase.from('rooms').select().eq('id', roomId).single();
    final List<dynamic> deck = room['shuffled_deck'];
    final splitIndex = (deck.length * (cutPoint / 100)).round();
    final newDeck = [...deck.sublist(splitIndex), ...deck.sublist(0, splitIndex)];

    await _supabase.from('rooms').update({
      'shuffled_deck': newDeck,
      'deck_cut_value': cutPoint,
      'status': 'dealing',
      'current_phase': 'dealing',
    }).eq('id', roomId);
  }

  @override
  Future<void> dealInitialFive(String roomId, List<String> playerIds) async {
    final room = await _supabase.from('rooms').select().eq('id', roomId).single();
    final List<dynamic> deck = room['shuffled_deck'];
    
    for (int i = 0; i < playerIds.length; i++) {
        final hand = deck.skip(i * 5).take(5).map((c) => {'player_id': playerIds[i], 'card_value': c}).toList();
        await _supabase.from('hands').insert(hand);
    }

    await _supabase.from('rooms').update({
      'status': 'bidding',
      'current_phase': 'bidding',
      'turn_index': (room['dealer_index'] + 1) % 4,
    }).eq('id', roomId);
  }

  @override
  Future<void> dealRemainingEight(String roomId, List<String> playerIds) async {
    final room = await _supabase.from('rooms').select().eq('id', roomId).single();
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
    // 1. Update player's bid
    await _supabase.from('players').update({
        'bid': bid,
    }).eq('id', playerId);

    // 2. Fetch latest room and players state
    final room = await _supabase.from('rooms').select().eq('id', roomId).single();
    final playersResponse = await _supabase.from('players').select().eq('room_id', roomId);
    final List<dynamic> players = playersResponse;
    
    final updates = <String, dynamic>{};
    if (suit != null) {
        updates['trump_suit'] = suit;
        if (bid >= 5) updates['trump_locked'] = true;
    }
    
    final nextTurnIndex = (room['turn_index'] + 1);
    updates['turn_index'] = nextTurnIndex;

    // 3. Phase Transition Logic
    final currentStatus = room['status'];
    final playersWithBids = players.where((p) => p['bid'] != null).length;

    if (currentStatus == 'bidding') {
      // Transition to bidding_2 if all 4 bid OR someone bids >= 5
      if (bid >= 5 || playersWithBids >= 4) {
        updates['status'] = 'bidding_2';
        updates['current_phase'] = 'bidding_2';
        // Reset turn index to player after dealer for the next phase
        updates['turn_index'] = (room['dealer_index'] + 1) % 4;
        
        await _supabase.from('rooms').update(updates).eq('id', roomId);
        
        // Trigger remaining deal (8 cards each)
        final pIds = players.map<String>((p) => p['id'] as String).toList();
        await dealRemainingEight(roomId, pIds);
        return;
      }
    } else if (currentStatus == 'bidding_2') {
      // Transition to playing after 4 more bids (total 8 slots filled if counting rounds, 
      // but here we just check if the last person in the round bid)
      if (nextTurnIndex % 4 == (room['dealer_index'] + 1) % 4) {
        updates['status'] = 'playing';
        updates['current_phase'] = 'playing';
        // Cutter starts the play (Dealer + 3)
        updates['turn_index'] = (room['dealer_index'] + 3) % 4;
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
