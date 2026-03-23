import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/room_provider.dart';
import '../models/game_models.dart';
import '../models/card_model.dart';
import '../widgets/bidding_overlay.dart';
import '../widgets/deck_cut_overlay.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'home_screen.dart';

class GameTableScreen extends ConsumerWidget {
  const GameTableScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final code = ref.watch(currentRoomCodeProvider);
    if (code == null) return const Scaffold(body: Center(child: Text('Error: No Room Code')));

    final roomAsync = ref.watch(roomMetadataProvider(code));

    // Handle Phase 2 Dealing (Host only)
    ref.listen<AsyncValue<Room?>>(roomMetadataProvider(code), (previous, next) {
      final room = next.value;
      if (room != null && room.currentPhase == 'dealing_2') {
        final players = ref.read(playersStreamProvider(room.id)).value ?? [];
        final localId = ref.read(localPlayerIdProvider);
        final isHost = players.any((p) => p.id == localId && p.isHost);
        
        if (isHost) {
          ref.read(cardServiceProvider).dealRemainingEight(
            room.id, 
            players.map((p) => p.id).toList()
          );
        }
      }

      // Handle transition from Deck Cut to Dealing 1
      if (room != null && room.currentPhase == 'dealing_1') {
        final players = ref.read(playersStreamProvider(room.id)).value ?? [];
        final localId = ref.read(localPlayerIdProvider);
        final isHost = players.any((p) => p.id == localId && p.isHost);
        
        if (isHost) {
          ref.read(cardServiceProvider).dealInitialFive(
            room.id, 
            players.map((p) => p.id).toList()
          );
        }
      }
    });

    return Scaffold(
      body: Stack(
        children: [
          const SpadeBackground(), // Reusing the background
          roomAsync.when(
            data: (room) {
              if (room == null) return const Center(child: Text('Room not found'));
              final playersAsync = ref.watch(playersStreamProvider(room.id));

              return playersAsync.when(
                data: (players) {
                   // Layout the table
                   return _buildTable(context, ref, room, players);
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, s) => Center(child: Text('Error: $e')),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, s) => Center(child: Text('Error: $e')),
          ),
        ],
      ),
    );
  }

