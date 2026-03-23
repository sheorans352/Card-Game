import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/card_model.dart';

class CardService {
  final _supabase = Supabase.instance.client;

  List<CardModel> generateDeck() {
    final List<CardModel> deck = [];
    for (final suit in Suit.values) {
      for (int r = 2; r <= 14; r++) {
        String val;
        if (r == 14) {
          val = 'A';
        } else if (r == 13) {
          val = 'K';
        } else if (r == 12) {
          val = 'Q';
        } else if (r == 11) {
          val = 'J';
        } else {
          val = r.toString();
        }
        
        deck.add(CardModel(suit: suit, value: val, rank: r));
      }
    }
    return deck..shuffle();
  }

  Future<void> dealInitialFive(String roomId, List<String> playerIds) async {
    final deck = generateDeck();
    
    // Choose a random dealer if not already set (simplified for now)
    final dealerIndex = 0; // Host or first player for now
    final turnIndex = (dealerIndex + 1) % playerIds.length;

    // Update room phase and indices
    await _supabase.from('rooms').update({
      'current_phase': 'dealing_1',
      'dealer_index': dealerIndex,
      'turn_index': turnIndex,
    }).eq('id', roomId);

    // Deal 5 cards to each player
    for (int i = 0; i < 5; i++) {
      for (final playerId in playerIds) {
        final card = deck.removeLast();
        await _supabase.from('player_cards').insert({
          'room_id': roomId,
          'player_id': playerId,
          'card_value': card.id,
          'is_revealed': false,
        });
        // Slight delay for animation "feeling"
        await Future.delayed(const Duration(milliseconds: 200));
      }
    }

    // Move to bidding phase
    await _supabase.from('rooms').update({'current_phase': 'bidding'}).eq('id', roomId);
  }

