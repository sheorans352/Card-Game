import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/room_provider.dart';
import '../services/card_service.dart';
import '../models/game_models.dart';
import '../models/card_model.dart';
import '../widgets/playing_card.dart';
import '../widgets/bidding_overlay.dart';
import '../widgets/deck_cut_overlay.dart';
import '../widgets/scoreboard_overlay.dart';
import '../widgets/spade_background.dart';

class GameTableScreen extends ConsumerStatefulWidget {
  const GameTableScreen({super.key});

  @override
  ConsumerState<GameTableScreen> createState() => _GameTableScreenState();
}

class _GameTableScreenState extends ConsumerState<GameTableScreen> {
  static const Color primaryBg = Color(0xFF0B2111);
  static const Color accentGold = Color(0xFFC7A14C);
  static const Color cardDark = Color(0xFF141414);

  final Map<String, GlobalKey> _playerKeys = {
    'bottom': GlobalKey(),
    'left': GlobalKey(),
    'top': GlobalKey(),
    'right': GlobalKey(),
  };

  @override
  Widget build(BuildContext context) {
    final roomCode = ref.watch(currentRoomCodeProvider);
    if (roomCode == null) return const Scaffold(body: Center(child: Text('No room code')));

    final roomAsync = ref.watch(roomMetadataProvider(roomCode));

    // Automated Dealer Transitions
    ref.listen<AsyncValue<Room?>>(roomMetadataProvider(roomCode), (previous, next) {
      next.whenData((room) {
        if (room == null) return;
        final isDealer = ref.read(isLocalPlayerDealerProvider(roomCode));
        if (!isDealer) return;

        if (room.status == 'shuffling') {
          // Auto-trigger shuffle
          ref.read(cardServiceProvider).shuffleDeck(room.id);
        } else if (room.status == 'dealing') {
          // Auto-trigger initial deal (5 cards each)
          // We need player IDs
          final players = ref.read(playersStreamProvider(room.id)).value;
          if (players != null && players.length == 4) {
             ref.read(cardServiceProvider).dealInitialFive(room.id, players.map((p) => p.id).toList());
          }
        }
      });
    });

    return Scaffold(
      body: roomAsync.when(
        data: (room) {
          if (room == null) return const Center(child: Text('Room not found'));
          final playersAsync = ref.watch(playersStreamProvider(room.id));

          return playersAsync.when(
            data: (players) {
              final localPlayerId = ref.watch(localPlayerIdProvider);
              final localIndex = players.indexWhere((p) => p.id == localPlayerId);
              if (localIndex == -1) return const Center(child: Text('You are not in this room'));

              // Rotate players so local is at bottom (index 0)
              final rotatedPlayers = List.generate(4, (i) {
                return players[(localIndex + i) % players.length];
              });

              return Stack(
                children: [
                   const SpadeBackground(),
                  // The Table
                  const Center(child: TableLayer()),
                  
                  // Player Avatars
                  _buildPlayerAvatar(rotatedPlayers[0], 'bottom', room.turnIndex == localIndex, room.dealerIndex == localIndex),
                  _buildPlayerAvatar(rotatedPlayers[1], 'left', room.turnIndex == (localIndex + 1) % 4, room.dealerIndex == (localIndex + 1) % 4),
                  _buildPlayerAvatar(rotatedPlayers[2], 'top', room.turnIndex == (localIndex + 2) % 4, room.dealerIndex == (localIndex + 2) % 4),
                  _buildPlayerAvatar(rotatedPlayers[3], 'right', room.turnIndex == (localIndex + 3) % 4, room.dealerIndex == (localIndex + 3) % 4),

                  // Cards Layer
                  CardsLayer(
                    roomId: room.id,
                    players: rotatedPlayers,
                    localPlayerId: localPlayerId!,
                    currentPhase: room.currentPhase ?? 'playing',
                    playerPositions: _playerKeys,
                  ),

                   // Overlays
                  if ((room.currentPhase == 'bidding' || room.currentPhase == 'bidding_2') && 
                      ref.watch(isLocalPlayerTurnProvider(roomCode)))
                    BiddingOverlay(
                      onBidSubmitted: (score, trump) {
                        final suitCode = trump?.toString().split('.').last[0].toUpperCase();
                        ref.read(cardServiceProvider).placeBid(room.id, localPlayerId!, score, suit: suitCode);
                      },
                      onPass: () {
                         ref.read(cardServiceProvider).placeBid(room.id, localPlayerId!, 1);
                      },
                    ),
                  
                  if ((room.currentPhase == 'bidding' || room.currentPhase == 'bidding_2') && 
                      !ref.watch(isLocalPlayerTurnProvider(roomCode)))
                    const Align(
                      alignment: Alignment.bottomCenter,
                      child: Padding(
                        padding: EdgeInsets.only(bottom: 100),
                        child: Text('Waiting for other players to bid...', 
                          style: TextStyle(color: Colors.white54, fontStyle: FontStyle.italic)),
                      ),
                    ),
                  
                  if (room.currentPhase == 'cutting')
                    const DeckCutOverlay(),

                  // Scoreboard Trigger
                  Positioned(
                    top: 40,
                    right: 20,
                    child: IconButton(
                      icon: const Icon(Icons.leaderboard, color: _GameTableScreenState.accentGold, size: 32),
                      onPressed: () => showDialog(
                        context: context,
                        builder: (context) => ScoreboardOverlay(roomId: room.id),
                      ),
                    ),
                  ),
                  if (room.status == 'game_over')
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(32),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: _GameTableScreenState.accentGold, width: 2),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('GAME OVER', style: TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: _GameTableScreenState.accentGold)),
                            const SizedBox(height: 20),
                            ...players.map((p) => Text('${p.name}: ${p.totalScore}', style: const TextStyle(color: Colors.white, fontSize: 24))),
                            const SizedBox(height: 30),
                            ElevatedButton(
                              onPressed: () {
                                LocalStorageSync.reset();
                                Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
                              },
                              child: const Text('RESTART MOCK'),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // TRUMP HUD
                  if (room.trumpSuit != null)
                    Positioned(
                      top: 40,
                      left: 20,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.7),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: _GameTableScreenState.accentGold.withOpacity(0.5), width: 1),
                          boxShadow: [BoxShadow(color: Colors.black54, blurRadius: 10)],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('TRUMP: ', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
                            Text(_getSuitEmojiStatic(room.trumpSuit!), style: const TextStyle(fontSize: 24)),
                          ],
                        ),
                      ),
                    ),
                ],
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, s) => Center(child: Text('Error: $e')),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => Center(child: Text('Error: $e')),
      ),
    );
  }

  Widget _buildPlayerAvatar(Player player, String position, bool isActive, bool isDealer) {
    Alignment alignment;
    double? top, bottom, left, right;

    switch (position) {
      case 'bottom': alignment = Alignment.bottomCenter; bottom = 20; break;
      case 'left': alignment = Alignment.centerLeft; left = 20; break;
      case 'top': alignment = Alignment.topCenter; top = 40; break;
      case 'right': alignment = Alignment.centerRight; right = 20; break;
      default: alignment = Alignment.center;
    }

    return Align(
      alignment: alignment,
      child: Padding(
        padding: EdgeInsets.only(
          top: top ?? 0, bottom: bottom ?? 0, left: left ?? 0, right: right ?? 0
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                // Animated Outer Ring for active player
                if (isActive)
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.0, end: 1.0),
                    duration: const Duration(seconds: 2),
                    builder: (context, value, child) {
                      return Container(
                        width: 86,
                        height: 86,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: accentGold.withOpacity(0.5 + 0.5 * math.sin(value * math.pi * 2)),
                            width: 2,
                          ),
                        ),
                      );
                    },
                    onEnd: () {}, // Handled by repeating logic if needed, but simple glow is fine
                  ),
                Container(
                  key: _playerKeys[position],
                  width: 80,
                  height: 80,
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.black45,
                    border: Border.all(
                      color: isActive ? accentGold : Colors.white10,
                      width: 1.5,
                    ),
                    boxShadow: isActive ? [
                      BoxShadow(color: accentGold.withOpacity(0.3), blurRadius: 15, spreadRadius: 2)
                    ] : [],
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isActive ? accentGold.withOpacity(0.1) : Colors.white.withOpacity(0.05),
                    ),
                    child: Center(
                      child: Text(
                        player.name[0].toUpperCase(),
                        style: TextStyle(
                          fontSize: 28, 
                          fontWeight: FontWeight.w900, 
                          color: isActive ? accentGold : Colors.white70,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ),
                  ),
                ),
                if (isDealer)
                  Positioned(
                    right: -2,
                    bottom: -2,
                    child: Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle, 
                        color: accentGold,
                        border: Border.all(color: primaryBg, width: 2),
                        boxShadow: [BoxShadow(color: Colors.black54, blurRadius: 4)],
                      ),
                      child: const Center(
                        child: Text('D', style: TextStyle(color: primaryBg, fontWeight: FontWeight.bold, fontSize: 13)),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white10, width: 0.5),
              ),
              child: Column(
                children: [
                   Text(
                    player.name,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: isActive ? accentGold : Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Score: ${player.totalScore}',
                    style: const TextStyle(color: Colors.white38, fontSize: 11),
                  ),
                ],
              ),
            ),
            if (player.bid != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: accentGold.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: accentGold.withOpacity(0.3), width: 0.5),
                  ),
                  child: Text(
                    'Bid: ${player.bid} | Won: ${player.tricksWon}',
                    style: const TextStyle(color: accentGold, fontSize: 10, fontWeight: FontWeight.w800),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class TableLayer extends StatelessWidget {
  const TableLayer({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: math.min(MediaQuery.of(context).size.width * 0.8, 600),
      height: math.min(MediaQuery.of(context).size.width * 0.8, 600),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFF0F3018), // Table felt
        border: Border.all(color: const Color(0xFF0B2111), width: 12),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.6), blurRadius: 40, spreadRadius: 5),
          BoxShadow(color: _GameTableScreenState.accentGold.withOpacity(0.1), blurRadius: 10, spreadRadius: 0),
        ],
      ),
      child: Center(
        child: Consumer(builder: (context, ref, _) {
          final roomCode = ref.watch(currentRoomCodeProvider);
          final room = roomCode != null ? ref.watch(roomMetadataProvider(roomCode)).value : null;
          final players = room != null ? ref.watch(playersStreamProvider(room.id)).value : null;
          final localId = ref.watch(localPlayerIdProvider);

          if (room == null || players == null || localId == null) return const SizedBox();

          final localIndex = players.indexWhere((p) => p.id == localId);
          final playerTurnIndexInRotated = (room.turnIndex - localIndex + 4) % 4;
          
          Alignment alignment;
          switch (playerTurnIndexInRotated) {
             case 0: alignment = Alignment.bottomCenter; break;
             case 1: alignment = Alignment.centerLeft; break;
             case 2: alignment = Alignment.topCenter; break;
             case 3: alignment = Alignment.centerRight; break;
             default: alignment = Alignment.center;
          }

          return AnimatedAlign(
            duration: const Duration(milliseconds: 500),
            alignment: alignment,
            child: Container(
              width: 150, height: 150,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [_GameTableScreenState.accentGold.withOpacity(0.2), Colors.transparent],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

String _getSuitEmojiStatic(String code) {
  switch (code) {
    case 'S': return '♠️';
    case 'H': return '♥️';
    case 'D': return '♦️';
    case 'C': return '♣️';
    default: return '';
  }
}

class CardsLayer extends ConsumerWidget {
  final String roomId;
  final List<Player> players;
  final String localPlayerId;
  final String currentPhase;
  final Map<String, GlobalKey> playerPositions;

  const CardsLayer({
    super.key,
    required this.roomId,
    required this.players,
    required this.localPlayerId,
    required this.currentPhase,
    required this.playerPositions,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playedCardsAsync = ref.watch(playedCardsProvider(roomId));
    final roomCode = ref.watch(currentRoomCodeProvider);
    final room = roomCode != null ? ref.watch(roomMetadataProvider(roomCode)).value : null;

    return playedCardsAsync.when(
      data: (playedMaps) {
        // 1. Identify current trick (last 1-4 cards)
        final trickSize = playedMaps.length % 4;
        final trickStartIndex = playedMaps.length - (trickSize == 0 && playedMaps.isNotEmpty ? 4 : trickSize);
        if (trickStartIndex < 0) return const SizedBox();
        
        final currentTrick = playedMaps.sublist(trickStartIndex);

        return Stack(
          children: [
            // Cards in Hand
            ..._buildPlayerHands(ref),
            
            // Cards on Table
            ...currentTrick.map((m) {
              final player = players.cast<Player?>().firstWhere((p) => p?.id == m['player_id'], orElse: () => null);
              if (player == null) return const SizedBox();
              
              final playerIdxInRotated = players.indexOf(player);
              final pos = _getPositionFromIndex(playerIdxInRotated);
              
              return PlayedCardWidget(
                card: CardModel.fromId(m['card_value']),
                position: pos,
                order: currentTrick.indexOf(m),
              );
            }),
          ],
        );
      },
      loading: () => const SizedBox(),
      error: (e, s) => const SizedBox(),
    );
  }

  String _getPositionFromIndex(int index) {
    switch (index) {
      case 0: return 'bottom';
      case 1: return 'left';
      case 2: return 'top';
      case 3: return 'right';
      default: return 'bottom';
    }
  }

  List<Widget> _buildPlayerHands(WidgetRef ref) {
    final localHandAsync = ref.watch(playerHandProvider(localPlayerId));
    final playableIds = ref.watch(playableCardsProvider(roomId));

    List<Widget> handWidgets = [];

    // Local Player Hand (Bottom)
    localHandAsync.whenData((hand) {
      for (var i = 0; i < hand.length; i++) {
        final cardId = hand[i]['card_value'] as String;
        final isPlayable = playableIds.contains(cardId);
        
        handWidgets.add(
          HandCardWidget(
            card: CardModel.fromId(cardId),
            index: i,
            total: hand.length,
            isPlayable: isPlayable,
            onTap: isPlayable ? () => ref.read(cardServiceProvider).playCard(roomId, localPlayerId, cardId) : null,
          ),
        );
      }
    });

    // Opponent Hands (Face Down)
    for (var i = 1; i < 4; i++) {
      final p = players[i];
      final pos = _getPositionFromIndex(i);
      final pHandAsync = ref.watch(playerHandProvider(p.id));
      
      pHandAsync.whenData((hand) {
        for (var j = 0; j < hand.length; j++) {
          handWidgets.add(OpponentCardWidget(position: pos, index: j, total: hand.length));
        }
      });
    }

    return handWidgets;
  }
}

class HandCardWidget extends StatelessWidget {
  final CardModel card;
  final int index;
  final int total;
  final bool isPlayable;
  final VoidCallback? onTap;

  const HandCardWidget({
    super.key,
    required this.card,
    required this.index,
    required this.total,
    required this.isPlayable,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final fanOffset = (index - (total - 1) / 2) * 30.0;
    final rotation = (index - (total - 1) / 2) * 0.1;

    return AnimatedAlign(
      duration: const Duration(milliseconds: 500),
      alignment: Alignment.bottomCenter,
      child: Transform.translate(
        offset: Offset(fanOffset, -110),
        child: Transform.rotate(
          angle: rotation,
          child: GestureDetector(
            onTap: onTap,
            child: Opacity(
              opacity: isPlayable ? 1.0 : 0.6,
              child: PlayingCard(
                card: card,
                isFaceUp: true,
                isPlayable: isPlayable,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class OpponentCardWidget extends StatelessWidget {
  final String position;
  final int index;
  final int total;

  const OpponentCardWidget({
    super.key,
    required this.position,
    required this.index,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    final fanOffset = (index - (total - 1) / 2) * 10.0;
    final rotation = (index - (total - 1) / 2) * 0.05;

    Alignment alignment;
    double? top, bottom, left, right;
    double? angle;

    switch (position) {
      case 'left':
        alignment = Alignment.centerLeft;
        left = 100;
        top = fanOffset;
        angle = math.pi / 2 + rotation;
        break;
      case 'top':
        alignment = Alignment.topCenter;
        top = 110;
        left = fanOffset;
        angle = math.pi + rotation;
        break;
      case 'right':
        alignment = Alignment.centerRight;
        right = 100;
        bottom = fanOffset;
        angle = -math.pi / 2 + rotation;
        break;
      default:
        alignment = Alignment.center;
    }

    return Align(
      alignment: alignment,
      child: Transform.translate(
        offset: Offset(
          (position == 'left' ? 100 : (position == 'right' ? -100 : fanOffset)),
          (position == 'top' ? 110 : (position == 'left' ? fanOffset : (position == 'right' ? -fanOffset : 0))),
        ),
        child: Transform.rotate(
          angle: angle ?? 0,
          child: const PlayingCard(isFaceUp: false),
        ),
      ),
    );
  }
}

class PlayedCardWidget extends StatelessWidget {
  final CardModel card;
  final String position;
  final int order;

  const PlayedCardWidget({
    super.key,
    required this.card,
    required this.position,
    required this.order,
  });

  @override
  Widget build(BuildContext context) {
    double offsetX = 0;
    double offsetY = 0;
    double rotation = 0;

    switch (position) {
      case 'bottom': offsetY = 60; rotation = 0; break;
      case 'left': offsetX = -60; rotation = math.pi / 2; break;
      case 'top': offsetY = -60; rotation = math.pi; break;
      case 'right': offsetX = 60; rotation = -math.pi / 2; break;
    }

    return Center(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: 1.0),
        duration: const Duration(milliseconds: 300),
        builder: (context, value, child) {
          return Transform.translate(
            offset: Offset(offsetX * value, offsetY * value),
            child: Transform.rotate(
              angle: rotation + (order * 0.1),
              child: PlayingCard(card: card, isFaceUp: true),
            ),
          );
        },
      ),
    );
  }
}