  Widget _buildTable(BuildContext context, WidgetRef ref, Room room, List<Player> players) {
    final size = MediaQuery.of(context).size;
    final tableSize = size.shortestSide * 0.7;

    return Stack(
      alignment: Alignment.center,
      children: [
        // The Felt Table
        Container(
          width: tableSize,
          height: tableSize,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                const Color(0xFF076324), // Center green
                const Color(0xFF043F17), // Outer dark green
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.5),
                blurRadius: 30,
                spreadRadius: 5,
              ),
            ],
            border: Border.all(color: Colors.white10, width: 2),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
               // Table info
               Positioned(
                 top: tableSize * 0.15,
                 child: Column(
                   children: [
                     Text(
                        room.trumpSuit != null ? 'TRUMP: ${_getSuitEmoji(room.trumpSuit)}' : 'SELECTING TRUMP...',
                        style: const TextStyle(color: Colors.white30, fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'ROOM: ${room.code}',
                        style: const TextStyle(color: Colors.white12, fontSize: 10),
                      ),
                   ],
                 ),
               ),
               // CURRENT TRICK CARDS
               _buildTableCenter(ref, room.id, players),
            ],
          ),
        ),

        // Player Labels and Hands
        ...players.asMap().entries.map((entry) {
          final index = entry.key;
          final player = entry.value;
          
          // Position players around the circle
          double? top, left, right, bottom;
          if (index == 0) { // Bottom (User)
            bottom = 40; left = 0; right = 0;
          } else if (index == 1) { // Left
            left = 40; top = 0; bottom = 0;
          } else if (index == 2) { // Top
            top = 40; left = 0; right = 0;
          } else { // Right
            right = 40; top = 0; bottom = 0;
          }

          final isTurn = room.turnIndex == index;

          return Positioned(
            top: top, left: left, right: right, bottom: bottom,
            child: _buildPlayerArea(ref, room, player, index == 0, isTurn),
          );
        }).toList(),

        // Deck Cut Overlay
        if (room.currentPhase == 'deck_cut' && ref.watch(isCutterProvider(room.code)))
          Align(
            alignment: Alignment.center,
            child: DeckCutOverlay(
              onCutConfirmed: (cutPoint) async {
                await ref.read(cardServiceProvider).cutDeck(room.id, cutPoint);
              },
            ),
          ),
        
        // Bidding Overlay
        if ((room.currentPhase == 'bidding' || room.currentPhase == 'bidding_2') && ref.watch(isLocalPlayerTurnProvider(room.code)))
          Align(
            alignment: Alignment.bottomCenter,
            child: BiddingOverlay(
              onPass: () async {
                final supabase = Supabase.instance.client;
                final nextTurn = (room.turnIndex + 1);
                
                if (nextTurn >= players.length) {
                  if (room.currentPhase == 'bidding') {
                    // End of 5-card bidding phase
                    await supabase.from('rooms').update({
                      'current_phase': 'dealing_2',
                      'turn_index': (room.dealerIndex + 1) % players.length,
                    }).eq('id', room.id);
                  } else {
                    // End of Phase 2 bidding
                    await supabase.from('rooms').update({
                      'current_phase': 'playing',
                      'turn_index': (room.dealerIndex + 1) % players.length,
                    }).eq('id', room.id);
                  }
                } else {
                  await supabase.from('rooms').update({
                    'turn_index': nextTurn,
                  }).eq('id', room.id);
                }
              },
              onBidSubmitted: (bid, trump) async {
                final supabase = Supabase.instance.client;
                final localId = ref.read(localPlayerIdProvider);

                // Override Logic for Phase 2
                if (room.currentPhase == 'bidding_2') {
                  if (!room.trumpLocked && bid < 9 && trump != null && trump.code != room.trumpSuit) {
                    // Cannot change trump unless bid >= 9
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('You must bid 9+ to change the Trump suit!')),
                    );
                    return;
                  }
                }

                // Update player's bid
                await supabase.from('players').update({'bid': bid}).eq('id', localId!);
                
                if (bid >= 5 && trump != null && room.currentPhase == 'bidding') {
                   // TRUMP LOCK in Phase 1
                   await supabase.from('rooms').update({
                     'trump_suit': trump.code,
                     'trump_locked': true,
                     'current_phase': 'dealing_2',
                     'turn_index': (room.dealerIndex + 1) % players.length,
                   }).eq('id', room.id);
                } else if (trump != null && room.currentPhase == 'bidding_2') {
                   // Possible Trump Change in Phase 2 (Override checked above)
                   await supabase.from('rooms').update({
                     'trump_suit': trump.code,
                     'current_phase': 'playing',
                     'turn_index': (room.dealerIndex + 1) % players.length,
                   }).eq('id', room.id);
                } else {
                   // Move to next turn
                   final nextTurn = (room.turnIndex + 1);
                   if (nextTurn >= players.length) {
                      final nextPhase = room.currentPhase == 'bidding' ? 'dealing_2' : 'playing';
                      await supabase.from('rooms').update({
                        'current_phase': nextPhase,
                        'turn_index': (room.dealerIndex + 1) % players.length,
                      }).eq('id', room.id);
                   } else {
                      await supabase.from('rooms').update({
                        'turn_index': nextTurn,
                      }).eq('id', room.id);
                   }
                }
              },
            ),
          ),
        
        // Game Over Overlay
        if (room.status == 'finished')
           Center(
             child: Container(
               padding: const EdgeInsets.all(32),
               decoration: BoxDecoration(
                 color: Colors.black.withOpacity(0.9),
                 borderRadius: BorderRadius.circular(24),
                 border: Border.all(color: Colors.amber, width: 2),
               ),
               child: Column(
                 mainAxisSize: MainAxisSize.min,
                 children: [
                   const Text('GAME OVER', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.amber)),
                   const SizedBox(height: 24),
                   ...players.map((p) => Padding(
                     padding: const EdgeInsets.symmetric(vertical: 4),
                     child: Text('${p.name}: ${p.totalScore} pts', style: const TextStyle(fontSize: 18, color: Colors.white)),
                   )).toList(),
                   const SizedBox(height: 32),
                   ElevatedButton(
                     onPressed: () => Navigator.of(context).pushAndRemoveUntil(
                       MaterialPageRoute(builder: (context) => const HomeScreen()), 
                       (route) => false
                     ),
                     child: const Text('RETURN TO HOME'),
                   ),
                 ],
               ),
             ),
           ),
      ],
    );
  }

  Widget _buildPlayerArea(WidgetRef ref, Room room, Player player, bool isLocalPlayer, bool isTurn) {
    final cardsAsync = ref.watch(playerHandProvider(player.id));

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: isTurn ? Border.all(color: Colors.amber, width: 2) : null,
            boxShadow: isTurn ? [BoxShadow(color: Colors.amber.withOpacity(0.5), blurRadius: 10)] : null,
          ),
          child: CircleAvatar(
            backgroundColor: isTurn ? Colors.amber : Colors.white10,
            radius: 20,
            child: Text(
              player.name.isNotEmpty ? player.name[0] : '?', 
              style: TextStyle(color: isTurn ? Colors.black : Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          player.name,
          style: TextStyle(
            color: isTurn ? Colors.amber : Colors.white, 
            fontWeight: isTurn ? FontWeight.bold : FontWeight.normal,
            fontSize: 12,
          ),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (player.bid != null)
              Text('BID: ${player.bid}', style: const TextStyle(color: Colors.amber, fontSize: 10)),
            const SizedBox(width: 8),
            Text('WON: ${player.tricksWon}', style: const TextStyle(color: Colors.greenAccent, fontSize: 10)),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 80,
          child: cardsAsync.when(
            data: (cards) => _buildHand(ref, room, player, cards, isLocalPlayer, isTurn),
            loading: () => const SizedBox(),
            error: (e, s) => const SizedBox(),
          ),
        ),
      ],
    );
  }

  Widget _buildHand(WidgetRef ref, Room room, Player player, List<Map<String, dynamic>> cards, bool isLocalPlayer, bool isTurn) {
    final playableCards = ref.watch(playableCardsProvider(room.id));

    return Stack(
      clipBehavior: Clip.none,
      children: cards.asMap().entries.map((entry) {
        final i = entry.key;
        final card = entry.value;
        final cardValue = card['card_value'];
        final isPlayable = !isLocalPlayer || !isTurn || playableCards.isEmpty || playableCards.contains(cardValue);
        
        return Positioned(
          left: i * 20.0,
          child: GestureDetector(
            onTap: (isLocalPlayer && isTurn && room.currentPhase == 'playing' && isPlayable) 
              ? () async {
                  final service = ref.read(cardServiceProvider);
                  await service.playCard(room.id, player.id, cardValue);
                }
              : null,
            child: Opacity(
              opacity: isPlayable ? 1.0 : 0.4,
              child: _buildCard(cardValue, isLocalPlayer),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildCard(String cardValue, bool isVisible) {
    final card = CardModel.fromId(cardValue);
    final isRed = card.suit == Suit.hearts || card.suit == Suit.diamonds;

    return Container(
      width: 50,
      height: 75,
      decoration: BoxDecoration(
        color: isVisible ? Colors.white : Colors.blueGrey,
        borderRadius: BorderRadius.circular(6),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 4,
            offset: const Offset(2, 2),
          ),
        ],
        border: Border.all(color: Colors.white24, width: 0.5),
      ),
      child: isVisible
          ? Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  card.value,
                  style: TextStyle(
                    color: isRed ? Colors.red : Colors.black,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                Text(
                  _getSuitEmoji(card.suit.code),
                  style: const TextStyle(fontSize: 16),
                ),
              ],
            )
          : const Center(child: Text('♠', style: TextStyle(color: Colors.white24, fontSize: 24))),
    );
  }

  Widget _buildTableCenter(WidgetRef ref, String roomId, List<Player> players) {
    final playedCardsAsync = ref.watch(playedCardsProvider(roomId));

    return playedCardsAsync.when(
      data: (allPlayedCards) {
        // Only show last 4 cards (current trick)
        final trickSize = allPlayedCards.length % 4;
        final currentTrick = trickSize == 0 && allPlayedCards.isNotEmpty
            ? allPlayedCards.sublist(allPlayedCards.length - 4)
            : allPlayedCards.sublist(allPlayedCards.length - trickSize);

        return Stack(
          alignment: Alignment.center,
          children: currentTrick.map((played) {
            final playerIndex = players.indexWhere((p) => p.id == played['player_id']);
            
            // Position played cards slightly offset towards their player
            double dx = 0, dy = 0;
            if (playerIndex == 0) dy = 40; // Bottom
            else if (playerIndex == 1) dx = -40; // Left
            else if (playerIndex == 2) dy = -40; // Top
            else if (playerIndex == 3) dx = 40; // Right

            return Transform.translate(
              offset: Offset(dx, dy),
              child: _buildCard(played['card_value'], true),
            );
          }).toList(),
        );
      },
      loading: () => const SizedBox(),
      error: (e, s) => const SizedBox(),
    );
  }

  Widget _buildDeckVisual(int? cutValue) {
    // Simple representation of a deck of cards
    return Stack(
      alignment: Alignment.center,
      children: List.generate(10, (index) {
        return Transform.translate(
          offset: Offset(index * 0.5, -index * 0.5),
          child: Container(
            width: 50,
            height: 75,
            decoration: BoxDecoration(
              color: Colors.blueGrey.shade800,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.white24),
              boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 2)],
            ),
            child: const Center(child: Text('♠', style: TextStyle(color: Colors.white12, fontSize: 24))),
          ),
        );
      }),
    );
  }

  String _getSuitEmoji(String? code) {
    if (code == null) return '';
    switch (code) {
      case 'S': return '♠️';
      case 'H': return '♥️';
      case 'D': return '♦️';
      case 'C': return '♣️';
      default: return '';
    }
  }
}
