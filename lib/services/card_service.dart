import '../models/card_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

abstract class CardService {
  List<CardModel> generateDeck();
  Future<void> shuffleDeck(String roomId);
  Future<void> cutDeck(String roomId, int cutPoint);
  Future<void> dealInitialFive(String roomId, List<String> playerIds);
  Future<void> dealRemainingEight(String roomId, List<String> playerIds);
  Future<void> placeBid(String roomId, String playerId, int bid);
  Future<void> selectTrump(String roomId, String playerId, String suit);
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
    final roomResponse = await _supabase.from('rooms').select().eq('id', roomId);
    if (roomResponse.isEmpty) return;
    final room = roomResponse.first;
    final List<dynamic> deck = room['shuffled_deck'];
    final int dealerIndex = room['dealer_index'] ?? 0;
    // Cutter is to the LEFT of dealer — matches isCutterProvider: (dealerIndex + 3) % 4
    final int cutterIndex = (dealerIndex + 3) % 4;
    
    // Clear all old hands for these players
    for (final pid in playerIds) {
      try { await _supabase.from('hands').delete().eq('player_id', pid); } catch (_) {}
    }
    
    // Build clockwise order starting from cutter
    final List<String> orderedPlayers = List.generate(4, (i) => playerIds[(cutterIndex + i) % 4]);

    // === DEAL ROUND 1: 5 cards each (deck[0..19]) ===
    for (int i = 0; i < 4; i++) {
      final hand = deck.skip(i * 5).take(5).map((c) => {
        'room_id': roomId,
        'player_id': orderedPlayers[i],
        'card_value': c,
      }).toList();
      await _supabase.from('hands').insert(hand);
      await Future.delayed(const Duration(milliseconds: 500));
    }

