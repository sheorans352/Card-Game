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
    // Cutter is to the LEFT of dealer (clockwise next): (dealerIndex + 1) % 4
    final int cutterIndex = (dealerIndex + 1) % 4;
    
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
    final int cutterIndex = (dealerIndex + 1) % 4; // Matches isCutterProvider

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
    // 1. Fetch current state and enforce turn
    final room = await _supabase.from('rooms').select().eq('id', roomId).single();
    final players = await _supabase.from('players').select().eq('room_id', roomId).order('joined_at', ascending: true);
    final currentPlayerIndex = room['turn_index'] % players.length;
    if (players[currentPlayerIndex]['id'] != playerId) {
      throw Exception('Not your turn to bid!');
    }

    final int currentHigh = room['highest_bid'] ?? 0;
    final int passCount = room['pass_count'] ?? 0;
    final String status = room['status'];

    
    final updates = <String, dynamic>{};

    if (bid == 0) {
      // Player permanently passes trump-suit bidding — use boolean flag, leave bid clean
      await _supabase.from('players')
          .update({'trump_bid_passed': true})
          .eq('id', playerId);
      updates['pass_count'] = passCount + 1;
    } else {
      // Validate
      if (status == 'bidding') {
        if (bid < 5 && currentHigh == 0) throw Exception('Min opening bid is 5');
        if (bid <= currentHigh) throw Exception('Bid must be higher than $currentHigh');
        updates['highest_bid'] = bid;
        updates['highest_bidder_id'] = playerId;
      } else if (status == 'bidding_2') {
        if (bid < 2) throw Exception('Min bid is 2');
        // No currentHigh limitation; can be same or less than other players' bids
      }
      
      await _supabase.from('players').update({'bid': bid}).eq('id', playerId);
      // NOTE: pass_count is NOT reset for bidding_1 — players who passed stay out
    }

    final int newPassCount = (updates['pass_count'] ?? passCount) as int;

    // Fetch all players (with trump_bid_passed flag) to compute next active turn
    final allPlayers = await _supabase
        .from('players')
        .select('id, bid, trump_bid_passed')
        .eq('room_id', roomId)
        .order('joined_at', ascending: true);

    final currentIndex = allPlayers.indexWhere((p) => p['id'] == playerId);

    // --- Termination check (bidding_1: trump suit bidding) ---
    if (status == 'bidding') {
      if (newPassCount >= 3 && currentHigh > 0) {
        // 3 players have passed → winner selects trump
        updates['status'] = 'trump_selection';
        updates['current_phase'] = 'trump_selection';
        final String winnerId = updates['highest_bidder_id'] ?? room['highest_bidder_id'];
        updates['turn_index'] = allPlayers.indexWhere((p) => p['id'] == winnerId);
      } else if (newPassCount >= 4) {
        // Everyone passed → deal rest, default trump = Spades
        
        // Optimistic lock to prevent duplicate deals on rapid clicking
        // Do this FIRST before long dealing animations
        final updated = await _supabase.from('rooms').update({'status': 'dealing_2'})
            .match({'id': roomId, 'status': 'bidding'}).select();
        if (updated.isEmpty) return;

        final pIds = allPlayers.map<String>((p) => p['id'] as String).toList();
        await _dealFourCardsRound(roomId, pIds, 20);
        await _dealFourCardsRound(roomId, pIds, 36);
        updates['status'] = 'bidding_2';
        updates['current_phase'] = 'bidding_2';
        updates['pass_count'] = 0;
        updates['highest_bid'] = 0;
        updates['trump_suit'] = 'S'; // Spades default
        updates['turn_index'] = (room['dealer_index'] + 1) % 4;
        
        // Reset trump_bid_passed and bid for final bidding round
        await _supabase.from('players')
            .update({'bid': null, 'trump_bid_passed': false})
            .eq('room_id', roomId);
      } else {
        // Advance to next player who hasn't passed (trump_bid_passed = false)
        int next = (currentIndex + 1) % 4;
        for (int i = 0; i < 4; i++) {
          if (allPlayers[next]['trump_bid_passed'] != true) break;
          next = (next + 1) % 4;
        }
        updates['turn_index'] = next;
      }
    } else if (status == 'bidding_2') {
      // === PHASE 2: Final trick-count declarations (no passing) ===
      final phase1WinnerId = room['highest_bidder_id'] as String?;
      final isScenarioA = phase1WinnerId != null;

      if (bid < 1) throw Exception('Must declare at least 1 trick');

      // Record declaration (bid field = committed trick count)
      await _supabase.from('players').update({'bid': bid}).eq('id', playerId);

      final declarationCount = passCount + 1;
      updates['pass_count'] = declarationCount;

      // Scenario A needs 3 declarations (trump settler already committed)
      // Scenario B needs all 4
      final needed = isScenarioA ? 3 : 4;

      if (declarationCount >= needed) {
        if (!isScenarioA) {
          // Scenario B: check if any player bid 9+ to override trump
          final latestPlayers = await _supabase
              .from('players').select('id, bid')
              .eq('room_id', roomId)
              .order('joined_at', ascending: true);

          int maxBid = 0;
          String? overriderId;
          for (var p in latestPlayers) {
            final pBid = p['bid'] as int? ?? 0;
            if (pBid >= 9 && pBid > maxBid) { maxBid = pBid; overriderId = p['id'] as String; }
          }

          if (overriderId != null) {
            // Highest 9+ bid wins → trump selection (52 cards already dealt)
            updates['status'] = 'trump_selection';
            updates['current_phase'] = 'trump_selection';
            updates['highest_bidder_id'] = overriderId;
            updates['turn_index'] = latestPlayers.indexWhere((p) => p['id'] == overriderId);
          } else {
            // No 9+ bid → Spades confirmed, cutter leads
            updates['status'] = 'playing';
            updates['current_phase'] = 'playing';
            updates['trump_suit'] = 'S';
            updates['turn_index'] = (room['dealer_index'] + 1) % 4;
            updates['highest_bidder_id'] = null;
          }
        } else {
          // Scenario A: Phase 1 winner leads first
          updates['status'] = 'playing';
          updates['current_phase'] = 'playing';
          updates['turn_index'] = allPlayers.indexWhere((p) => p['id'] == phase1WinnerId);
          updates['highest_bidder_id'] = null; // Clear for playing phase
        }
      } else {
        // Advance turn — skip the trump setter in Scenario A
        int next = (currentIndex + 1) % 4;
        if (isScenarioA && allPlayers[next]['id'] == phase1WinnerId) {
          next = (next + 1) % 4;
        }
        updates['turn_index'] = next;
      }
    }

    await _supabase.from('rooms').update(updates).eq('id', roomId);
  }

  @override
  Future<void> selectTrump(String roomId, String playerId, String suit) async {
    // 1. Fetch current state and enforce winner
    final room = await _supabase.from('rooms').select().eq('id', roomId).single();
    final players = await _supabase.from('players').select().eq('room_id', roomId).order('joined_at', ascending: true);
    final winnerIndex = room['turn_index']; // Winner's index is stored in turn_index during trump_selection phase
    
    if (players[winnerIndex]['id'] != playerId) {
      throw Exception('Only the winner can select trump!');
    }



    // Set trump suit first
    await _supabase.from('rooms').update({'trump_suit': suit}).eq('id', roomId);

    final pIds = players.map<String>((p) => p['id'] as String).toList();


    // Check how many cards are already dealt to distinguish Phase 1 vs Scenario B override
    final handsResponse = await _supabase.from('hands').select('id').eq('room_id', roomId);
    final handsDealt = (handsResponse as List).length;

    if (handsDealt < 52) {
      // Optimistic lock to prevent duplicate deals on rapid clicking
      final updated = await _supabase.from('rooms').update({'status': 'dealing_2'})
          .match({'id': roomId, 'status': 'trump_selection'}).select();
      if (updated.isEmpty) return;

      // === Phase 1 trump selection: deal 4+4 remaining cards ===
      await _dealFourCardsRound(roomId, pIds, 20); // Round 2
      await _dealFourCardsRound(roomId, pIds, 36); // Round 3

      // Reset trump_bid_passed for all players (bidding_2 is a fresh declaration round)
      await _supabase.from('players')
          .update({'trump_bid_passed': false})
          .eq('room_id', roomId);

      // Move to final bid — KEEP highest_bidder_id (identifies Scenario A Phase 1 winner)
      await _supabase.from('rooms').update({
        'status': 'bidding_2',
        'current_phase': 'bidding_2',
        'turn_index': (room['dealer_index'] + 1) % 4, // Cutter starts declaring
        'pass_count': 0,   // Used as declaration counter in bidding_2
        'highest_bid': 0,  // Reset (highest_bidder_id is kept for Scenario A)
        // highest_bidder_id intentionally NOT cleared — Scenario A identity
      }).eq('id', roomId);
    } else {
      // === Scenario B: 52 cards already dealt, this is a 9+ trump override ===
      // Trump setter leads first (Phase 5, Scenario 1)
      final trumpSetterIndex = pIds.indexOf(playerId);
      await _supabase.from('rooms').update({
        'status': 'playing',
        'current_phase': 'playing',
        'turn_index': trumpSetterIndex,
        'highest_bidder_id': null, // Clear for playing phase
      }).eq('id', roomId);
    }
  }

  @override
  Future<void> playCard(String roomId, String playerId, String cardValue) async {
    // 1. Call atomic RPC for turn check, card play, and winner/round evaluation
    final response = await _supabase.rpc('play_card', params: {
      'p_room_id': roomId,
      'p_player_id': playerId,
      'p_card_value': cardValue,
    });

    final result = Map<String, dynamic>.from(response);
    if (result['success'] != true) {
      throw Exception(result['error'] ?? 'Failed to play card');
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

      // Update player total, reset bid state for next round
      await _supabase.from('players').update({
        'total_score': newTotal,
        'bid': null,
        'tricks_won': 0,
        'trump_bid_passed': false,
      }).eq('id', p['id']);
    }

    // Get players again for final total_score check
    final updatedPlayers = await _supabase.from('players')
        .select()
        .eq('room_id', roomId)
        .order('joined_at'); // Consistent ordering

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
      'current_phase': 'lobby',
      'current_round': roundNum + 1,
      'dealer_index': lowestScorerIndex,
      'trump_suit': null,
      'trump_locked': false,
      'deck_cut_value': null, // Reset so next round can be freshly shuffled
      'pass_count': 0,
      'highest_bid': 0,
      'highest_bidder_id': null,
    }).eq('id', roomId);
    
    // Clear played cards
    await _supabase.from('played_cards').delete().eq('room_id', roomId);
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

    if (hasSameSuit) {
      // Rule 1: Must follow lead suit
      if (playedCard.suit != leadSuit) return false;

      // Must-beat rule: find current best card of lead suit on table
      CardModel? currentBest;
      for (var t in currentTrick) {
        final tc = CardModel.fromId(t['card_value'] as String);
        if (tc.suit == leadSuit) {
          if (currentBest == null || tc.rank > currentBest.rank) currentBest = tc;
        }
      }
      // If player can beat the best, they MUST
      if (currentBest != null) {
        final canBeat = handCards.any((c) => c.suit == leadSuit && c.rank > currentBest!.rank);
        if (canBeat && playedCard.rank <= currentBest.rank) return false;
      }
      return true;
    }

    // No lead-suit cards in hand
    
    // If the player chooses to play a trump card
    if (trumpSuitEnum != null && playedCard.suit == trumpSuitEnum) {
      // Find current best trump on table
      CardModel? bestTrump;
      for (var t in currentTrick) {
        final tc = CardModel.fromId(t['card_value'] as String);
        if (tc.suit == trumpSuitEnum) {
          if (bestTrump == null || tc.rank > bestTrump.rank) bestTrump = tc;
        }
      }
      // If trump already played, must play higher trump if possible
      if (bestTrump != null) {
        final canBeatTrump = handCards.any((c) => c.suit == trumpSuitEnum && c.rank > bestTrump!.rank);
        if (canBeatTrump && playedCard.rank <= bestTrump.rank) return false;
      }
      return true;
    }

    // Rule 3: No lead suit cards in hand, and player chose to play a non-trump card (Throwaway) — always valid
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
