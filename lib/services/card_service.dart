import '../models/card_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

abstract class CardService {
  List<CardModel> generateDeck();
  Future<void> shuffleDeck(String roomId);
  Future<void> cutDeck(String roomId, int cutPoint);
  Future<void> dealInitialFive(String roomId, List<String> playerIds);
  Future<void> placeBid(String roomId, String playerId, int bid);
  Future<void> selectTrump(String roomId, String playerId, String suit);
  Future<void> playCard(String roomId, String playerId, String cardValue);
  Future<void> setPlayerReady(String roomId, String playerId);
  Future<void> dealPlayerBatch(String roomId, String playerId, int count);
  Future<void> finishPhase1Dealing(String roomId);
  Future<void> finishDealing(String roomId);
  Future<void> resetRoundData(String roomId);
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
    }).eq('id', roomId);

    // Fetch players and start initial deal automatically
    final playersResponse = await _supabase
        .from('players')
        .select('id')
        .eq('room_id', roomId)
        .order('joined_at', ascending: true);
    
    final playerIds = (playersResponse as List).map((p) => p['id'] as String).toList();
    if (playerIds.length == 4) {
      await dealInitialFive(roomId, playerIds);
    }
  }

  @override
  Future<void> dealInitialFive(String roomId, List<String> playerIds) async {
    // Call the atomic server-side RPC for 100% stability
    // This handles Shuffle, Clear Table, Dealer Selection, and Initial Deal
    await _supabase.rpc('start_deal_round', params: {'p_room_id': roomId});
    
    // UI Pause to let players see the "Dealer" badge move and the deck shuffle
    await Future.delayed(const Duration(milliseconds: 1500));
  }


  @override
  Future<void> placeBid(String roomId, String playerId, int bid) async {
    await _supabase.rpc('place_bid', params: {
      'p_room_id': roomId,
      'p_player_id': playerId,
      'p_bid': bid,
    });
  }

  @override
  Future<void> selectTrump(String roomId, String playerId, String suit) async {
    await _supabase.rpc('select_trump', params: {
      'p_room_id': roomId,
      'p_player_id': playerId,
      'p_suit': suit,
    });
  }

  @override
  Future<void> playCard(String roomId, String playerId, String cardValue) async {
    await _supabase.rpc('play_card', params: {
      'p_room_id': roomId,
      'p_player_id': playerId,
      'p_card_value': cardValue,
    });
  }

  @override
  Future<void> dealPlayerBatch(String roomId, String playerId, int count) async {
    await _supabase.rpc('deal_player_batch', params: {
      'p_room_id': roomId,
      'p_player_id': playerId,
      'p_count': count,
    });
  }

  @override
  Future<void> finishPhase1Dealing(String roomId) async {
    await _supabase.rpc('finish_phase_1_dealing', params: {
      'p_room_id': roomId,
    });
  }

  @override
  Future<void> finishDealing(String roomId) async {
    await _supabase.rpc('finish_dealing', params: {
      'p_room_id': roomId,
    });
  }


  @override
  Future<void> setPlayerReady(String roomId, String playerId) async {
    await _supabase.rpc('set_player_ready', params: {
      'p_room_id': roomId,
      'p_player_id': playerId,
    });
  }

  @override
  Future<void> resetRoundData(String roomId) async {
    await _supabase.rpc('end_round', params: {
      'p_room_id': roomId,
    });
  }

  @override
  Future<bool> validateMove(
    String roomId,
    String playerId,
    String cardValue,
    List<Map<String, dynamic>> currentTrick,
    List<String> playerHand,
    String? trumpSuit,
  ) async {
    // Leading the trick — any card is valid
    if (currentTrick.isEmpty) return true;

    final leadCard = CardModel.fromId(currentTrick.first['card_value'] as String);
    final leadSuit = leadCard.suit;
    final playedCard = CardModel.fromId(cardValue);
    final trumpSuitEnum = _parseSuit(trumpSuit);
    final handCards = playerHand.map((c) => CardModel.fromId(c)).toList();

    final hasSameSuit = handCards.any((c) => c.suit == leadSuit);
    final isTrumpOnTable = currentTrick.any((t) {
      final tc = CardModel.fromId(t['card_value'] as String);
      return tc.suit == trumpSuitEnum;
    });

    if (hasSameSuit) {
      // Rule 1: Must follow lead suit
      if (playedCard.suit != leadSuit) return false;

      // If a Trump is on the table cutting the trick, you don't have to waste your high lead cards
      // EXCEPT when the lead suit itself IS the Trump suit!
      if (!isTrumpOnTable || leadSuit == trumpSuitEnum) {
        CardModel? currentBestLead;
        for (var t in currentTrick) {
          final tc = CardModel.fromId(t['card_value'] as String);
          if (tc.suit == leadSuit) {
            if (currentBestLead == null || tc.rank > currentBestLead.rank) currentBestLead = tc;
          }
        }
        // If player can beat the best lead card, they MUST
        if (currentBestLead != null) {
          final canBeat = handCards.any((c) => c.suit == leadSuit && c.rank > currentBestLead!.rank);
          if (canBeat && playedCard.rank <= currentBestLead.rank) return false;
        }
      }
      return true;
    }

    // No lead-suit cards in hand -> Option: ANY card is valid (Trump or Throwaway)
    return true;
  }

  Suit? _parseSuit(String? code) {
    switch (code) {
      case 'S': return Suit.spades;
      case 'H': return Suit.hearts;
      case 'D': return Suit.diamonds;
      case 'C': return Suit.clubs;
      default: return null;
    }
  }
}
