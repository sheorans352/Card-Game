import 'dart:math' as math;
import 'dart:ui';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/tehri_provider.dart';
import '../models/tehri_models.dart';
import '../../minus/widgets/playing_card.dart';
import '../../minus/models/card_model.dart';
import '../widgets/tehri_bidding_overlay.dart';
import '../widgets/tehri_deck_cut_overlay.dart';
import '../../minus/widgets/spade_background.dart';

const Color primaryBg = Color(0xFF0A1A2F); 
const Color playerCardBg = Color(0xFF101E33); 
const Color accentGold = Color(0xFFE5B84B); 

class TehriGameScreen extends ConsumerStatefulWidget {
  final String? roomId;
  const TehriGameScreen({super.key, this.roomId});

  @override
  ConsumerState<TehriGameScreen> createState() => _TehriGameScreenState();
}

class _TehriGameScreenState extends ConsumerState<TehriGameScreen> {
  bool _isDealingBatch = false;
  bool _isDealingSelection = false;

  @override
  Widget build(BuildContext context) {
    if (widget.roomId == null) return const Scaffold(body: Center(child: Text('Invalid Room ID')));

    final sessionAsync = ref.watch(tehriSessionProvider);
    final roomAsync = ref.watch(tehriRoomProvider(widget.roomId!));
    final playersAsync = ref.watch(tehriPlayersProvider(widget.roomId!));

    if (sessionAsync.isLoading) {
      return const Scaffold(backgroundColor: primaryBg, body: Center(child: CircularProgressIndicator(color: accentGold)));
    }

    // Dealing Coordination (Dealer only)
    ref.listen<AsyncValue<TehriRoom?>>(tehriRoomProvider(widget.roomId!), (prev, next) {
      next.whenData((room) {
        if (room == null) return;
        final players = ref.read(tehriPlayersProvider(room.id)).value;
        if (players == null || players.length < 4) return;
        final localId = ref.read(localTehriPlayerIdProvider);
        
        if (room.dealerId == localId && !_isDealingBatch) {
          if (room.status == 'dealing_initial') {
            _isDealingBatch = true;
            _handleDealSequence(room, players, 5, isInitial: true);
          } else if (room.status == 'dealing_remaining') {
             _isDealingBatch = true;
             _handleDealSequence(room, players, 4, isInitial: false);
          }
        } else if (!room.status.startsWith('dealing')) {
          _isDealingBatch = false;
        }

        // Automatic Dealer Selection Dealing
        // We rely on DB status and being the host to trigger the loop
        final localPlayer = players?.firstWhere((p) => p.id == localId, orElse: () => players!.first);
        if (room.status == 'selecting_dealer' && (localPlayer?.isHost ?? false) && !_isDealingSelection) {
          _isDealingSelection = true;
          debugPrint('Starting Auto Selection loop for ${room.id}');
          _handleAutoSelection(room.id);
        } else if (room.status != 'selecting_dealer') {
          _isDealingSelection = false;
        }
      });
    });

    // Clear optimistic card state when a new round starts
    ref.listen<AsyncValue<TehriRoom?>>(tehriRoomProvider(widget.roomId!), (prev, next) {
      final prevStatus = prev?.value?.status;
      final nextStatus = next.value?.status;
      if (nextStatus == 'cutting' && prevStatus != 'cutting') {
        ref.read(tehriLocalPlayedCardsProvider.notifier).state = {};
        ref.read(tehriPendingCardPlayProvider.notifier).state = {};
      }
    });

    return Scaffold(
      backgroundColor: primaryBg,
      body: roomAsync.when(
        data: (room) {
          if (room == null) return const Center(child: Text('Room not found', style: TextStyle(color: Colors.white)));
          
          return playersAsync.when(
            data: (players) {
              final localPlayerId = ref.watch(localTehriPlayerIdProvider);
              if (localPlayerId == null) {
                return Scaffold(
                  backgroundColor: primaryBg,
                  body: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('PLEASE JOIN VIA THE LOBBY', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 20),
                        ElevatedButton(
                          onPressed: () => context.go('/tehri'),
                          child: const Text('GO TO LOBBY'),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return _buildGameTable(context, ref, room, players, localPlayerId);
            },
            loading: () => const Center(child: CircularProgressIndicator(color: accentGold)),
            error: (e, s) => Center(child: Text('Error: $e')),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator(color: accentGold)),
        error: (e, s) => Center(child: Text('Error: $e')),
      ),
    );
  }

  Future<void> _handleDealSequence(TehriRoom room, List<TehriPlayer> players, int count, {required bool isInitial}) async {
    try {
      // Find the cutter's seat index to start dealing
      final cutterIdx = players.indexWhere((p) => p.id == room.cutterId);
      if (cutterIdx == -1) return;

      int rounds = isInitial ? 1 : 2;

      for (int r = 0; r < rounds; r++) {
        for (int i = 0; i < 4; i++) {
          // Move anti-clockwise in a circle starting from the cutter
          final seatToDeal = (cutterIdx + i) % 4;
          final p = players.firstWhere((p) => p.seatIndex == seatToDeal);
          
          await ref.read(tehriOpsProvider).dealBatch(room.id, p.id, count);
          
          // Small delay between players to make the "dealing" visible
          await Future.delayed(const Duration(milliseconds: 700));
        }
      }

      if (isInitial) {
        await ref.read(tehriOpsProvider).finishInitialDealing(room.id);
      } else {
        await ref.read(tehriOpsProvider).finishDealing(room.id);
      }
    } catch (e) {
      debugPrint('Dealing Error: $e');
    } finally {
      if (mounted) setState(() => _isDealingBatch = false);
    }
  }

  Future<void> _handleAutoSelection(String roomId) async {
    while (mounted) {
      final currentRoom = ref.read(tehriRoomProvider(roomId)).value;
      if (currentRoom?.status != 'selecting_dealer') break;
      
      try {
        debugPrint('Dealing one card for selection...');
        await ref.read(tehriOpsProvider).dealForSelection(roomId);
        await Future.delayed(const Duration(milliseconds: 1500)); // Slightly slower for ritual feel
      } catch (e) {
        debugPrint('Selection Error: $e');
        // If it's a phase error, just stop
        if (e.toString().contains('phase')) break;
        await Future.delayed(const Duration(seconds: 2));
      }
    }
    _isDealingSelection = false;
    debugPrint('Auto Selection loop finished');
  }


  Widget _buildGameTable(BuildContext context, WidgetRef ref, TehriRoom room, List<TehriPlayer> players, String localId) {
    final me = players.firstWhere((p) => p.id == localId);
    final localIndex = players.indexOf(me);
    final rotatedPlayers = List.generate(4, (i) => players[(localIndex + i) % 4]);
    final handAsync = ref.watch(tehriHandProvider(localId));
    final tricksAsync = ref.watch(tehriTricksProvider(room.id));

    return Stack(
      children: [
        const SpadeBackground(),
        
        // 1. TOP HUD
        _buildTopHUD(room, players),

        // 2. CENTER TRICK AREA
        Center(
          child: tricksAsync.when(
            data: (tricks) {
              final activeTrick = (room.status == 'playing') 
                  ? tricks.where((t) => t.winnerId == null).lastOrNull 
                  : null;
              return _buildTrickArea(activeTrick, rotatedPlayers);
            },
            loading: () => const SizedBox(),
            error: (e, s) => const SizedBox(),
          ),
        ),

        // 2.5 DEALER SELECTION: Cards dealt near each player avatar
        // Keep the last dealt card visible during waiting_to_start so J♠ stays on screen
        if ((room.status == 'selecting_dealer' || room.status == 'waiting_to_start') && room.lastSelectionCard != null)
          _buildSelectionCards(room.lastSelectionCard!, rotatedPlayers),

        // 3. OPPONENT HAND FANS first (so they render BEHIND avatars)
        ..._buildOpponentHands(ref, rotatedPlayers),

        // AVATARS on top of fan cards
        _buildPlayerAvatar(rotatedPlayers[0], 'bottom', room, localId, players),
        _buildPlayerAvatar(rotatedPlayers[1], 'left', room, localId, players),
        _buildPlayerAvatar(rotatedPlayers[2], 'top', room, localId, players),
        _buildPlayerAvatar(rotatedPlayers[3], 'right', room, localId, players),

        // 4. MY HAND — animated cards slide in, sorted by suit/rank
        ...handAsync.when(
          data: (hand) {
            final localPlayedCards = ref.watch(tehriLocalPlayedCardsProvider);
            final pendingCards = ref.watch(tehriPendingCardPlayProvider);

            final bool restricted = room.status == 'bidding_initial' && room.cutterId == me.id;
            final rawHand = restricted ? hand.take(5).toList() : hand;
            // Optimistically exclude cards the player has already tapped
            final visibleHand = rawHand.where((c) => !localPlayedCards.contains(c)).toList();
            final sortedHand = List<String>.from(visibleHand)..sort((a, b) {
              const suitOrder = {'S': 0, 'H': 1, 'D': 2, 'C': 3};
              final sA = a.substring(a.length - 1);
              final sB = b.substring(b.length - 1);
              final sCmp = (suitOrder[sA] ?? 4).compareTo(suitOrder[sB] ?? 4);
              if (sCmp != 0) return sCmp;
              return CardModel.getRankValue(b).compareTo(CardModel.getRankValue(a));
            });
            final isMyTurn = room.status == 'playing' && room.currentTurnIndex == me.seatIndex;
            
            // LEAD SUIT ENFORCEMENT:
            String? leadSuit;
            final tricks = tricksAsync.value ?? [];
            final activeTrick = tricks.where((t) => t.winnerId == null).lastOrNull;
            if (activeTrick != null && activeTrick.cards.isNotEmpty) {
              final firstCard = activeTrick.cards.first;
              leadSuit = firstCard.substring(firstCard.length - 1).toUpperCase();
            }

            final bool hasLeadSuit = leadSuit != null && 
                visibleHand.any((c) => c.substring(c.length - 1).toUpperCase() == leadSuit);

            return sortedHand.asMap().entries.map((e) {
              final cardId = e.value;
              final isPending = pendingCards.contains(cardId);
              final cardSuit = cardId.substring(cardId.length - 1).toUpperCase();
              
              bool canPlay = isMyTurn && !isPending;
              if (canPlay && hasLeadSuit && cardSuit != leadSuit) {
                canPlay = false; // Must follow suit if you have it
              }

              return TehriHandCardWidget(
                key: ValueKey(cardId),
                cardId: cardId,
                index: e.key,
                total: sortedHand.length,
                isPlayable: canPlay,
                onTap: (isMyTurn && !isPending) ? () {
                  // If they tap an unplayable card, we still let the RPC fail or we can block it here
                  // To be strict, we only allow tap if canPlay is true
                  if (!canPlay && hasLeadSuit) return; 

                  // Optimistic: remove card from hand instantly
                  ref.read(tehriPendingCardPlayProvider.notifier).update((s) => {...s, cardId});
                  ref.read(tehriLocalPlayedCardsProvider.notifier).update((s) => {...s, cardId});
                  // Fire RPC in background — rollback on failure
                  ref.read(tehriOpsProvider).playCard(room.id, me.id, cardId).catchError((_) {
                    ref.read(tehriPendingCardPlayProvider.notifier).update((s) => s.where((v) => v != cardId).toSet());
                    ref.read(tehriLocalPlayedCardsProvider.notifier).update((s) => s.where((v) => v != cardId).toSet());
                  });
                } : null,
              );
            }).toList();
          },
          loading: () => [],
          error: (e, s) => [],
        ),

        // 4.5 TURN INDICATOR — shown when in playing phase
        if (room.status == 'playing')
          Center(
            child: Padding(
              padding: const EdgeInsets.only(top: 160), // Push slightly below the cards
              child: Builder(builder: (context) {
                final isMyTurn = room.currentTurnIndex == me.seatIndex;
                final currentPlayer = players.firstWhereOrNull((p) => p.seatIndex == room.currentTurnIndex);
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: isMyTurn ? accentGold.withOpacity(0.18) : Colors.black45,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isMyTurn ? accentGold : Colors.white24,
                      width: isMyTurn ? 1.5 : 1,
                    ),
                    boxShadow: isMyTurn ? [BoxShadow(color: accentGold.withOpacity(0.3), blurRadius: 12, spreadRadius: 2)] : [],
                  ),
                  child: Text(
                    isMyTurn
                      ? '✦ YOUR TURN — TAP A CARD ✦'
                      : 'Waiting for ${currentPlayer?.name ?? 'player'} to play...',
                    style: TextStyle(
                      color: isMyTurn ? accentGold : Colors.white54,
                      fontSize: isMyTurn ? 12 : 10,
                      fontWeight: isMyTurn ? FontWeight.w900 : FontWeight.w500,
                      letterSpacing: isMyTurn ? 1.5 : 0.5,
                    ),
                  ),
                );
              }),
            ),
          ),

        // 5. BIDDING OVERLAYS (Centered popup)
        if (room.status == 'bidding_initial')
          if (room.cutterId == localId)
            TehriBiddingOverlay(
              minBid: 7,
              isInitial: true,
              onBid: (bid, trump) => ref.read(tehriOpsProvider).setInitialBid(room.id, localId, bid, trump),
            )
          else
            _buildCenterStatus('Waiting for ${players.firstWhereOrNull((p) => p.id == room.cutterId)?.name ?? 'Cutter'} to set the initial bid...'),

        if (room.status == 'bidding_final')
          if (room.currentTurnIndex == me.seatIndex)
            TehriBiddingOverlay(
              minBid: room.currentBid + 1,
              currentBid: room.currentBid,
              isInitial: false,
              onBid: (bid, trump) => ref.read(tehriOpsProvider).placeBid(room.id, localId, bid, trump),
            )
          else
            _buildCenterStatus('Waiting for ${players.firstWhereOrNull((p) => p.seatIndex == room.currentTurnIndex)?.name ?? 'player'} to bid...'),

        // 6. SELECTION PHASE BOTTOM CONTROLS (host-only subtle button)
        if (room.status == 'selecting_dealer')
          Positioned(
            bottom: 20, left: 0, right: 0,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: accentGold.withOpacity(0.3)),
                    ),
                    child: const Text('Searching for Jack of Spades...', 
                      style: TextStyle(color: accentGold, fontSize: 11, letterSpacing: 1)),
                  ),
                  if (me.isHost) ...[
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accentGold,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: () => ref.read(tehriOpsProvider).dealForSelection(room.id),
                      icon: const Icon(Icons.arrow_forward_ios, size: 16),
                      label: const Text('DEAL NEXT CARD', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    ),
                  ],
                ],
              ),
            ),
          ),

        // Dealer sees deal button during batch dealing phases
        if (room.status == 'dealing_initial' && me.id == room.dealerId && !_isDealingBatch)
          Positioned(
            bottom: 20, left: 0, right: 0,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: accentGold.withOpacity(0.3)),
                    ),
                    child: const Text('You are Dealing — deal 5 cards to each player', 
                      style: TextStyle(color: accentGold, fontSize: 11)),
                  ),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accentGold,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 18),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: () {
                      setState(() => _isDealingBatch = true);
                      _handleDealSequence(room, players, 5, isInitial: true);
                    },
                    icon: const Icon(Icons.style, size: 18),
                    label: const Text('DEAL 5 CARDS TO ALL', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  ),
                ],
              ),
            ),
          ),
        if (room.status == 'dealing_initial' && me.id != room.dealerId)
          Positioned(
            bottom: 20, left: 0, right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: accentGold.withOpacity(0.3)),
                ),
                child: const Text('Dealer is dealing your first 5 cards...', 
                  style: TextStyle(color: accentGold, fontSize: 12)),
              ),
            ),
          ),

        if (room.status == 'dealing_remaining' && me.id == room.dealerId && !_isDealingBatch)
          Positioned(
            bottom: 20, left: 0, right: 0,
            child: Center(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: accentGold,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 18),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: () {
                  setState(() => _isDealingBatch = true);
                  _handleDealSequence(room, players, 4, isInitial: false);
                },
                icon: const Icon(Icons.style, size: 18),
                label: const Text('DEAL REMAINING CARDS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              ),
            ),
          ),
        if (room.status == 'dealing_remaining' && me.id != room.dealerId)
          Positioned(
            bottom: 20, left: 0, right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: accentGold.withOpacity(0.3)),
                ),
                child: const Text('Dealer is dealing remaining cards...', 
                  style: TextStyle(color: accentGold, fontSize: 12)),
              ),
            ),
          ),

        if (room.status == 'waiting' && me.isHost && players.length == 4)
           Center(
             child: ElevatedButton(
               style: ElevatedButton.styleFrom(backgroundColor: accentGold, foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20)),
               onPressed: () => ref.read(tehriOpsProvider).startGame(room.id),
               child: const Text('START DEALER SELECTION', style: TextStyle(fontWeight: FontWeight.bold)),
             ),
           ),
        
        // Dealer gets the Collect & Reshuffle button; everyone else waits
        if (room.status == 'waiting_to_start') ...[
          Builder(builder: (context) {
            final dealerPlayer = players.firstWhere(
              (p) => p.id == room.dealerId,
              orElse: () => players.first,
            );
            final dealerName = dealerPlayer.id == me.id ? 'You' : dealerPlayer.name;

            if (me.id == room.dealerId) {
              return Positioned(
                bottom: 20, left: 0, right: 0,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        decoration: BoxDecoration(
                          color: accentGold.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: accentGold.withOpacity(0.5)),
                        ),
                        child: const Text('You are the Dealer!', 
                          style: TextStyle(color: accentGold, fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 1)),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: accentGold, 
                          foregroundColor: Colors.black, 
                          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        onPressed: () => ref.read(tehriOpsProvider).startCutting(room.id),
                        child: const Text('COLLECT & RESHUFFLE', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      ),
                    ],
                  ),
                ),
              );
            } else {
              return Positioned(
                bottom: 20, left: 0, right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: accentGold.withOpacity(0.3)),
                    ),
                    child: Text('${dealerPlayer.name} is the Dealer — collecting cards...', 
                      style: const TextStyle(color: accentGold, fontSize: 12)),
                  ),
                ),
              );
            }
          }),
        ],

        // 7. CUTTING OVERLAY
        if (room.status == 'cutting') 
          TehriDeckCutOverlay(roomId: room.id),

        // 8. ROUND SUMMARY OVERLAY
        if (room.status == 'resolving_round' && room.lastRoundSummary != null)
          TehriRoundSummaryOverlay(roomId: room.id, summary: room.lastRoundSummary!),
      ],
    );
  }

  Widget _buildTopHUD(TehriRoom room, List<TehriPlayer> players) {
    return Positioned(
      top: 0, left: 0, right: 0,
      child: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            height: 64,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(color: Colors.black.withOpacity(0.5), border: Border(bottom: BorderSide(color: Colors.white10))),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (room.trumpSuit != null && room.bidderId != null) ...[
                  Builder(builder: (context) {
                    final bidder = players.firstWhereOrNull((p) => p.id == room.bidderId);
                    return Row(children: [
                      Text(CardModel.getSuitEmoji(room.trumpSuit!), style: const TextStyle(fontSize: 22)),
                      const SizedBox(width: 10),
                      Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('${bidder?.name ?? 'Bidder'}: ${room.currentBid}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12)),
                        const Text('BID & TRUMP', style: TextStyle(color: Colors.white38, fontSize: 8, fontWeight: FontWeight.bold)),
                      ]),
                    ]);
                  }),
                ],
                // CENTER: Tehri score + game wins (once bid is set)
                Builder(builder: (context) {
                  if (players.length < 4) {
                    return Text(room.status.toUpperCase().replaceAll('_', ' '),
                      style: const TextStyle(color: accentGold, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 2));
                  }
                  // Source of truth: teamIndex from database
                  final teamA = players.where((p) => p.teamIndex == 0).toList();
                  final teamB = players.where((p) => p.teamIndex == 1).toList();
                  
                  final teamATricks = teamA.fold(0, (sum, p) => sum + p.tricksWon);
                  final teamBTricks = teamB.fold(0, (sum, p) => sum + p.tricksWon);
                  
                  final nameA = teamA.isEmpty ? 'Team A' : teamA.map((p) => p.name).join(' & ');
                  final nameB = teamB.isEmpty ? 'Team B' : teamB.map((p) => p.name).join(' & ');

                  final bidderPlayer = players.firstWhereOrNull((p) => p.id == room.bidderId);
                  final bidderTeamIndex = bidderPlayer?.teamIndex;
                  
                  // For the non-bidding team, the target to "break" the bid is (14 - currentBid)
                  // e.g. Bid 7 -> Opponent needs 7 (14-7). Bid 8 -> Opponent needs 6 (14-8).
                  final breakTarget = 14 - room.currentBid;

                  return Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildTeamHUDRow(
                        nameA, 
                        teamATricks, 
                        bidderTeamIndex == 0 ? room.currentBid : breakTarget, 
                        bidderTeamIndex == 0, 
                        room.gameWinsEvenTeam, 
                        room.currentBid,
                        isEven: true,
                        label: bidderTeamIndex == 0 ? 'bid' : 'to break'
                      ),
                      const SizedBox(height: 4),
                      _buildTeamHUDRow(
                        nameB, 
                        teamBTricks, 
                        bidderTeamIndex == 1 ? room.currentBid : breakTarget, 
                        bidderTeamIndex == 1, 
                        room.gameWinsOddTeam, 
                        room.currentBid,
                        isEven: false,
                        label: bidderTeamIndex == 1 ? 'bid' : 'to break'
                      ),
                    ],
                  );
                }),

                // Quit Button
                IconButton(
                  icon: const Icon(Icons.logout, color: Colors.white38, size: 20),
                  onPressed: () => _confirmQuit(context),
                  tooltip: 'Quit Room',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTeamHUDRow(String names, int tricks, int target, bool isBidderTeam, int wins, int currentBid, {required bool isEven, required String label}) {
    final color = isEven ? accentGold : Colors.white70;
    final bg = isEven ? accentGold.withOpacity(0.15) : Colors.white.withOpacity(0.08);
    final hasBid = currentBid > 0;
    
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 100,
          child: Text(names, 
            style: TextStyle(color: color, fontSize: 8, fontWeight: FontWeight.bold),
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.right,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(4),
            border: (hasBid && isBidderTeam) ? Border.all(color: color.withOpacity(0.3), width: 0.5) : null,
          ),
          child: Text(
            hasBid
              ? '$tricks / $target $label  •  $wins W'
              : '$wins wins',
            style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 0.2),
          ),
        ),
      ],
    );
  }

  void _confirmQuit(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: playerCardBg,
        title: const Text('Quit Game?', style: TextStyle(color: Colors.white)),
        content: const Text('Are you sure you want to leave the room?', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              ref.read(tehriSessionProvider.notifier).clearSession();
              context.go('/');
            },
            child: const Text('QUIT'),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayerAvatar(TehriPlayer player, String pos, TehriRoom room, String localId, List<TehriPlayer> allPlayers) {
    final bool isTurn = room.currentTurnIndex == player.seatIndex;
    final bool isDealer = room.dealerId == player.id;
    final bool isMe = player.id == localId;

    Alignment alignment; EdgeInsets padding;
    switch (pos) {
      case 'bottom': alignment = Alignment.bottomLeft; padding = const EdgeInsets.only(left: 20, bottom: 220); break;
      case 'left': alignment = Alignment.topLeft; padding = const EdgeInsets.only(left: 20, top: 100); break;
      case 'top': alignment = Alignment.topRight; padding = const EdgeInsets.only(right: 20, top: 100); break;
      case 'right': alignment = Alignment.bottomRight; padding = const EdgeInsets.only(right: 20, bottom: 220); break;
      default: alignment = Alignment.center; padding = EdgeInsets.zero;
    }

    return Align(
      alignment: alignment,
      child: Padding(
        padding: padding,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80, height: 110,
              decoration: BoxDecoration(
                color: playerCardBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isTurn ? accentGold : Colors.white10, width: isTurn ? 2 : 1),
                boxShadow: [if (isTurn) BoxShadow(color: accentGold.withOpacity(0.2), blurRadius: 15)],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(isMe ? 'YOU' : player.name.toUpperCase(),
                    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                    overflow: TextOverflow.ellipsis),
                  Container(
                    width: 40, height: 1, 
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    color: accentGold.withOpacity(0.2),
                  ),
                  
                  // Always show personal tricks won this round
                  Text('${player.tricksWon}', 
                    style: const TextStyle(color: accentGold, fontSize: 18, fontWeight: FontWeight.w900)),
                  const Text('TRICKS', style: TextStyle(color: Colors.white24, fontSize: 8, fontWeight: FontWeight.bold)),
                  
                  const SizedBox(height: 6),

                  // If Dealer, show Tehri score points (0-52)
                  if (isDealer && room.status != 'selecting_dealer' && room.status != 'waiting_to_start') ...[
                    const Divider(color: Colors.white10, indent: 15, endIndent: 15, height: 8),
                    Text('${room.tehriScore}',
                      style: TextStyle(
                        color: room.tehriScore <= 20 ? Colors.greenAccent
                             : room.tehriScore <= 40 ? Colors.amberAccent
                             : Colors.redAccent,
                        fontSize: 12, fontWeight: FontWeight.w900,
                      )),
                    const Text('TEHRI PTS', style: TextStyle(color: Colors.white24, fontSize: 6, fontWeight: FontWeight.bold)),
                  ],
                ],
              ),
            ),
            if (isDealer) const Padding(padding: EdgeInsets.only(top: 4), child: Text('DEALER', style: TextStyle(color: accentGold, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 1))),
          ],
        ),
      ),
    );
  }

  // Build face-down opponent fan cards (indices 1-3 in rotated list)
  List<Widget> _buildOpponentHands(WidgetRef ref, List<TehriPlayer> rotatedPlayers) {
    final positions = ['left', 'top', 'right'];
    final List<Widget> widgets = [];
    for (int i = 1; i <= 3; i++) {
      final p = rotatedPlayers[i];
      final pos = positions[i - 1];
      final handAsync = ref.watch(tehriHandProvider(p.id));
      handAsync.whenData((cards) {
        for (int j = 0; j < cards.length; j++) {
          widgets.add(TehriOpponentCardWidget(position: pos, index: j, total: cards.length));
        }
      });
    }
    return widgets;
  }

  Widget _buildTrickArea(TehriTrick? trick, List<TehriPlayer> rotatedPlayers) {
    if (trick == null || trick.cards.isEmpty) return const SizedBox();
    return Stack(
      children: trick.cards.asMap().entries.map((entry) {
        final cardId = entry.value;
        final playerId = trick.playerIds[entry.key];
        final p = rotatedPlayers.firstWhere((p) => p.id == playerId);
        final posIdx = rotatedPlayers.indexOf(p);
        
        Offset offset;
        switch (posIdx) {
          case 0: offset = const Offset(0, 60); break;
          case 1: offset = const Offset(-60, 0); break;
          case 2: offset = const Offset(0, -60); break;
          case 3: offset = const Offset(60, 0); break;
          default: offset = Offset.zero;
        }

        return Center(
          child: Transform.translate(
            offset: offset,
            child: PlayingCard(card: CardModel.fromId(cardId), width: 80, height: 110),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSelectionCards(Map<String, dynamic> lastCard, List<TehriPlayer> rotatedPlayers) {
    // DB stores camelCase: cardId, playerId, isJack
    final cardId = (lastCard['cardId'] ?? lastCard['card_id']) as String?;
    final receiverId = (lastCard['playerId'] ?? lastCard['player_id']) as String?;
    final isJack = (lastCard['isJack'] ?? lastCard['is_jack']) as bool? ?? false;

    if (cardId == null || receiverId == null) return const SizedBox();

    final posIdx = rotatedPlayers.indexWhere((p) => p.id == receiverId);
    if (posIdx < 0) return const SizedBox();

    // Avatar positions mirror _buildPlayerAvatar:
    // posIdx 0 = 'bottom' → bottomLeft, padding left:20 bottom:220, box is 80×110
    // posIdx 1 = 'left'   → topLeft, padding left:20 top:100
    // posIdx 2 = 'top'    → topRight, padding right:20 top:100
    // posIdx 3 = 'right'  → bottomRight, padding right:20 bottom:220

    // Card is 55×80. We place it at the top-right corner of the avatar box (or equivalent)
    final card = PlayingCard(card: CardModel.fromId(cardId), width: 55, height: 80);

    Widget badge = isJack
      ? Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: accentGold,
            borderRadius: BorderRadius.circular(6),
            boxShadow: [BoxShadow(color: accentGold.withOpacity(0.7), blurRadius: 8)],
          ),
          child: const Text('DEALER', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 10)),
        )
      : const SizedBox();

    switch (posIdx) {
      case 0: // bottom-left avatar → card pops out at its top-right corner
        return Positioned(
          left: 20 + 80 - 28,   // avatar left(20) + avatar width(80) - card overlap(28)
          bottom: 220 + 110 - 10, // avatar bottom(220) + avatar height(110) - card overlap
          child: Column(mainAxisSize: MainAxisSize.min, children: [badge, const SizedBox(height: 2), card]),
        );
      case 1: // top-left avatar → card pops out at its top-right corner
        return Positioned(
          left: 20 + 80 - 28,
          top: 100 - 10,
          child: Column(mainAxisSize: MainAxisSize.min, children: [badge, const SizedBox(height: 2), card]),
        );
      case 2: // top-right avatar → card pops out at its top-left corner
        return Positioned(
          right: 20 + 80 - 28,
          top: 100 - 10,
          child: Column(mainAxisSize: MainAxisSize.min, children: [badge, const SizedBox(height: 2), card]),
        );
      case 3: // bottom-right avatar → card pops out at its top-left corner
        return Positioned(
          right: 20 + 80 - 28,
          bottom: 220 + 110 - 10,
          child: Column(mainAxisSize: MainAxisSize.min, children: [badge, const SizedBox(height: 2), card]),
        );
      default:
        return const SizedBox();
    }
  }

  Widget _buildCenterStatus(String message) {
    return Align(
      alignment: const Alignment(0, -0.35), // Move up from center
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 40),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.black87,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: accentGold.withOpacity(0.3)),
          boxShadow: const [
            BoxShadow(color: Colors.black54, blurRadius: 10),
          ],
        ),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: accentGold,
            fontSize: 13,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }
}

