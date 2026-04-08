// Matka game service — all in-game actions
// Independent of lib/games/minus/
//
// Turn flow:
//   deal pillars → player bets (instant reveal) OR passes (draws next 2 pillars for next player)
//   Bet:  consume 3 cards (2 pillars + 1 middle), compute result
//   Pass: consume 2 cards (pillars only), record pass
//   After each player: advance to next player and deal their 2 pillars
//   When all players done in a round: collect antes, increment round_number, start again
//   When shoe runs out mid-deal: status='shuffling', host can add decks then reshuffle

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/card_model.dart';
import '../models/matka_models.dart';

SupabaseClient get _db => Supabase.instance.client;

class MatkaGameService {
  // ─────────────────────────────────────────────────────────────────────────
  // START GAME (host only)
  // Collect antes from all players, deal pillars for player at index 0.
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> startGame(MatkaRoom room, List<MatkaPlayer> players) async {
    // Collect antes
    final totalAnte = room.anteAmount * players.length;
    for (final p in players) {
      await _db
          .schema('matka')
          .from('players')
          .update({'net_chips': p.netChips - room.anteAmount, 'is_ready': true})
          .eq('id', p.id);
    }

    // Check shoe has enough cards for first deal (2 pillars)
    if (room.shoePtr + 2 > room.shoe.length) {
      await _db.schema('matka').from('rooms').update({'status': 'shuffling'}).eq('id', room.id);
      return;
    }

    final left = room.shoe[room.shoePtr];
    final right = room.shoe[room.shoePtr + 1];

    await _db.schema('matka').from('rooms').update({
      'pot_amount': room.potAmount + totalAnte,
      'current_player_index': 0,
      'shoe_ptr': room.shoePtr + 2,
      'left_pillar': left,
      'right_pillar': right,
      'middle_card': null,
      'current_bet': null,
      'status': 'betting',
    }).eq('id', room.id);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PLACE BET (active player)
  // Immediately draws middle card, computes result, updates state.
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> placeBet(
    MatkaRoom room,
    MatkaPlayer player,
    List<MatkaPlayer> allPlayers,
    int betAmount,
  ) async {
    if (betAmount <= 0 || betAmount > room.potAmount) return;
    if (room.shoePtr + 1 > room.shoe.length) {
      await _db.schema('matka').from('rooms').update({'status': 'shuffling'}).eq('id', room.id);
      return;
    }

    final middleId = room.shoe[room.shoePtr];
    final p1 = MatkaCard.fromId(room.leftPillar!);
    final p2 = MatkaCard.fromId(room.rightPillar!);
    final middle = MatkaCard.fromId(middleId);

    final result = MatkaCard.evaluate(p1, p2, middle);
    int chipsDelta;
    int newPot;
    int newNet;

    switch (result) {
      case MatkaResult.win:
        chipsDelta = betAmount;
        newPot = room.potAmount - betAmount;
        newNet = player.netChips + betAmount;
        break;
      case MatkaResult.loss:
        chipsDelta = -betAmount;
        newPot = room.potAmount + betAmount;
        newNet = player.netChips - betAmount;
        break;
      case MatkaResult.post:
        chipsDelta = -(betAmount * 2);
        newPot = room.potAmount + (betAmount * 2);
        newNet = player.netChips - (betAmount * 2);
        break;
      case MatkaResult.pass:
        return; // shouldn't happen
    }

    final resultStr = result.name; // 'win' | 'loss' | 'post'

    // Update player
    await _db.schema('matka').from('players').update({
      'net_chips': newNet,
      'last_action': resultStr,
      'last_bet_amount': betAmount,
    }).eq('id', player.id);

    // Insert round record
    await _db.schema('matka').from('rounds').insert({
      'room_id': room.id,
      'round_number': room.roundNumber,
      'player_id': player.id,
      'left_pillar': room.leftPillar,
      'right_pillar': room.rightPillar,
      'middle_card': middleId,
      'bet_amount': betAmount,
      'result': resultStr,
      'chips_delta': chipsDelta,
    });

    // Update room with result — then advance
    await _db.schema('matka').from('rooms').update({
      'pot_amount': newPot,
      'shoe_ptr': room.shoePtr + 1,
      'middle_card': middleId,
      'current_bet': betAmount,
      'status': 'round_result',
    }).eq('id', room.id);

    // Auto-advance after brief display
    await Future.delayed(const Duration(seconds: 3));
    await _advanceTurn(room.copyWith(
      potAmount: newPot,
      shoePtr: room.shoePtr + 1,
      status: 'round_result',
    ), allPlayers);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PASS (active player)
  // Records pass, advances to next player with fresh pillars.
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> passTurn(
    MatkaRoom room,
    MatkaPlayer player,
    List<MatkaPlayer> allPlayers,
  ) async {
    // Update player last action
    await _db.schema('matka').from('players').update({
      'last_action': 'pass',
      'last_bet_amount': null,
    }).eq('id', player.id);

    // Insert pass round record
    await _db.schema('matka').from('rounds').insert({
      'room_id': room.id,
      'round_number': room.roundNumber,
      'player_id': player.id,
      'left_pillar': room.leftPillar,
      'right_pillar': room.rightPillar,
      'middle_card': null,
      'bet_amount': null,
      'result': 'pass',
      'chips_delta': 0,
    });

    await _advanceTurn(room, allPlayers);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // ADVANCE TURN (internal)
  // Moves to next player. If all players done: collect antes for new round.
  // Always deals 2 fresh pillars for the incoming player.
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> _advanceTurn(MatkaRoom room, List<MatkaPlayer> players) async {
    final nextIndex = (room.currentPlayerIndex + 1) % players.length;
    final isNewRound = nextIndex == 0;
    int newShoePtr = room.shoePtr;
    int newPot = room.potAmount;
    int newRound = room.roundNumber;

    if (isNewRound) {
      // Collect antes for all players
      newRound = room.roundNumber + 1;
      final totalAnte = room.anteAmount * players.length;
      // Fetch fresh player data to get current net_chips
      final freshPlayers = await _db
          .schema('matka')
          .from('players')
          .select()
          .eq('room_id', room.id);
      for (final p in freshPlayers) {
        await _db.schema('matka').from('players').update({
          'net_chips': (p['net_chips'] as int) - room.anteAmount,
        }).eq('id', p['id']);
      }
      newPot += totalAnte;
    }

    // Check shoe capacity for next 2 pillars
    if (newShoePtr + 2 > room.shoe.length) {
      await _db.schema('matka').from('rooms').update({
        'status': 'shuffling',
        'current_player_index': nextIndex,
        'pot_amount': newPot,
        'round_number': newRound,
        'left_pillar': null,
        'right_pillar': null,
        'middle_card': null,
        'current_bet': null,
      }).eq('id', room.id);
      return;
    }

    final left = room.shoe[newShoePtr];
    final right = room.shoe[newShoePtr + 1];

    await _db.schema('matka').from('rooms').update({
      'current_player_index': nextIndex,
      'shoe_ptr': newShoePtr + 2,
      'left_pillar': left,
      'right_pillar': right,
      'middle_card': null,
      'current_bet': null,
      'pot_amount': newPot,
      'round_number': newRound,
      'status': 'betting',
    }).eq('id', room.id);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // RESHUFFLE (host only)
  // Called when status='shuffling'. Host can optionally add decks (1–4 total).
  // Rebuilds and reshuffles the shoe, then deals pillars for current player.
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> reshuffleShoe(MatkaRoom room, {int? newDeckCount}) async {
    final count = (newDeckCount ?? room.deckCount).clamp(1, 4);
    final newShoe = MatkaCard.shuffled(MatkaCard.buildShoe(count));

    if (newShoe.length < 2) return;
    final left = newShoe[0];
    final right = newShoe[1];

    await _db.schema('matka').from('rooms').update({
      'deck_count': count,
      'shoe': newShoe,
      'shoe_ptr': 2,
      'left_pillar': left,
      'right_pillar': right,
      'middle_card': null,
      'current_bet': null,
      'status': 'betting',
    }).eq('id', room.id);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // END GAME (host only)
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> endGame(String roomId) async {
    await _db
        .schema('matka')
        .from('rooms')
        .update({'status': 'ended'})
        .eq('id', roomId);
  }
}
