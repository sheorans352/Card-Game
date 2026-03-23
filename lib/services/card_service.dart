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

  Future<void> shuffleDeck(String roomId) async {
    final deck = generateDeck();
    final deckIds = deck.map((c) => c.id).toList();

    await _supabase.from('rooms').update({
      'shuffled_deck': deckIds,
      'current_phase': 'deck_cut',
    }).eq('id', roomId);
  }

  Future<void> cutDeck(String roomId, int cutPoint) async {
    final roomData = await _supabase.from('rooms').select('shuffled_deck, dealer_index').eq('id', roomId).single();
    final List<dynamic> originalDeck = roomData['shuffled_deck'];
    
    // Logic: If selected X, cards 1 to X move to bottom.
    // Index X in 1-based becomes cutPoint. 
    // New deck = originalDeck.sublist(cutPoint) + originalDeck.sublist(0, cutPoint);
    final cutDeck = [...originalDeck.sublist(cutPoint), ...originalDeck.sublist(0, cutPoint)];

    await _supabase.from('rooms').update({
      'shuffled_deck': cutDeck,
      'deck_cut_value': cutPoint,
      'current_phase': 'dealing_1', // Move to dealing after cut
    }).eq('id', roomId);
  }

  Future<void> dealInitialFive(String roomId, List<String> playerIds) async {
    final roomData = await _supabase.from('rooms').select('shuffled_deck, dealer_index').eq('id', roomId).single();
    final List<dynamic> deckIds = roomData['shuffled_deck'];
    final List<String> deck = List<String>.from(deckIds);
    
    final dealerIndex = roomData['dealer_index'] ?? 0;
    final turnIndex = (dealerIndex + 1) % playerIds.length;

    await _supabase.from('rooms').update({
      'turn_index': turnIndex,
    }).eq('id', roomId);

    // Deal 5 cards to each player from the top of the cut deck
    int cardIndex = 0;
    for (int i = 0; i < 5; i++) {
      for (final playerId in playerIds) {
        final cardId = deck[cardIndex++];
        await _supabase.from('player_cards').insert({
          'room_id': roomId,
          'player_id': playerId,
          'card_value': cardId,
          'is_revealed': false,
        });
        await Future.delayed(const Duration(milliseconds: 200));
      }
    }

    await _supabase.from('rooms').update({'current_phase': 'bidding'}).eq('id', roomId);
  }

  Future<void> dealRemainingEight(String roomId, List<String> playerIds) async {
    final fullDeck = generateDeck();
    
    // Get already dealt cards
  Future<void> dealRemainingEight(String roomId, List<String> playerIds) async {
    final roomData = await _supabase.from('rooms').select('shuffled_deck').eq('id', roomId).single();
    final List<dynamic> deckIds = roomData['shuffled_deck'];
    final List<String> fullDeck = List<String>.from(deckIds);
    
    // Cards 1-20 are already dealt (5 * 4 players)
    final remainingDeck = fullDeck.sublist(20);

    int cardIndex = 0;
    // Phase 2: Deal 4 cards
    for (int i = 0; i < 4; i++) {
      for (final playerId in playerIds) {
        if (cardIndex >= remainingDeck.length) break;
        final cardId = remainingDeck[cardIndex++];
        await _supabase.from('player_cards').insert({
          'room_id': roomId,
          'player_id': playerId,
          'card_value': cardId,
          'is_revealed': false,
        });
        await Future.delayed(const Duration(milliseconds: 200));
      }
    }

    // Phase 3: Deal 4 cards
    for (int i = 0; i < 4; i++) {
      for (final playerId in playerIds) {
        if (cardIndex >= remainingDeck.length) break;
        final cardId = remainingDeck[cardIndex++];
        await _supabase.from('player_cards').insert({
          'room_id': roomId,
          'player_id': playerId,
          'card_value': cardId,
          'is_revealed': false,
        });
        await Future.delayed(const Duration(milliseconds: 200));
      }
    }
  }

  Future<void> playCard(String roomId, String playerId, String cardValue) async {
    // 1. Mark card as played
    await _supabase.from('player_cards').update({
      'is_played': true,
      'played_at': DateTime.now().toIso8601String(),
    }).match({'player_id': playerId, 'card_value': cardValue});

    // 2. Check if the trick is complete (4 cards)
    final playedCardsData = await _supabase
        .from('player_cards')
        .select('id, played_at')
        .eq('room_id', roomId)
        .eq('is_played', true);
    
    final allPlayed = (playedCardsData as List);
    
    if (allPlayed.length % 4 == 0 && allPlayed.isNotEmpty) {
      final lastFourData = await _supabase
        .from('player_cards')
        .select('*')
        .eq('room_id', roomId)
        .eq('is_played', true)
        .order('played_at', ascending: true);
      
      final currentTrick = (lastFourData as List).sublist(lastFourData.length - 4);
      await _evaluateTrick(roomId, currentTrick, allPlayed.length);
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

    if (currentTrickSize == 0) return true; // Leading is always valid

    // 2. Get Room Info (Trump)
    final roomData = await _supabase.from('rooms').select('trump_suit').eq('id', roomId).single();
    final trumpSuitCode = roomData['trump_suit'];

    // 3. Identify current trick context
    final trickCards = playedList.sublist(playedList.length - currentTrickSize);
    final leadCard = CardModel.fromId(trickCards[0]['card_value']);
    final leadSuit = leadCard.suit;

    // 4. Get Player's available cards
    final handData = await _supabase.from('player_cards').select('card_value').eq('player_id', playerId).eq('is_played', false);
    final hand = (handData as List).map((c) => CardModel.fromId(c['card_value'])).toList();

    final hasLeadSuit = hand.any((c) => c.suit == leadSuit);

    // Rule 1: MUST follow suit if possible
    if (hasLeadSuit) {
      if (card.suit != leadSuit) return false;

      // NEW: RULE 'Must Play Higher' for lead suit
      final bestOnTable = _getBestCardInTrick(trickCards, trumpSuitCode);
      
      // If best card on table is also lead suit, and we have a higher one, we MUST play it.
      if (bestOnTable.suit == leadSuit) {
        final handHigherLead = hand.where((c) => c.suit == leadSuit && c.rank > bestOnTable.rank).toList();
        if (handHigherLead.isNotEmpty) {
           return card.rank > bestOnTable.rank;
        }
      }
      return true; // If we can't beat it, any card of lead suit is fine
    }

    // Rule 2: If OUT of lead suit, the player CAN play any card.
    // However, the 'Must Play Higher' rule still applies IF they choose to play a Spade.
    if (!hasLeadSuit && card.suit.code == 'S') {
      int maxSpadeOnTable = 0;
      for (var tc in trickCards) {
        final c = CardModel.fromId(tc['card_value']);
        if (c.suit.code == 'S' && c.rank > maxSpadeOnTable) maxSpadeOnTable = c.rank;
      }

      final handHigherSpade = hand.where((c) => c.suit.code == 'S' && c.rank > maxSpadeOnTable).toList();
      if (handHigherSpade.isNotEmpty) {
        return card.rank > maxSpadeOnTable;
      }
    }

    return true; // Any card is valid if out of lead suit (unless Ducking with a Spade)
  }

  CardModel _getBestCardInTrick(List<dynamic> trickCards, String? trumpSuitCode) {
    final leadCard = CardModel.fromId(trickCards[0]['card_value']);
    CardModel bestCard = leadCard;

    for (var i = 1; i < trickCards.length; i++) {
      final currentCard = CardModel.fromId(trickCards[i]['card_value']);
      bool isBetter = false;

      if (currentCard.suit.code == trumpSuitCode && bestCard.suit.code != trumpSuitCode) {
        isBetter = true;
      } else if (currentCard.suit == bestCard.suit && currentCard.rank > bestCard.rank) {
        isBetter = true;
      }

      if (isBetter) bestCard = currentCard;
    }
    return bestCard;
  }

  Future<void> _evaluateTrick(String roomId, List<dynamic> trickCards, int totalTricks) async {
    final roomData = await _supabase.from('rooms').select('trump_suit').eq('id', roomId).single();
    final trumpSuitCode = roomData['trump_suit'];

    final bestCard = _getBestCardInTrick(trickCards, trumpSuitCode);
    
    // Find who played the best card
    String winnerPlayerId = '';
    for (var tc in trickCards) {
       if (tc['card_value'] == bestCard.id) {
         winnerPlayerId = tc['player_id'];
         break;
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
