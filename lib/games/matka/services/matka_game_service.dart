// Matka game service — all in-game actions
// Independent of lib/games/minus/
//
// Turn flow:
//   deal pillars (RPC) → player bets OR passes
//   Bet:  calls RPC 'matka_draw_card', computes result client-side for UI, updates DB
//   Pass: updates DB, records pass
//   Advance: moves to next player, deals pillars (RPC)
//   Shuffling: handled by RPC when shoe is depleted

import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/matka_models.dart';

SupabaseClient get _db => Supabase.instance.client;

class MatkaGameService {
  // ─────────────────────────────────────────────────────────────────────────
  // START GAME (host only)
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> startGame(MatkaRoom room, List<MatkaPlayer> players) async {
    final host = players.firstWhere((p) => p.isHost);
    
    // Call Secure RPC to initialize shoe and first pillars
    await _db.rpc('matka_init_game', params: {
      'rid': room.id,
      'pid': host.id,
    });
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PLACE BET (active player)
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> placeBet(
    MatkaRoom room,
    MatkaPlayer player,
    List<MatkaPlayer> allPlayers,
    int betAmount,
  ) async {
    if (betAmount <= 0 || betAmount > room.potAmount) return;

    try {
      // 1. Call Secure RPC to draw middle card
      final String middleId = await _db.rpc('matka_draw_card', params: {
        'rid': room.id,
        'pid': player.id,
        'bet': betAmount,
      });

      // 2. Client-side evaluation for history record (SQL also updates status to 'round_result')
      final p1 = MatkaCard.fromId(room.leftPillar!);
      final p2 = MatkaCard.fromId(room.rightPillar!);
      final middle = MatkaCard.fromId(middleId);
      final result = MatkaCard.evaluate(p1, p2, middle);

      int chipsDelta = 0;
      int newPot = room.potAmount;
      int newNet = player.netChips;

      switch (result) {
        case MatkaResult.win:
          chipsDelta = betAmount;
          newPot -= betAmount;
          newNet += betAmount;
          break;
        case MatkaResult.loss:
          chipsDelta = -betAmount;
          newPot += betAmount;
          newNet -= betAmount;
          break;
        case MatkaResult.post:
          chipsDelta = -(betAmount * 2);
          newPot += (betAmount * 2);
          newNet -= (betAmount * 2);
          break;
        case MatkaResult.pass:
          return;
      }

      final resultStr = result.name;

      // 3. Update player balance & last action
      await _db.from('matka_players').update({
        'net_chips': newNet,
        'last_action': resultStr,
        'last_bet_amount': betAmount,
      }).eq('id', player.id);

      // 4. Insert round record
      await _db.from('matka_rounds').insert({
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

      // 5. Update room pot (status already set by RPC)
      await _db.from('matka_rooms').update({
        'pot_amount': newPot,
      }).eq('id', room.id);

      // 6. Auto-advance after brief display
      await Future.delayed(const Duration(seconds: 3));
      await _advanceTurn(room.copyWith(
        potAmount: newPot,
        status: 'round_result',
      ), allPlayers);
    } catch (e) {
      if (e.toString().contains('PGRST116')) {
        // Handle shoe depletion
        await _db.from('matka_rooms').update({'status': 'shuffling'}).eq('id', room.id);
      }
      rethrow;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PASS (active player)
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> passTurn(
    MatkaRoom room,
    MatkaPlayer player,
    List<MatkaPlayer> allPlayers,
  ) async {
    await _db.from('matka_players').update({
      'last_action': 'pass',
      'last_bet_amount': null,
    }).eq('id', player.id);

    await _db.from('matka_rounds').insert({
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
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> _advanceTurn(MatkaRoom room, List<MatkaPlayer> players) async {
    final nextIndex = (room.currentPlayerIndex + 1) % players.length;
    final isNewRound = nextIndex == 0;
    int newPot = room.potAmount;
    int newRound = room.roundNumber;

    if (isNewRound) {
      newRound = room.roundNumber + 1;
      final totalAnte = room.anteAmount * players.length;
      final freshPlayers = await _db.from('matka_players').select().eq('room_id', room.id);
      for (final p in freshPlayers) {
        await _db.from('matka_players').update({
          'net_chips': (p['net_chips'] as int) - room.anteAmount,
        }).eq('id', p['id']);
      }
      newPot += totalAnte;
    }

    // Call Secure RPC to deal pillars for the next player
    try {
      await _db.rpc('matka_deal_pillars', params: {
        'rid': room.id,
        'pid': players[nextIndex].id,
      });

      // Update remaining room state
      await _db.from('matka_rooms').update({
        'current_player_index': nextIndex,
        'pot_amount': newPot,
        'round_number': newRound,
      }).eq('id', room.id);
    } catch (e) {
      // If deal fails (no cards), go to shuffling
      await _db.from('matka_rooms').update({
        'status': 'shuffling',
        'current_player_index': nextIndex,
        'pot_amount': newPot,
        'round_number': newRound,
      }).eq('id', room.id);
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // RESHUFFLE (host only)
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> reshuffleShoe(MatkaRoom room, {int? newDeckCount}) async {
    final count = (newDeckCount ?? room.deckCount).clamp(1, 4);
    final host = await _db.from('matka_players').select().eq('room_id', room.id).eq('is_host', true).single();

    await _db.rpc('matka_reshuffle', params: {
      'rid': room.id,
      'pid': host['id'],
      'new_decks': count,
    });
  }

  // ─────────────────────────────────────────────────────────────────────────
  // END GAME (host only)
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> endGame(String roomId) async {
    await _db.from('matka_rooms').update({'status': 'ended'}).eq('id', roomId);
  }
}