// ─── Animated hand card (my cards slide in from top like dealing) ───────────
class TehriHandCardWidget extends StatefulWidget {
  final String cardId;
  final int index;
  final int total;
  final bool isPlayable;
  final VoidCallback? onTap;

  const TehriHandCardWidget({
    super.key,
    required this.cardId,
    required this.index,
    required this.total,
    required this.isPlayable,
    this.onTap,
  });

  @override
  State<TehriHandCardWidget> createState() => _TehriHandCardWidgetState();
}

class _TehriHandCardWidgetState extends State<TehriHandCardWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _progress;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 480));
    _progress = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
    // Stagger: each card in batch slides in slighly after the previous
    final stagger = (widget.index % 13) * 55;
    Future.delayed(Duration(milliseconds: stagger), () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final total = widget.total;
    final i = widget.index;

    // Fan layout using REAL layout position so hit area matches visual on Flutter Web
    final fanX = (i - (total - 1) / 2.0) * 22.0;
    final fanAngle = (i - (total - 1) / 2.0) * 0.07;
    // Positioned.left = screen center + fan offset - half card width
    final cardLeft = (screenWidth / 2) + fanX - 35.0;
    const cardBottom = 85.0;

    // Positioned (not Align+Transform.translate) so hit area = visual position
    return Positioned(
      left: cardLeft,
      bottom: cardBottom,
      child: AnimatedBuilder(
        animation: _progress,
        builder: (context, _) {
          final t = _progress.value;
          // Only Y for the slide-in animation; X is handled by Positioned.left
          final slideY = -(1.0 - t) * 380.0;
          final currentAngle = fanAngle * t;
          final opacity = (t * 2.5).clamp(0.0, 1.0);
          return Opacity(
            opacity: opacity,
            child: Transform.translate(
              offset: Offset(0, slideY), // Y-only — zero after animation ends
              child: Transform.rotate(
                angle: currentAngle,
                child: Opacity(
                  opacity: widget.isPlayable ? 1.0 : 0.4,
                  child: PlayingCard(
                    card: CardModel.fromId(widget.cardId),
                    isFaceUp: true,
                    isPlayable: widget.isPlayable,
                    onTap: widget.onTap,
                    width: 70,
                    height: 105,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─── Face-down opponent card fan (same as Minus OpponentCardWidget) ──────────
class TehriOpponentCardWidget extends StatelessWidget {
  final String position;
  final int index;
  final int total;
  const TehriOpponentCardWidget({
    super.key,
    required this.position,
    required this.index,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    final fanOffset = (index - (total - 1) / 2) * 12.0;
    final rotation = (index - (total - 1) / 2) * 0.05;
    Alignment alignment;
    EdgeInsets padding;
    double angle;
    switch (position) {
      case 'left':
        alignment = Alignment.topLeft;
        padding = const EdgeInsets.only(left: 20, top: 100);
        angle = math.pi / 6 + (rotation * 0.5);
        break;
      case 'top':
        alignment = Alignment.topRight;
        padding = const EdgeInsets.only(right: 20, top: 100);
        angle = -math.pi / 6 + (rotation * 0.5);
        break;
      case 'right':
        alignment = Alignment.bottomRight;
        padding = const EdgeInsets.only(right: 20, bottom: 210);
        angle = -math.pi / 12 + (rotation * 0.5);
        break;
      default:
        alignment = Alignment.center;
        padding = EdgeInsets.zero;
        angle = 0;
    }
    return Align(
      alignment: alignment,
      child: Padding(
        padding: padding,
        child: SizedBox(
          width: 86,
          height: 120,
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              Transform.translate(
                offset: Offset(fanOffset, -10),
                child: Transform.rotate(
                  angle: angle,
                  child: const PlayingCard(isFaceUp: false, width: 44, height: 66),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

}

class TehriRoundSummaryOverlay extends ConsumerWidget {
  final String roomId;
  final Map<String, dynamic> summary;

  const TehriRoundSummaryOverlay({super.key, required this.roomId, required this.summary});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final oldScore = summary['oldScore'] ?? 0;
    final newScore = summary['newScore'] ?? 0;
    final delta = summary['scoreDelta'] ?? 0;
    final bidderName = summary['bidderName'] ?? 'Unknown';
    final bidAmount = summary['bidAmount'] ?? 0;
    final tricksMade = summary['tricksMade'] ?? 0;
    final bidSuccess = summary['bidSuccess'] ?? false;
    final dealerStatus = summary['dealerStatus'] ?? '';
    final nextDealer = summary['nextDealerName'] ?? '';

    final room = ref.watch(tehriRoomProvider(roomId)).value;
    final me = ref.watch(localTehriPlayerIdProvider);
    final isDealer = room?.dealerId == me;

    return Center(
      child: Container(
        padding: const EdgeInsets.all(24),
        margin: const EdgeInsets.symmetric(horizontal: 40),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.95),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: accentGold.withOpacity(0.3), width: 2),
          boxShadow: [
            BoxShadow(color: accentGold.withOpacity(0.2), blurRadius: 20, spreadRadius: 5),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('ROUND COMPLETED', 
              style: TextStyle(color: accentGold, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 2)),
            const SizedBox(height: 16),
            
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              decoration: BoxDecoration(
                color: (bidSuccess ? Colors.green : Colors.red).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Bidder Team', style: TextStyle(color: Colors.white70, fontSize: 10)),
                      Text(bidderName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text('Required v/s Actual', style: TextStyle(color: Colors.white70, fontSize: 10)),
                      Text('$bidAmount v/s $tricksMade', style: TextStyle(
                        color: bidSuccess ? Colors.greenAccent : Colors.redAccent,
                        fontWeight: FontWeight.bold, fontSize: 14)),
                    ],
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 20),
            
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildScoreBox('START', oldScore.toString()),
                const Icon(Icons.arrow_forward_rounded, color: Colors.white24, size: 24),
                _buildScoreBox('END', newScore.toString(), color: accentGold),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: (delta >= 0 ? Colors.red : Colors.green).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    (delta >= 0 ? '+$delta' : '$delta'),
                    style: TextStyle(
                      color: delta >= 0 ? Colors.redAccent : Colors.greenAccent,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 20),
            
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(12)),
              child: Column(
                children: [
                   Text(dealerStatus.toUpperCase(), style: const TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold)),
                   const SizedBox(height: 4),
                   Text('NEXT DEALER: $nextDealer', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            if (isDealer)
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: accentGold,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => ref.read(tehriOpsProvider).finalizeRoundSummary(roomId),
                child: const Text('PROCEED TO NEXT ROUND', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
              )
            else
              const Text('Waiting for Dealer to proceed...', style: TextStyle(color: Colors.white38, fontSize: 11, fontStyle: FontStyle.italic)),
          ],
        ),
      ),
    );
  }

  Widget _buildScoreBox(String label, String value, {Color? color}) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.white38, fontSize: 9, fontWeight: FontWeight.bold)),
        Text(value, style: TextStyle(color: color ?? Colors.white, fontSize: 24, fontWeight: FontWeight.w900)),
      ],
    );
  }
}