  Future<void> dealRemainingEight(String roomId, List<String> playerIds) async {
    final fullDeck = generateDeck();
    
    // Get already dealt cards
    final dealtData = await _supabase.from('player_cards').select('card_value').eq('room_id', roomId);
    final dealtValues = (dealtData as List).map((d) => d['card_value'] as String).toSet();

    final remainingDeck = fullDeck.where((c) => !dealtValues.contains(c.id)).toList();

    // Phase 2: Deal 4 cards
    for (int i = 0; i < 4; i++) {
      for (final playerId in playerIds) {
        if (remainingDeck.isEmpty) break;
        final card = remainingDeck.removeLast();
        await _supabase.from('player_cards').insert({
          'room_id': roomId,
          'player_id': playerId,
          'card_value': card.id,
          'is_revealed': false,
        });
        await Future.delayed(const Duration(milliseconds: 200));
      }
    }

    // Phase 3: Deal 4 cards
    for (int i = 0; i < 4; i++) {
      for (final playerId in playerIds) {
        if (remainingDeck.isEmpty) break;
        final card = remainingDeck.removeLast();
        await _supabase.from('player_cards').insert({
          'room_id': roomId,
          'player_id': playerId,
          'card_value': card.id,
          'is_revealed': false,
        });
        await Future.delayed(const Duration(milliseconds: 200));
      }
    }

  Future<void> playCard(String roomId, String playerId, String cardValue) async {
    // 1. Mark card as played
    await _supabase.from('player_cards').update({
      'is_played': true,
      'played_at': DateTime.now().toIso8601String(),
    }).match({'player_id': playerId, 'card_value': cardValue});

    // 2. Check if the trick is complete (4 cards)
    final playedCards = await _supabase
        .from('player_cards')
        .select('*, players(name)')
        .eq('room_id', roomId)
        .eq('is_played', true)
        .order('played_at', ascending: true);

    // Filter for the current trick (last N cards where N % 4 != 0 is previous tricks)
    // Simplified: Just get cards played after the last 'tricks_won' update? 
    // Better: Get cards where is_played is true and they aren't part of a finished trick.
    // Let's use a simpler approach: if playedCards.length is a multiple of 4, a trick just finished.
    if (playedCards.length % 4 == 0 && playedCards.isNotEmpty) {
      final currentTrick = (playedCards as List).sublist(playedCards.length - 4);
      await _evaluateTrick(roomId, currentTrick);
    } else {
      // Just move turn to next player
      final roomData = await _supabase.from('rooms').select('turn_index').eq('id', roomId).single();
      final playersData = await _supabase.from('players').select('id').eq('room_id', roomId).order('joined_at', ascending: true);
      
      final nextTurn = (roomData['turn_index'] + 1) % (playersData as List).length;
      await _supabase.from('rooms').update({'turn_index': nextTurn}).eq('id', roomId);
    }
  }

  Future<bool> validateMove(String roomId, String playerId, String cardValue) async {
    final card = CardModel.fromId(cardValue);
    
    // 1. Get current trick cards
    final playedCards = await _supabase
        .from('player_cards')
        .select('*')
        .eq('room_id', roomId)
        .eq('is_played', true)
        .order('played_at', ascending: true);
    
    final playedList = playedCards as List;
    final currentTrickSize = playedList.length % 4;

    if (currentTrickSize == 0) return true; // Leading a trick is always valid

    // 2. Identify lead suit
    final leadCard = CardModel.fromId(playedList[playedList.length - currentTrickSize]['card_value']);
    final leadSuit = leadCard.suit;

    if (card.suit == leadSuit) return true; // Following suit is always valid

    // 3. If NOT following suit, check if player HAS the lead suit
    final playerHand = await _supabase.from('player_cards').select('card_value').eq('player_id', playerId).eq('is_played', false);
    for (var c in playerHand as List) {
      if (CardModel.fromId(c['card_value']).suit == leadSuit) {
        return false; // Must follow suit if possible
      }
    }

    return true; // Sluffing is valid if no lead suit in hand
  }

  Future<void> _evaluateTrick(String roomId, List<dynamic> trickCards) async {
    final roomData = await _supabase.from('rooms').select('trump_suit').eq('id', roomId).single();
    final trumpSuitCode = roomData['trump_suit'];

    // Lead card is the first one in the trickCards list (ordered by played_at)
    final leadCard = CardModel.fromId(trickCards[0]['card_value']);
    final leadSuit = leadCard.suit;

    String winnerPlayerId = trickCards[0]['player_id'];
    CardModel bestCard = leadCard;

    for (var i = 1; i < trickCards.length; i++) {
      final currentCard = CardModel.fromId(trickCards[i]['card_value']);
      final currentPlayerId = trickCards[i]['player_id'];

      bool isBetter = false;

      // Rule: Trump beats everything
      if (currentCard.suit.code == trumpSuitCode && bestCard.suit.code != trumpSuitCode) {
        isBetter = true;
      } 
      // Rule: Higher rank of same suit (trump or lead)
      else if (currentCard.suit == bestCard.suit && currentCard.rank > bestCard.rank) {
        isBetter = true;
      }

      if (isBetter) {
        bestCard = currentCard;
        winnerPlayerId = currentPlayerId;
      }
    }

    // Update winner's tricks_won
    final winnerData = await _supabase.from('players').select('tricks_won').eq('id', winnerPlayerId).single();
    await _supabase.from('players').update({
      'tricks_won': (winnerData['tricks_won'] ?? 0) + 1
    }).eq('id', winnerPlayerId);

    // Winner starts the next trick
    final playersData = await _supabase.from('players').select('id').eq('room_id', roomId).order('joined_at', ascending: true);
    final playersList = (playersData as List);
    final winnerIndex = playersList.indexWhere((p) => p['id'] == winnerPlayerId);

    if (totalTricks == 52) { // 13 * 4
       await _calculateRoundScores(roomId);
    } else {
       await _supabase.from('rooms').update({
         'turn_index': winnerIndex,
       }).eq('id', roomId);
    }
  }

  Future<void> _calculateRoundScores(String roomId) async {
    final playersData = await _supabase.from('players').select('*').eq('room_id', roomId);
    final players = playersData as List;

    for (var p in players) {
      final bid = p['bid'] as int? ?? 0;
      final tricks = p['tricks_won'] as int? ?? 0;
      final currentTotal = p['total_score'] as int? ?? 0;

      // MINUS Scoring: (Tricks >= Bid) ? Bid : -Bid
      final roundScore = (tricks >= bid) ? bid : -bid;
      final newTotal = currentTotal + roundScore;

      await _supabase.from('players').update({
        'total_score': newTotal,
        'bid': null, // Reset for next round
        'tricks_won': 0, // Reset for next round
      }).eq('id', p['id']);

      if (newTotal >= 31) {
        // WE HAVE A WINNER
        await _supabase.from('rooms').update({
          'status': 'finished',
          'current_phase': 'game_over'
        }).eq('id', roomId);
        return;
      }
    }

    // Reset for next round
    await _supabase.from('player_cards').delete().eq('room_id', roomId);
    await _supabase.from('rooms').update({
      'current_phase': 'lobby', // Or 'dealing_1' if we want auto-restart? Let's go to lobby of scoreboard
      'trump_suit': null,
      'trump_locked': false,
    }).eq('id', roomId);
  }
}
