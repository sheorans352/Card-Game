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
import '../services/audio_service.dart';

class GameTableScreen extends ConsumerStatefulWidget {
  const GameTableScreen({super.key});

  @override
  ConsumerState<GameTableScreen> createState() => _GameTableScreenState();
}

class _GameTableScreenState extends ConsumerState<GameTableScreen> {
  static const Color primaryBg = Color(0xFF062A14); // Deeper green
  static const Color accentGold = Color(0xFFC7A14C);
  static const Color cardDark = Color(0xFF141414);
  static const Color playerGreen = Color(0xFF2E7D32);
  static const Color playerBlue = Color(0xFF1565C0);
  static const Color playerRed = Color(0xFFC62828);
  static const Color playerGold = Color(0xFFBF8F00);

  final Map<String, GlobalKey> _playerKeys = {
    'bottom': GlobalKey(),
    'left': GlobalKey(),
    'top': GlobalKey(),
    'right': GlobalKey(),
  };

  bool _showScoreboard = false;

  @override
  Widget build(BuildContext context) {
    final roomCode = ref.watch(currentRoomCodeProvider);
    if (roomCode == null) return const Scaffold(body: Center(child: Text('No room code')));

    final roomAsync = ref.watch(roomMetadataProvider(roomCode));

    // Automated Dealer Transitions
    ref.listen<AsyncValue<Room?>>(roomMetadataProvider(roomCode), (previous, next) {
      next.whenData((room) {
        if (room == null) return;
        
        final players = ref.read(playersStreamProvider(room.id)).value;
        if (players == null || players.length < 4) return;
        
        final localId = ref.read(localPlayerIdProvider);
        final dealerIndexInList = room.dealerIndex % players.length;
        final isDealer = players[dealerIndexInList].id == localId;
        
        if (!isDealer) return;

        print('DEBUG: Dealer detecting state change: ${room.status}');

        try {
          if (room.status == 'shuffling') {
            gameAudio.playShuffle();
            ref.read(cardServiceProvider).shuffleDeck(room.id);
          } else if (room.status == 'dealing') {
             print('DEBUG: Dealer triggering initial deal for room: ${room.id}');
             ref.read(cardServiceProvider).dealInitialFive(room.id, players.map((p) => p.id).toList());
          }
        } catch (e) {
          print('DEBUG: Error in dealer automation: $e');
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
                  // Top HUD: Scores & Status
                  _buildTopHUD(players, room),

                  // Player Avatars (Figma Style)
                  _buildPlayerAvatar(rotatedPlayers[0], 'bottom', room.turnIndex == localIndex, room.dealerIndex == localIndex, playerGreen),
                  _buildPlayerAvatar(rotatedPlayers[1], 'left', room.turnIndex == (localIndex + 1) % 4, room.dealerIndex == (localIndex + 1) % 4, playerBlue),
                  _buildPlayerAvatar(rotatedPlayers[2], 'top', room.turnIndex == (localIndex + 2) % 4, room.dealerIndex == (localIndex + 2) % 4, playerRed),
                  _buildPlayerAvatar(rotatedPlayers[3], 'right', room.turnIndex == (localIndex + 3) % 4, room.dealerIndex == (localIndex + 3) % 4, playerGold),

                  // Cards Layer
                  CardsLayer(
                    roomId: room.id,
                    players: rotatedPlayers,
                    localPlayerId: localPlayerId!,
                    currentPhase: room.currentPhase ?? 'playing',
                    playerPositions: _playerKeys,
                  ),

                    // Overlays (Bidding & Trump Selection)
                   if ((room.currentPhase == 'bidding' || room.currentPhase == 'bidding_2' || room.currentPhase == 'trump_selection') && 
                       ref.watch(isLocalPlayerTurnProvider(room.code)))
                     BiddingOverlay(
                       currentHighBid: room.highestBid,
                       isTrumpSelection: room.currentPhase == 'trump_selection',
                       onBidSubmitted: (score) => ref.read(cardServiceProvider).placeBid(room.id, localPlayerId!, score),
                       onTrumpSelected: (suit) => ref.read(cardServiceProvider).selectTrump(room.id, localPlayerId!, suit.name.toUpperCase().substring(0, 1)),
                       onPass: () => ref.read(cardServiceProvider).placeBid(room.id, localPlayerId!, 0),
                     ),
                   
                   if ((room.currentPhase == 'bidding' || room.currentPhase == 'bidding_2' || room.currentPhase == 'trump_selection') && 
                       !ref.watch(isLocalPlayerTurnProvider(room.code)))
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

                  // Bottom Tricks HUD
                  _buildBottomTricksHUD(players, localIndex, room),

                  // TRUMP HUD (Floating bottom left)
                  if (room.trumpSuit != null)
                    _buildTrumpHUD(room.trumpSuit!, room),

                  // Scoreboard Button (Top Right)
                  Positioned(
                    top: MediaQuery.of(context).padding.top + 10,
                    right: 20,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black38,
                        shape: BoxShape.circle,
                        border: Border.all(color: accentGold.withOpacity(0.5)),
                      ),
                      child: IconButton(
                        onPressed: () => setState(() => _showScoreboard = true),
                        icon: const Icon(Icons.leaderboard_rounded, color: accentGold, size: 28),
                        tooltip: 'Scoreboard',
                      ),
                    ),
                  ),

                  // Scoreboard Overlay
                  if (_showScoreboard)
                    Positioned.fill(
                      child: GestureDetector(
                        onTap: () => setState(() => _showScoreboard = false),
                        child: Container(
                          color: Colors.black87,
                          padding: const EdgeInsets.only(top: 80),
                          child: ScoreboardOverlay(
                            roomId: room.id,
                            players: players,
                            onClose: () => setState(() => _showScoreboard = false),
                          ),
                        ),
                      ),
                    ),

                  if (room.status == 'game_over')
                    _buildGameOverOverlay(context),
                ],
              );
            },
            loading: () => const Center(child: CircularProgressIndicator(color: accentGold)),
            error: (err, stack) => _ErrorView(
              message: 'Players sync lost',
              onRetry: () => ref.refresh(playersStreamProvider(room.id)),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator(color: accentGold)),
        error: (err, stack) => _ErrorView(
          message: 'Connection timed out',
          onRetry: () => ref.refresh(roomMetadataProvider(roomCode)),
        ),
      ),
    );
  }

  // Duplicate removed

  Widget _buildGameOverOverlay(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.9),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: accentGold, width: 2),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('GAME OVER', style: TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: accentGold)),
            const SizedBox(height: 16),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: accentGold, 
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              ),
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('BACK TO LOBBY', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopHUD(List<Player> players, Room room) {
    return Positioned(
      top: 0, left: 0, right: 0,
      child: Container(
        height: 60,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.black.withOpacity(0.8), Colors.transparent],
          ),
        ),
        child: Row(
          children: [
            if (room.trumpSuit != null) ...[
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.white10, shape: BoxShape.circle),
                child: Text(_getSuitEmojiStatic(room.trumpSuit!), style: const TextStyle(fontSize: 18)),
              ),
              const SizedBox(width: 10),
              Text('Trump: ${_getSuitName(room.trumpSuit!)}', style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold)),
            ],
            const Spacer(),
            Text('ROUND ${room.currentRound ?? 1} — TRICK ${(playedCardsCount(room) ~/ 4) + 1}', 
              style: const TextStyle(color: accentGold, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
            const Spacer(),
            // Miniature Player Scores
            ...players.map((p) => Padding(
              padding: const EdgeInsets.only(left: 12),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(p.name.substring(0, 2).toUpperCase(), style: const TextStyle(color: Colors.white38, fontSize: 9, fontWeight: FontWeight.bold)),
                  Text('${p.totalScore}', style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900)),
                ],
              ),
            )),
          ],
        ),
      ),
    );
  }

  int playedCardsCount(Room room) {
    // We can't easily access the stream provider results here synchronously 
    // without a separate state, but we can assume from the turnIndex and deck status
    // Or we just use a placeholder text as seen in Figma and refine later.
    return 14; // Placeholder reflecting Figma's 'Trick 4' value (Trick 4 = 12+2 cards)
  }

  String _getSuitName(String suit) {
    switch (suit) {
      case 'S': return 'Spades';
      case 'H': return 'Hearts';
      case 'D': return 'Diamonds';
      case 'C': return 'Clubs';
      default: return '';
    }
  }

  Widget _buildBottomTricksHUD(List<Player> players, int localIndex, Room room) {
    final rotated = List.generate(4, (i) => players[(localIndex + i) % 4]);
    return Positioned(
      bottom: 0, left: 0, right: 0,
      child: Container(
        height: 80,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.9),
          border: Border(top: BorderSide(color: Colors.white10, width: 0.5)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: rotated.map((p) {
            final isLocal = rotated.indexOf(p) == 0;
            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(isLocal ? 'You' : p.name.split(' ').first, style: TextStyle(color: isLocal ? accentGold : Colors.white30, fontSize: 11)),
                const SizedBox(height: 4),
                RichText(text: TextSpan(
                  children: [
                    TextSpan(text: '${p.tricksWon}', style: TextStyle(color: isLocal ? accentGold : Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
                    TextSpan(text: ' / ${p.bid ?? "?"}', style: const TextStyle(color: Colors.white38, fontSize: 14)),
                  ]
                )),
                const Text('tricks', style: TextStyle(color: Colors.white24, fontSize: 9)),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildTrumpHUD(String suit, Room room) {
    return Positioned(
      bottom: 90,
      left: 20,
      child: Row(
        children: [
          Text(_getSuitEmojiStatic(suit), style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 8),
          Text('Trump Suit: ${_getSuitName(suit)}', style: const TextStyle(color: accentGold, fontSize: 12, fontWeight: FontWeight.bold)),
          const SizedBox(width: 8),
          const Text('•', style: TextStyle(color: Colors.white24)),
          const SizedBox(width: 8),
          Text('Round ${room.currentRound}  •  Trick ${(room.currentRound ?? 1)} of 13', 
            style: const TextStyle(color: Colors.white38, fontSize: 11)), // Refined below
        ],
      )
    );
  }

  Widget _buildPlayerAvatar(Player player, String position, bool isTurn, bool isDealer, Color color) {
    Alignment alignment;
    double? top, bottom, left, right;

    switch (position) {
      case 'bottom': alignment = Alignment.bottomCenter; bottom = 100; break;
      case 'left': alignment = Alignment.centerLeft; left = 20; break;
      case 'top': alignment = Alignment.topCenter; top = 80; break;
      case 'right': alignment = Alignment.centerRight; right = 20; break;
      default: alignment = Alignment.center;
    }

    return Align(
      alignment: alignment,
      child: Padding(
        padding: EdgeInsets.only(
          top: top ?? 0, bottom: bottom ?? 0, left: left ?? 0, right: right ?? 0,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isTurn && position == 'bottom')
               _buildYourTurnBadge(),
            const SizedBox(height: 8),
            Stack(
              clipBehavior: Clip.none,
              children: [
                // Avatar Circle
                Container(
                  width: 70, height: 70,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color.withOpacity(0.2),
                    border: Border.all(
                      color: isTurn ? accentGold : Colors.white10,
                      width: isTurn ? 3 : 1,
                    ),
                    boxShadow: [
                      if (isTurn) BoxShadow(color: accentGold.withOpacity(0.4), blurRadius: 15, spreadRadius: 2),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      player.name.substring(0, 2).toUpperCase(),
                      style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900),
                    ),
                  ),
                ),

                // Dealer Badge (Matches Figma top right of avatar)
                if (isDealer)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      width: 22, height: 22,
                      decoration: BoxDecoration(color: Color(0xFFE5B84B), shape: BoxShape.circle, border: Border.all(color: Colors.black, width: 1.5)),
                      child: const Center(child: Text('D', style: TextStyle(color: Colors.black, fontSize: 11, fontWeight: FontWeight.w900))),
                    ),
                  ),
                
                if (isTurn)
                  Positioned.fill(
                    child: CustomPaint(painter: _TurnTimerPainter(angle: 0.8)), // Placeholder
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Text(player.name, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
            if (player.bid != null && position != 'bottom') 
               Container(
                 margin: const EdgeInsets.only(top: 4),
                 padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                 decoration: BoxDecoration(color: Colors.black45, borderRadius: BorderRadius.circular(10)),
                 child: Text('${player.tricksWon}/${player.bid}', style: const TextStyle(color: accentGold, fontSize: 10, fontWeight: FontWeight.w900)),
               ),
          ],
        ),
      ),
    );
  }

  Widget _buildYourTurnBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Color(0xFFE5B84B),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black54, blurRadius: 10)],
      ),
      child: const Text('YOUR TURN', style: TextStyle(color: Colors.black, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1)),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(24),
        margin: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFF0B2111),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.redAccent.withOpacity(0.5)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off, color: Colors.redAccent, size: 48),
            const SizedBox(height: 16),
            Text(message, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 8),
            const Text('The Realtime connection was interrupted.', 
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70)),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              icon: const Icon(Icons.refresh),
              label: const Text('RECONNECT NOW'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFC7A14C),
                foregroundColor: Colors.black,
              ),
              onPressed: onRetry,
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
      width: math.min(MediaQuery.of(context).size.width * 0.85, 650),
      height: math.min(MediaQuery.of(context).size.width * 0.85, 650),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            const Color(0xFF1B5E20), // Lighter green center
            const Color(0xFF144525), 
            const Color(0xFF0B2111), // Dark edge
          ],
          stops: const [0.0, 0.4, 1.0],
        ),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.8), blurRadius: 60, spreadRadius: 10),
          BoxShadow(color: const Color(0xFFC7A14C).withOpacity(0.15), blurRadius: 30, spreadRadius: 2),
        ],
        border: Border.all(
          color: const Color(0xFFC7A14C).withOpacity(0.8), 
          width: 8,
          strokeAlign: BorderSide.strokeAlignOutside,
        ),
      ),
      child: Stack(
        children: [
          // Detailed Felt Texture
          Positioned.fill(
            child: ClipOval(
              child: Opacity(
                opacity: 0.15,
                child: Image.network(
                  'https://www.transparenttextures.com/patterns/felt.png',
                  repeat: ImageRepeat.repeat,
                  color: Colors.black,
                  errorBuilder: (context, error, stackTrace) => const SizedBox(),
                ),
              ),
            ),
          ),
          
          // Outer Gold Ring (Decorative)
          Positioned.fill(
            child: Container(
              margin: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFC7A14C).withOpacity(0.3), width: 1),
              ),
            ),
          ),

          Center(
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
                duration: const Duration(milliseconds: 600),
                curve: Curves.easeInOutBack,
                alignment: alignment,
                child: Container(
                  width: 160, height: 160,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [const Color(0xFFC7A14C).withOpacity(0.3), Colors.transparent],
                      stops: const [0.4, 1.0],
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
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

    return playedCardsAsync.when(
      data: (playedMaps) {
        final trickSize = playedMaps.length % 4;
        final trickStartIndex = playedMaps.length - (trickSize == 0 && playedMaps.isNotEmpty ? 4 : trickSize);
        if (trickStartIndex < 0) return const SizedBox();
        final currentTrick = playedMaps.sublist(trickStartIndex);

        return Stack(
          children: [
            ..._buildPlayerHands(ref),
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
            onTap: isPlayable ? () {
              gameAudio.playCardPlay();
              ref.read(cardServiceProvider).playCard(roomId, localPlayerId, cardId);
            } : () {
              gameAudio.playInvalidMove();
            },
          ),
        );
      }
    });

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
    // Listen for new cards in local hand for dealing SFX
    ref.listen(playerHandProvider(localPlayerId), (prev, next) {
      next.whenData((hand) {
        final prevLen = prev?.value?.length ?? 0;
        final nextLen = hand.length;
        if (nextLen > prevLen) {
          final addedCount = nextLen - prevLen;
          for (int i = 0; i < addedCount; i++) {
            Future.delayed(Duration(milliseconds: i * 150), () {
              gameAudio.playCardDeal();
            });
          }
        }
      });
    });

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

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 600 + (index * 100)),
      curve: Curves.easeOutBack,
      builder: (context, value, child) {
        return Align(
          alignment: Alignment.bottomCenter,
          child: Transform.translate(
            offset: Offset(fanOffset * value, -110 - (1 - value) * 400),
            child: Transform.rotate(
              angle: rotation * value,
              child: Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: [
                  GestureDetector(
                    onTap: onTap,
                    child: Opacity(
                      opacity: isPlayable ? 1.0 : 0.6,
                      child: PlayingCard(
                        card: card,
                        isFaceUp: true,
                        isPlayable: isPlayable,
                        width: 70, 
                        height: 105,
                      ),
                    ),
                  ),
                  if (isPlayable)
                    Positioned(
                      bottom: -10,
                      child: Container(
                        width: 10, height: 10,
                        decoration: const BoxDecoration(
                          color: Color(0xFFE5B84B), 
                          shape: BoxShape.circle,
                          boxShadow: [BoxShadow(color: Colors.amber, blurRadius: 4)],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
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
      case 'left': alignment = Alignment.centerLeft; left = 100; top = fanOffset; angle = math.pi / 2 + rotation; break;
      case 'top': alignment = Alignment.topCenter; top = 110; left = fanOffset; angle = math.pi + rotation; break;
      case 'right': alignment = Alignment.centerRight; right = 100; bottom = fanOffset; angle = -math.pi / 2 + rotation; break;
      default: alignment = Alignment.center;
    }

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 500 + (index * 80)),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        double offX = 0, offY = 0;
        switch (position) {
          case 'left': offX = 140; offY = fanOffset; break;
          case 'top': offX = fanOffset; offY = 140; break;
          case 'right': offX = -140; offY = -fanOffset; break;
        }

        return Align(
          alignment: alignment,
          child: Transform.translate(
            offset: Offset(offX * value, offY * value),
            child: Transform.rotate(
              angle: (angle ?? 0) * value,
              child: const PlayingCard(isFaceUp: false, width: 50, height: 75),
            ),
          ),
        );
      },
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

class _TurnTimerPainter extends CustomPainter {
  final double angle;
  _TurnTimerPainter({required this.angle});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFE5B84B).withOpacity(0.8)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    canvas.drawArc(rect, -1.57, angle * 6.28, false, paint);
  }

  @override
  bool shouldRepaint(covariant _TurnTimerPainter oldDelegate) => oldDelegate.angle != angle;
}