    // Phase: bidding (5 cards in hand, bid on trump)
    await _supabase.from('rooms').update({
      'status': 'bidding',
      'current_phase': 'bidding',
      'trump_suit': null,
      'highest_bid': 0,
      'highest_bidder_id': null,
      'pass_count': 0,
      'current_round': 1,
      'turn_index': cutterIndex, // Bidding starts with Cutter
    }).eq('id', roomId);
  }

  // Deal 4 more cards per player (called after trump selection)
  Future<void> _dealFourCardsRound(String roomId, List<String> playerIds, int deckOffset) async {
    final roomResponse = await _supabase.from('rooms').select().eq('id', roomId);
    if (roomResponse.isEmpty) return;
    final room = roomResponse.first;
    final List<dynamic> deck = room['shuffled_deck'];
    final int dealerIndex = room['dealer_index'] ?? 0;
    final int cutterIndex = (dealerIndex + 3) % 4; // Matches isCutterProvider

    final List<String> orderedPlayers = List.generate(4, (i) => playerIds[(cutterIndex + i) % 4]);

    for (int i = 0; i < 4; i++) {
      final hand = deck.skip(deckOffset + i * 4).take(4).map((c) => {
        'room_id': roomId,
        'player_id': orderedPlayers[i],
        'card_value': c,
      }).toList();
      await _supabase.from('hands').insert(hand);
      await Future.delayed(const Duration(milliseconds: 400));
    }
  }

  @override
  Future<void> dealRemainingEight(String roomId, List<String> playerIds) async {
    // No-op: replaced by _dealFourCardsRound called in 2 separate phases
  }

  @override
  Future<void> placeBid(String roomId, String playerId, int bid) async {
    // 1. Fetch current state
    final room = await _supabase.from('rooms').select().eq('id', roomId).single();
    final int currentHigh = room['highest_bid'] ?? 0;
    final int passCount = room['pass_count'] ?? 0;
    final String status = room['status'];
    
    final updates = <String, dynamic>{};

    if (bid == 0) {
      // Player permanently passes this round — mark bid = -1
      await _supabase.from('players').update({'bid': -1}).eq('id', playerId);
      updates['pass_count'] = passCount + 1;
    } else {
      // Validate
      if (status == 'bidding' && bid < 5 && currentHigh == 0) throw Exception('Min opening bid is 5');
      if (status == 'bidding_2' && bid < 2 && currentHigh == 0) throw Exception('Min bid is 2');
      if (bid <= currentHigh) throw Exception('Bid must be higher than $currentHigh');

      updates['highest_bid'] = bid;
      updates['highest_bidder_id'] = playerId;
      await _supabase.from('players').update({'bid': bid}).eq('id', playerId);
      // NOTE: pass_count is NOT reset here — players already out stay out
    }

    final int newPassCount = (updates['pass_count'] ?? passCount) as int;

    // Fetch all players (with updated bids) to compute next active turn
    final allPlayers = await _supabase
        .from('players')
        .select('id, bid')
        .eq('room_id', roomId)
        .order('joined_at', ascending: true);

    final currentIndex = allPlayers.indexWhere((p) => p['id'] == playerId);

    // --- Termination check ---
    if (status == 'bidding') {
      if (newPassCount >= 3 && currentHigh > 0) {
        // 3 players have passed, 1 winner remains
        updates['status'] = 'trump_selection';
        updates['current_phase'] = 'trump_selection';
        final String winnerId = updates['highest_bidder_id'] ?? room['highest_bidder_id'];
        updates['turn_index'] = allPlayers.indexWhere((p) => p['id'] == winnerId);
      } else if (newPassCount >= 4) {
        // Everyone passed → deal rest, default trump Spades
        final pIds = allPlayers.map<String>((p) => p['id'] as String).toList();
        await _dealFourCardsRound(roomId, pIds, 20);
        await _dealFourCardsRound(roomId, pIds, 36);
        updates['status'] = 'bidding_2';
        updates['current_phase'] = 'bidding_2';
        updates['pass_count'] = 0;
        updates['highest_bid'] = 0;
        updates['trump_suit'] = 'S'; // Spades default
        updates['turn_index'] = (room['dealer_index'] + 3) % 4; // Cutter starts bidding_2
        // Reset all player bids for the new bidding round
        await _supabase.from('players').update({'bid': null}).eq('room_id', roomId);
      } else {
        // Advance to next player who hasn't passed (bid != -1)
        int next = (currentIndex + 1) % 4;
        for (int i = 0; i < 4; i++) {
          if ((allPlayers[next]['bid'] as int?) != -1) break;
          next = (next + 1) % 4;
        }
        updates['turn_index'] = next;
      }
    } else if (status == 'bidding_2') {
      if (newPassCount >= 3) {
        // Final bid complete → start playing
        updates['status'] = 'playing';
        updates['current_phase'] = 'playing';
        updates['turn_index'] = (room['dealer_index'] + 3) % 4; // Cutter leads first trick
      } else {
        // Advance turn normally (no elimination in bidding_2)
        updates['turn_index'] = (room['turn_index'] + 1) % 4;
      }
    }

    await _supabase.from('rooms').update(updates).eq('id', roomId);
  }

  @override
  Future<void> selectTrump(String roomId, String playerId, String suit) async {
    final room = await _supabase.from('rooms').select().eq('id', roomId).single();
    if (room['highest_bidder_id'] != playerId) throw Exception('Only the winner can select trump');

    await _supabase.from('rooms').update({
      'trump_suit': suit,
    }).eq('id', roomId);

    final players = await _supabase.from('players').select('id').eq('room_id', roomId).order('created_at');
    final pIds = players.map<String>((p) => p['id'] as String).toList();

    if (room['status'] == 'trump_selection') {
       // Deal Round 2: 4 cards each (deck[20..35]) — silent, no bidding
       await _dealFourCardsRound(roomId, pIds, 20);
       
       // Deal Round 3: 4 cards each (deck[36..51]) — still silent
       await _dealFourCardsRound(roomId, pIds, 36);

       // Now all 13 cards dealt (5+4+4). Move to final bidding round.
       await _supabase.from('rooms').update({
         'status': 'bidding_2',
         'current_phase': 'bidding_2',
         'turn_index': (room['dealer_index'] + 3) % 4, // Cutter starts final bid
         'pass_count': 0,
         'highest_bid': 0,
         'highest_bidder_id': null,
       }).eq('id', roomId);
    }
  }

  @override
  Future<void> playCard(String roomId, String playerId, String cardValue) async {
    // 0. Validate move
    final room = await _supabase.from('rooms').select().eq('id', roomId).single();
    final playedCards = await _supabase.from('played_cards').select().eq('room_id', roomId);
    final hand = await _supabase.from('hands').select().eq('player_id', playerId);
    
    final currentTrick = playedCards.length % 4 == 0 ? <Map<String, dynamic>>[] : playedCards.sublist(playedCards.length - (playedCards.length % 4));
    final handValues = hand.map((h) => h['card_value'] as String).toList();
    
    final isValid = await validateMove(roomId, playerId, cardValue, currentTrick, handValues, room['trump_suit']);
    if (!isValid) throw Exception('Invalid move: Must follow suit/win if possible');

    // 1. Play the card
    await _supabase.from('played_cards').insert({
      'room_id': roomId,
      'player_id': playerId,
      'card_value': cardValue,
    });

    // 2. Remove from hand
    await _supabase.from('hands').delete().match({
      'player_id': playerId,
      'card_value': cardValue,
    });

    // 3. Fetch state for evaluation
    final roomResponse = await _supabase.from('rooms').select().eq('id', roomId).single();
    final allPlayedCards = await _supabase.from('played_cards').select().eq('room_id', roomId).order('played_at', ascending: true);
    final players = await _supabase.from('players').select().eq('room_id', roomId);

    final trickSize = allPlayedCards.length % 4;
    
    if (trickSize == 0 && allPlayedCards.isNotEmpty) {
      // Trick finished! Evaluate winner.
      final currentTrick = allPlayedCards.sublist(allPlayedCards.length - 4);
      final trumpSuit = roomResponse['trump_suit'];
      
      String? winnerPlayerId;
      CardModel? bestCard;
      final leadSuit = CardModel.fromId(currentTrick.first['card_value']).suit;

      for (var pCard in currentTrick) {
        final card = CardModel.fromId(pCard['card_value']);
        if (bestCard == null) {
          bestCard = card;
          winnerPlayerId = pCard['player_id'];
          continue;
        }

        bool beats = false;
        if (trumpSuit != null && card.suit.name.toUpperCase().startsWith(trumpSuit)) {
          if (!bestCard.suit.name.toUpperCase().startsWith(trumpSuit)) {
            beats = true;
          } else if (card.rank > bestCard.rank) {
            beats = true;
          }
        } else if (!bestCard.suit.name.toUpperCase().startsWith(trumpSuit ?? 'NONE') && card.suit == leadSuit) {
          if (bestCard.suit != leadSuit || card.rank > bestCard.rank) {
            beats = true;
          }
        }

        if (beats) {
          bestCard = card;
          winnerPlayerId = pCard['player_id'];
        }
      }

      if (winnerPlayerId != null) {
        // Update tricks_won for winner
        final winner = players.firstWhere((p) => p['id'] == winnerPlayerId);
        await _supabase.from('players').update({
          'tricks_won': (winner['tricks_won'] ?? 0) + 1,
        }).eq('id', winnerPlayerId);

        // Winner starts next trick
        final winnerIndex = players.indexWhere((p) => p['id'] == winnerPlayerId);
        await _supabase.from('rooms').update({
          'turn_index': winnerIndex,
        }).eq('id', roomId);
      }

      // 4. Check if Round is finished (13 tricks * 4 = 52 cards)
      if (playedCards.length == 52) {
        await _recordRoundResults(roomId);
      }
    } else {
      // Move to next player
      await _supabase.from('rooms').update({
        'turn_index': (roomResponse['turn_index'] + 1) % 4,
      }).eq('id', roomId);
    }
  }

  Future<void> _recordRoundResults(String roomId) async {
    final room = await _supabase.from('rooms').select().eq('id', roomId).single();
    final players = await _supabase.from('players').select().eq('room_id', roomId);
    final int roundNum = room['current_round'] ?? 1;

    for (var p in players) {
      final int bid = p['bid'] ?? 2;
      final int won = p['tricks_won'] ?? 0;
      final int points = (won >= bid) ? bid : -bid;
      final int newTotal = (p['total_score'] ?? 0) + points;

      // Record in history
      await _supabase.from('round_results').insert({
        'room_id': roomId,
        'player_id': p['id'],
        'round_number': roundNum,
        'bid': bid,
        'tricks_won': won,
        'points_earned': points,
      });

      // Update player total
      await _supabase.from('players').update({
        'total_score': newTotal,
        'bid': null,
        'tricks_won': 0,
      }).eq('id', p['id']);
    }

    // Get players again for final total_score check
    final updatedPlayers = await _supabase.from('players')
        .select()
        .eq('room_id', roomId)
        .order('created_at'); // Consistent ordering

    var lowestScorerIndex = 0;
    var minScore = updatedPlayers[0]['total_score'] ?? 0;
    
    for (int i = 0; i < updatedPlayers.length; i++) {
       final s = updatedPlayers[i]['total_score'] ?? 0;
       if (s < minScore) {
          minScore = s;
          lowestScorerIndex = i;
       }
    }

    // Set to shuffling for next round
    await _supabase.from('rooms').update({
      'status': 'shuffling',
      'current_phase': 'lobby', // Actually back to lobby phase briefly before auto-dealing
      'current_round': roundNum + 1,
      'dealer_index': lowestScorerIndex,
      'trump_suit': null,
      'trump_locked': false,
    }).eq('id', roomId);
    
    // Clear played cards
    await _supabase.from('played_cards').delete().eq('room_id', roomId);
  }

  @override
  Future<bool> validateMove(String roomId, String playerId, String cardValue, List<Map<String, dynamic>> currentTrick, List<String> playerHand, String? trumpSuit) async {
    if (currentTrick.isEmpty) return true;

    final leadCardId = currentTrick.first['card_value'] as String;
    final leadSuit = CardModel.fromId(leadCardId).suit;
    final playedCard = CardModel.fromId(cardValue);

    // If player follows suit, it's always valid
    if (playedCard.suit == leadSuit) return true;

    // If player doesn't follow suit, they must not have any cards of the lead suit
    final hasLeadSuit = playerHand.any((cid) => CardModel.fromId(cid).suit == leadSuit);
    
    return !hasLeadSuit;
  }
}
