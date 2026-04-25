import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/tehri_provider.dart';
import '../models/tehri_models.dart';
import '../../minus/widgets/playing_card.dart';
import '../../minus/models/card_model.dart';
import '../widgets/tehri_bidding_overlay.dart';
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

    final roomAsync = ref.watch(tehriRoomProvider(widget.roomId!));
    final playersAsync = ref.watch(tehriPlayersProvider(widget.roomId!));

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
        if (room.status == 'selecting_dealer' && room.hostId == localId && !_isDealingSelection) {
          _isDealingSelection = true;
          _handleAutoSelection(room.id);
        } else if (room.status != 'selecting_dealer') {
          _isDealingSelection = false;
        }
      });
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
      // Start dealing clockwise from Cutter (Seat 1 if Dealer is 0)
      final dealerIdx = players.indexWhere((p) => p.id == room.dealerId);
      final startIndex = (dealerIdx + 1) % 4;
      
      // Stage 1 dealing (5 cards each) OR Stage 2 dealing (4 then 4)
      int rounds = isInitial ? 1 : 2; 

      for (int r = 0; r < rounds; r++) {
        for (int i = 0; i < 4; i++) {
          final p = players[(startIndex + i) % 4];
          await ref.read(tehriOpsProvider).dealBatch(room.id, p.id, count);
          await Future.delayed(const Duration(milliseconds: 600));
        }
      }

      if (isInitial) {
        await ref.read(tehriOpsProvider).finishInitialDealing(room.id);
      } else {
        await ref.read(tehriOpsProvider).finishDealing(room.id);
      }
    } catch (e) {
      debugPrint('Dealing Error: $e');
      _isDealingBatch = false;
    }
  }

  Future<void> _handleAutoSelection(String roomId) async {
    while (mounted && ref.read(tehriRoomProvider(roomId)).value?.status == 'selecting_dealer') {
      try {
        await ref.read(tehriOpsProvider).dealForSelection(roomId);
        await Future.delayed(const Duration(milliseconds: 1000));
      } catch (e) {
        debugPrint('Selection Error: $e');
        break;
      }
    }
    _isDealingSelection = false;
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
        _buildTopHUD(room),

        // 2. CENTER TRICK AREA
        Center(
          child: tricksAsync.when(
            data: (tricks) {
              final activeTrick = tricks.where((t) => t.winnerId == null).lastOrNull;
              return _buildTrickArea(activeTrick, rotatedPlayers);
            },
            loading: () => const SizedBox(),
            error: (e, s) => const SizedBox(),
          ),
        ),

        // 2.5 DEALER SELECTION OVERLAY
        if (room.status == 'selecting_dealer' && room.lastSelectionCard != null)
           _buildSelectionDisplay(room.lastSelectionCard!, rotatedPlayers),

        // 3. AVATARS (Same positions as Minus)
        _buildPlayerAvatar(rotatedPlayers[0], 'bottom', room, localId),
        _buildPlayerAvatar(rotatedPlayers[1], 'left', room, localId),
        _buildPlayerAvatar(rotatedPlayers[2], 'top', room, localId),
        _buildPlayerAvatar(rotatedPlayers[3], 'right', room, localId),

        // 4. MY HAND (Fan Layout similar to Minus)
        Positioned(
          bottom: 20,
          left: 0,
          right: 0,
          height: 200,
          child: handAsync.when(
            data: (hand) {
              final bool restricted = room.status == 'bidding_initial' && room.cutterId == me.id;
              final visibleHand = restricted ? hand.take(5).toList() : hand;
              return _buildHand(ref, room, me, visibleHand);
            },
            loading: () => const SizedBox(),
            error: (e, s) => const SizedBox(),
          ),
        ),

        // 5. BIDDING OVERLAYS
        if (room.status == 'bidding_initial' && room.cutterId == localId)
          Center(
            child: TehriBiddingOverlay(
              minBid: 7,
              isInitial: true,
              onBid: (bid, trump) => ref.read(tehriOpsProvider).setInitialBid(room.id, localId, bid, trump),
            ),
          ),

        if (room.status == 'bidding_final' && room.currentTurnIndex == me.seatIndex)
          Center(
            child: TehriBiddingOverlay(
              minBid: room.currentBid + 1,
              currentBid: room.currentBid,
              isInitial: false,
              onBid: (bid, trump) => ref.read(tehriOpsProvider).placeBid(room.id, localId, bid, trump),
            ),
          ),

        // 6. DEALER SELECTION / START CONTROLS
        if (room.status == 'waiting' && me.isHost && players.length == 4)
           Center(
             child: ElevatedButton(
               style: ElevatedButton.styleFrom(backgroundColor: accentGold, foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20)),
               onPressed: () => ref.read(tehriOpsProvider).startGame(room.id),
               child: const Text('START DEALER SELECTION', style: TextStyle(fontWeight: FontWeight.bold)),
             ),
           ),

        if (room.status == 'selecting_dealer')
          const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: accentGold),
                SizedBox(height: 16),
                Text('FINDING THE J...', style: TextStyle(color: accentGold, fontWeight: FontWeight.bold, letterSpacing: 2)),
              ],
            ),
          ),
        
        if (room.status == 'waiting_to_start' && me.isHost)
          Center(
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: accentGold, foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20)),
              onPressed: () => ref.read(tehriOpsProvider).initRound(room.id, room.dealerId!),
              child: const Text('START ROUND', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
      ],
    );
  }

  Widget _buildTopHUD(TehriRoom room) {
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
                if (room.trumpSuit != null)
                  Row(children: [
                    Text(CardModel.getSuitEmoji(room.trumpSuit!), style: const TextStyle(fontSize: 24)),
                    const SizedBox(width: 12),
                    Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('BID: ${room.currentBid}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
                      const Text('TRUMP SUIT', style: TextStyle(color: Colors.white38, fontSize: 8, fontWeight: FontWeight.bold)),
                    ]),
                  ]),
                Text(room.status.toUpperCase().replaceAll('_', ' '), style: const TextStyle(color: accentGold, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 2)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlayerAvatar(TehriPlayer player, String pos, TehriRoom room, String localId) {
    final bool isTurn = room.currentTurnIndex == player.seatIndex;
    final bool isDealer = room.dealerId == player.id;
    
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
                  Text(player.id == localId ? 'YOU' : player.name.toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900), overflow: TextOverflow.ellipsis),
                  const Divider(color: Colors.white10, indent: 10, endIndent: 10),
                  Text('${player.tricksWon}', style: const TextStyle(color: accentGold, fontSize: 18, fontWeight: FontWeight.w900)),
                  const Text('TRICKS', style: TextStyle(color: Colors.white24, fontSize: 8, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  if (player.id == room.dealerId)
                    Text('PTS: ${player.points}', style: const TextStyle(color: Colors.white38, fontSize: 8))
                  else
                    const SizedBox(height: 10),
                ],
              ),
            ),
            if (isDealer) const Padding(padding: EdgeInsets.only(top: 4), child: Text('DEALER', style: TextStyle(color: accentGold, fontSize: 8, fontWeight: FontWeight.w900))),
          ],
        ),
      ),
    );
  }

  Widget _buildHand(WidgetRef ref, TehriRoom room, TehriPlayer me, List<String> hand) {
    return Center(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: hand.asMap().entries.map((entry) {
            final cardId = entry.value;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: PlayingCard(
                card: CardModel.fromId(cardId),
                width: 70, height: 105,
                onTap: () {
                  if (room.status == 'playing' && room.currentTurnIndex == me.seatIndex) {
                    ref.read(tehriOpsProvider).playCard(room.id, me.id, cardId);
                  }
                },
              ),
            );
          }).toList(),
        ),
      ),
    );
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

  Widget _buildSelectionDisplay(Map<String, dynamic> selection, List<TehriPlayer> rotatedPlayers) {
    final cardId = selection['cardId'] as String;
    final playerId = selection['playerId'] as String;
    final isJack = selection['isJack'] as bool;
    final p = rotatedPlayers.firstWhere((p) => p.id == playerId);
    final posIdx = rotatedPlayers.indexOf(p);

    Offset offset;
    switch (posIdx) {
      case 0: offset = const Offset(0, 100); break;
      case 1: offset = const Offset(-100, 0); break;
      case 2: offset = const Offset(0, -100); break;
      case 3: offset = const Offset(100, 0); break;
      default: offset = Offset.zero;
    }

    return Center(
      child: Transform.translate(
        offset: offset,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            PlayingCard(card: CardModel.fromId(cardId), width: 90, height: 135),
            if (isJack)
              Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(color: accentGold, borderRadius: BorderRadius.circular(8)),
                child: const Text('FOUND THE J!', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 10)),
              ),
          ],
        ),
      ),
    );
  }
}
