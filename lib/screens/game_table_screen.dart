import 'dart:math' as math;
import 'dart:async';
import 'dart:ui';
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

const Color primaryBg = Color(0xFF0A1A2F); // Deep Navy Black from Mock
const Color tableFelt = Color(0xFF0D1B2A);
const Color accentGold = Color(0xFFE5B84B); // Premium Gold
const Color playerCardBg = Color(0xFF101E33); // Inactive player card
const Color activeCardBg = Color(0xFF1A2F4A); // Active/YOU card border
const Color boxGreen = Color(0xFF4CAF50);
const Color boxRed = Color(0xFFEF5350);
const Color tableBorder = Color(0xFF1E2833);

class GameTableScreen extends ConsumerStatefulWidget {
  const GameTableScreen({super.key});

  @override
  ConsumerState<GameTableScreen> createState() => _GameTableScreenState();
}

class _GameTableScreenState extends ConsumerState<GameTableScreen> {
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

        try {
          final prevRoom = previous?.value;
          final justEnteredShuffling = room.status == 'shuffling' && prevRoom?.status != 'shuffling';
          
          if (justEnteredShuffling && room.deckCutValue == null) {
            gameAudio.playShuffle();
            ref.read(cardServiceProvider).shuffleDeck(room.id);
          }
        } catch (e) {
          debugPrint('DEBUG: Error in dealer automation: $e');
        }
      });
    });

    // Auto-show scoreboard and force clear table on round transition
    ref.listen<int?>(
      roomMetadataProvider(roomCode).select((data) => data.value?.currentRound),
      (prev, next) {
        if (next != null && prev != null && next > prev) {
          setState(() => _showScoreboard = true);
          ref.read(localPlayedCardsProvider.notifier).state = {};
          debugPrint('Round transitioned: $prev -> $next. Resetting table and showing scoreboard.');
        }
      },
    );

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

              final predictivePlayedCards = ref.watch(predictivePlayedCardsProvider(room.id));
              final playedCardsCount = predictivePlayedCards.length;

              final rotatedPlayers = List.generate(4, (i) {
                return players[(localIndex + i) % players.length];
              });

              return Stack(
                children: [
                   Container(
                     decoration: const BoxDecoration(
                       gradient: LinearGradient(
                         begin: Alignment.topCenter,
                         end: Alignment.bottomCenter,
                         colors: [
                           Color(0xFF081221), // Top Darkest
                           Color(0xFF02070D), // Bottom Almost Black
                         ],
                       ),
                     ),
                   ),
                   const SpadeBackground(),
                  _buildTopHUD(players, room, playedCardsCount),

                  _buildPlayerAvatar(rotatedPlayers[0], 'bottom', ref.watch(predictiveTurnIdProvider(room.id)) == rotatedPlayers[0].id, room.dealerIndex == (players.indexOf(rotatedPlayers[0])), Colors.green),
                  _buildPlayerAvatar(rotatedPlayers[1], 'left', ref.watch(predictiveTurnIdProvider(room.id)) == rotatedPlayers[1].id, room.dealerIndex == (players.indexOf(rotatedPlayers[1])), Colors.blue),
                  _buildPlayerAvatar(rotatedPlayers[2], 'top', ref.watch(predictiveTurnIdProvider(room.id)) == rotatedPlayers[2].id, room.dealerIndex == (players.indexOf(rotatedPlayers[2])), Colors.red),
                  _buildPlayerAvatar(rotatedPlayers[3], 'right', ref.watch(predictiveTurnIdProvider(room.id)) == rotatedPlayers[3].id, room.dealerIndex == (players.indexOf(rotatedPlayers[3])), Colors.amber),

                  CardsLayer(
                    roomId: room.id,
                    players: rotatedPlayers,
                    localPlayerId: localPlayerId!,
                    currentPhase: room.currentPhase ?? 'playing',
                    playerPositions: _playerKeys,
                  ),

                  _buildBottomTricksHUD(players, localIndex, room),
                  
                  if (room.trumpSuit != null)
                    _buildBottomBar(room.trumpSuit!, room, playedCardsCount),

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

                  if ((room.currentPhase == 'bidding' || room.currentPhase == 'bidding_2' || room.currentPhase == 'trump_selection') && 
                      ref.watch(isLocalPlayerTurnProvider(room.code)))
                    BiddingOverlay(
                      isRoundTwo: room.currentPhase == 'bidding_2',
                      currentHighBid: room.highestBid,
                      trumpSuit: room.trumpSuit ?? 'S',
                      isTrumpSelection: room.currentPhase == 'trump_selection',
                      isScenarioB: room.currentPhase == 'bidding_2' && room.highestBidderId == null,
                      onBidSubmitted: (score) => ref.read(cardServiceProvider).placeBid(room.id, localPlayerId, score),
                      onTrumpSelected: (suit) => ref.read(cardServiceProvider).selectTrump(room.id, localPlayerId, suit.name.toUpperCase().substring(0, 1)),
                      onPass: () => ref.read(cardServiceProvider).placeBid(room.id, localPlayerId, 0),
                    ),

                  if (room.currentPhase == 'bidding_2' && room.highestBidderId == localPlayerId)
                    _buildTrumpSetterWaitingScreen(players, room),

                  if ((room.currentPhase == 'bidding' || room.currentPhase == 'trump_selection') && 
                      !ref.watch(isLocalPlayerTurnProvider(room.code)) &&
                      room.highestBidderId != localPlayerId)
                   Align(
                     alignment: Alignment.bottomCenter,
                     child: Padding(
                       padding: const EdgeInsets.only(bottom: 100),
                       child: Text(
                         room.currentPhase == 'trump_selection'
                           ? 'Waiting for winner to set trump...'
                           : 'Waiting for others to bid...',
                         style: const TextStyle(color: Colors.white54, fontStyle: FontStyle.italic)),
                     ),
                   ),

                  if (room.currentPhase == 'bidding_2' &&
                      room.highestBidderId != localPlayerId &&
                      !ref.watch(isLocalPlayerTurnProvider(room.code)))
                    _buildBidding2WaitingText(players, room),

                  if (room.currentPhase == 'cutting')
                    const DeckCutOverlay(),

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

  Widget _buildTopHUD(List<Player> players, Room room, int playedCardsCount) {
    return Positioned(
      top: 0, left: 0, right: 0,
      child: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            height: 64,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.black.withOpacity(0.8), Colors.black.withOpacity(0.5)],
              ),
              border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.1), width: 0.5)),
            ),
            child: Row(
              children: [
                if (room.trumpSuit != null) ...[
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.08), 
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Text(_getSuitEmojiStatic(room.trumpSuit!), style: const TextStyle(fontSize: 20)),
                  ),
                  const SizedBox(width: 14),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _getSuitName(room.trumpSuit!).toUpperCase(), 
                        style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 1)
                      ),
                      const Text('TRUMP SUIT', style: TextStyle(color: Colors.white24, fontSize: 8, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ],
                const Spacer(),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('ROUND ${room.currentRound ?? 1}', 
                      style: const TextStyle(color: Colors.white38, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                    Text('TRICK ${(playedCardsCount ~/ 4) + 1} / 13', 
                      style: const TextStyle(color: accentGold, fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 1)),
                  ],
                ),
                const Spacer(),
                // Miniature Player Scores
                ...players.map((p) {
                   final isLeader = players.every((other) => p.totalScore >= other.totalScore);
                   return Padding(
                    padding: const EdgeInsets.only(left: 16),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(p.name.substring(0, 2).toUpperCase(), 
                          style: TextStyle(color: isLeader ? accentGold : Colors.white24, fontSize: 9, fontWeight: FontWeight.bold)),
                        Text('${p.totalScore}', 
                          style: TextStyle(color: isLeader ? accentGold : Colors.white, fontSize: 15, fontWeight: FontWeight.w900)),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        ),
      ),
    );
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

  /// Full waiting screen shown to the trump setter (Scenario A) during bidding_2
  Widget _buildTrumpSetterWaitingScreen(List<Player> players, Room room) {
    final currentPlayer = players.isNotEmpty ? players[room.turnIndex % players.length] : null;
    final waitingFor = currentPlayer?.name.split(' ').first ?? 'other players';
    return Positioned.fill(
      child: Container(
        color: Colors.black.withOpacity(0.82),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('YOUR BID IS LOCKED', style: TextStyle(color: accentGold, fontSize: 13, letterSpacing: 3, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            const Icon(Icons.lock_outline_rounded, color: accentGold, size: 48),
            const SizedBox(height: 24),
            Text('Waiting for', style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 14)),
            const SizedBox(height: 8),
            Text(waitingFor, style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900)),
            const SizedBox(height: 6),
            Text('to make their Call...', style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 14)),
          ],
        ),
      ),
    );
  }

  /// Bottom hint for non-active, non-trump-setter players in bidding_2
  Widget _buildBidding2WaitingText(List<Player> players, Room room) {
    final currentPlayer = players.isNotEmpty ? players[room.turnIndex % players.length] : null;
    final waitingFor = currentPlayer?.name.split(' ').first ?? 'other players';
    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 100),
        child: Text('Waiting for $waitingFor to make their Call...',
          style: const TextStyle(color: Colors.white54, fontStyle: FontStyle.italic)),
      ),
    );
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
                    TextSpan(text: ' / ${(p.bid != null && p.bid! > 0) ? p.bid : "?"}', style: const TextStyle(color: Colors.white38, fontSize: 14)),
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

  Widget _buildPlayerAvatar(Player player, String position, bool isTurn, bool isDealer, Color color) {
    return Padding(
      padding: _getPaddingFromPosition(position),
      child: Align(
        alignment: _getAlignmentFromPosition(position),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 86,
              height: 120,
              decoration: BoxDecoration(
                color: playerCardBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isTurn ? accentGold : (position == 'bottom' ? activeCardBg.withOpacity(0.5) : Colors.white10),
                  width: isTurn ? 2 : 1,
                ),
                boxShadow: [
                  if (isTurn)
                    BoxShadow(color: accentGold.withOpacity(0.2), blurRadius: 15, spreadRadius: 2),
                ],
              ),
              child: Column(
                children: [
                  // Top Score Circle
                  Expanded(
                    flex: 3,
                    child: Center(
                      child: Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: (player.totalScore < 0 ? boxRed : (isTurn ? accentGold : Colors.white)).withOpacity(0.12),
                          border: Border.all(
                            color: (player.totalScore < 0 ? boxRed : (isTurn ? accentGold : Colors.white)).withOpacity(0.4),
                            width: 1.5
                          ),
                        ),
                        child: Center(
                          child: Text(
                            '${player.totalScore}',
                            style: TextStyle(
                              color: player.totalScore < 0 ? boxRed : Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Player Name
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      player.name.toUpperCase(),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w900),
                    ),
                  ),
                  const Spacer(),
                  // Bottom Info Section
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black26,
                      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(11)),
                    ),
                    child: Column(
                      children: [
                        Text(
                          '${player.tricksWon} / ${player.bid ?? 0}',
                          style: TextStyle(color: isTurn ? accentGold : Colors.white54, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                        const Text(
                          'tricks',
                          style: TextStyle(color: Colors.white24, fontSize: 7, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'Score: ${player.totalScore}',
                          style: const TextStyle(color: Colors.white24, fontSize: 8),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (isDealer)
               const Padding(
                 padding: EdgeInsets.only(top: 4),
                 child: Text('DEALER', style: TextStyle(color: accentGold, fontSize: 8, fontWeight: FontWeight.w900)),
               ),
          ],
        ),
      ),
    );
  }

  Alignment _getAlignmentFromPosition(String pos) {
    switch (pos) {
      case 'bottom': return Alignment.bottomLeft;
      case 'left': return Alignment.topLeft;
      case 'top': return Alignment.topRight;
      case 'right': return Alignment.bottomRight;
      default: return Alignment.center;
    }
  }

  EdgeInsets _getPaddingFromPosition(String pos) {
    switch (pos) {
      case 'bottom': return const EdgeInsets.only(left: 30, bottom: 60);
      case 'left': return const EdgeInsets.only(left: 30, top: 40);
      case 'top': return const EdgeInsets.only(right: 30, top: 40);
      case 'right': return const EdgeInsets.only(right: 30, bottom: 60);
      default: return EdgeInsets.zero;
    }
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

String _getSuitEmojiStatic(String code) {
  switch (code) {
    case 'S': return '♠️';
    case 'H': return '♥️';
    case 'D': return '♦️';
    case 'C': return '♣️';
    default: return '';
  }
}

class CardsLayer extends ConsumerStatefulWidget {
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
  ConsumerState<CardsLayer> createState() => _CardsLayerState();
}

class _CardsLayerState extends ConsumerState<CardsLayer> {
  int _lastTrickCount = 0;
  Timer? _sweepTimer;
  bool _isTrickExpanded = false;

  @override
  void dispose() {
    _sweepTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // === USE PREDICTIVE STATE FOR UI RENDERING ===
    final playedMaps = ref.watch(predictivePlayedCardsProvider(widget.roomId));
    
    // We need the room code to get the turnIndex (winner)
    final roomCode = ref.watch(currentRoomCodeProvider);
    final room = roomCode != null ? ref.watch(roomMetadataProvider(roomCode)).value : null;

    // Side-effect: Clear local tracking after a trick finishes (delay is for sweep animation)
    ref.listen<List<Map<String, dynamic>>>(
      predictivePlayedCardsProvider(widget.roomId),
      (prev, next) {
         if (next.length % 4 == 0 && next.isNotEmpty && next.length != _lastTrickCount) {
            _lastTrickCount = next.length;
            _sweepTimer?.cancel();
            // We NO LONGER clear localPlayedCards here. 
            // The room_provider.dart pruning side-effect will clear it once server catches up.
         } else if (next.length != _lastTrickCount) {
           _lastTrickCount = next.length;
         }
      },
    );

    // Watch for round changes or lobby resets to reset local state
    if (room != null) {
      ref.listen<int?>(
        roomMetadataProvider(roomCode!).select((data) => data.value?.currentRound),
        (prev, next) {
          if (prev != next) ref.read(localPlayedCardsProvider.notifier).state = {};
        },
      );
      ref.listen<String?>(
        roomMetadataProvider(roomCode).select((data) => data.value?.status),
        (prev, next) {
          if (next == 'shuffling' || next == 'waiting') ref.read(localPlayedCardsProvider.notifier).state = {};
        },
      );
    }

    // --- Table Rendering Logic ---
    if (playedMaps.isEmpty) return Stack(children: _buildPlayerHands(ref));

    final trickSize = playedMaps.length % 4;
    final isTrickFinished = trickSize == 0;
    
    // Always show the "current" trick (the last 4 if finished, or the current n if in progress)
    final trickStartIndex = playedMaps.length - (isTrickFinished ? 4 : trickSize);
    final currentTrick = playedMaps.sublist(trickStartIndex < 0 ? 0 : trickStartIndex);
    
    // Winner Position Logic for Sweep Animation
    String? winnerPos;
    if (isTrickFinished && room != null) {
       final playersList = ref.read(playersStreamProvider(room.id)).value ?? [];
       final winnerId = Player.evaluateTrickWinner(currentTrick, room.trumpSuit, playersList);
       
       if (winnerId != null && playersList.isNotEmpty) {
          final winnerIdxInList = playersList.indexWhere((p) => p.id == winnerId);
          final localPlayerIdxInList = playersList.indexWhere((p) => p.id == widget.localPlayerId);
          
          if (winnerIdxInList != -1 && localPlayerIdxInList != -1) {
            final winnerIdxInRotated = (winnerIdxInList - localPlayerIdxInList + 4) % 4;
            winnerPos = _getPositionFromIndex(winnerIdxInRotated);
          }
       }
    }

    return Stack(
      clipBehavior: Clip.none,
      children: [
        ..._buildPlayerHands(ref),
        
        // Trick Area with Swipe interaction
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onScaleStart: (_) => setState(() => _isTrickExpanded = true),
            onScaleEnd: (_) => setState(() => _isTrickExpanded = false),
            onLongPressStart: (_) => setState(() => _isTrickExpanded = true),
            onLongPressEnd: (_) => setState(() => _isTrickExpanded = false),
            onHorizontalDragStart: (_) => setState(() => _isTrickExpanded = true),
            onHorizontalDragEnd: (_) => setState(() => _isTrickExpanded = false),
            child: Stack(
              children: currentTrick.map((m) {
                final player = widget.players.cast<Player?>().firstWhere((p) => p?.id == m['player_id'], orElse: () => null);
                if (player == null) return const SizedBox();
                final playerIdxInRotated = widget.players.indexOf(player);
                final pos = _getPositionFromIndex(playerIdxInRotated);
                return PlayedCardWidget(
                  key: ValueKey('played_${m['card_value']}'),
                  card: CardModel.fromId(m['card_value']),
                  position: pos,
                  playerName: player.name,
                  order: currentTrick.indexOf(m),
                  isTrickFinished: isTrickFinished,
                  winnerPosition: winnerPos,
                  isExpanded: _isTrickExpanded,
                );
              }).toList(),
            ),
          ),
        ),

        // Expanded Hint
        if (currentTrick.isNotEmpty && !_isTrickExpanded && !isTrickFinished)
          Align(
            alignment: Alignment.center,
            child: Padding(
              padding: const EdgeInsets.only(top: 160),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black45,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text('Swipe center to see all cards', 
                  style: TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold)),
              ),
            ),
          ),
      ],
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
    final roomId = widget.roomId;
    final players = widget.players;
    final localPlayerId = widget.localPlayerId;
    final localHandAsync = ref.watch(playerHandProvider(localPlayerId));
    final playableIds = ref.watch(playableCardsProvider(roomId));
    final pendingPlays = ref.watch(pendingCardPlayProvider);
    final localPlayed = ref.watch(localPlayedCardsProvider);
    List<Widget> handWidgets = [];

    localHandAsync.whenData((hand) {
      // FIX FLICKER: Filter ONLY based on local optimistic state and actual hand database.
      // We IGNORE what is on the table (myPlayedIds) to avoid the "reappearing card" gap.
      final visibleHand = hand.where((h) {
        final val = h['card_value'] as String;
        // If it's in pending or localPlayed, we keep it hidden.
        // Once the server-side 'hands' table update reaches here, it will be gone from 'hand' anyway.
        return !pendingPlays.contains(val) && !localPlayed.contains(val);
      }).toList();
      
      for (var i = 0; i < visibleHand.length; i++) {
        final rawCardId = visibleHand[i]['card_value'] as String;
        final cardId = rawCardId.trim().toUpperCase();
        final isPlayable = playableIds.contains(cardId); // Global lock removed for trick transition
        
        handWidgets.add(
          HandCardWidget(
            key: ValueKey('hand_$cardId'),
            card: CardModel.fromId(cardId),
            index: i,
            total: visibleHand.length,
            isPlayable: isPlayable,
            onTap: isPlayable ? () async {
              gameAudio.playCardPlay();
              // Optimistically hide from hand
              ref.read(pendingCardPlayProvider.notifier).update((state) => {...state, cardId});
              ref.read(localPlayedCardsProvider.notifier).update((state) => {...state, cardId});
              
              try {
                await ref.read(cardServiceProvider).playCard(roomId, localPlayerId, cardId);
              } catch (e) {
                // If it fails, restore the card to hand
                ref.read(pendingCardPlayProvider.notifier).update((state) => state.where((id) => id != cardId).toSet());
                ref.read(localPlayedCardsProvider.notifier).update((state) => state.where((id) => id != cardId).toSet());
                debugPrint('Play card failed: $e');
              }
              // pendingCardPlayProvider will be cleared by ref.listen below
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
        final cardsPlayedByOpponent = ref.watch(predictivePlayedCardsProvider(roomId)).where((m) => m['player_id'] == p.id).length;
        final actualHandSize = (hand.length - cardsPlayedByOpponent).clamp(0, 52);
        
        for (var j = 0; j < actualHandSize; j++) {
          handWidgets.add(OpponentCardWidget(
            key: ValueKey('opp_${pos}_${p.id}_$j'),
            position: pos, 
            index: j, 
            total: actualHandSize
          ));
        }
      });
    }
    // Listen for new cards in local hand for dealing SFX and to clear pending plays
    ref.listen(playerHandProvider(localPlayerId), (prev, next) {
      next.whenData((hand) {
        // 1. Manage pending plays set: remove if the card is actually gone from the DB hand
        final handIds = hand.map((h) => h['card_value'] as String).toSet();
        ref.read(pendingCardPlayProvider.notifier).update((state) => 
          state.where((id) => handIds.contains(id)).toSet()
        );

        // 2. Deal SFX
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
                  behavior: HitTestBehavior.opaque,
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
    const spacing = 12.0;
    final fanOffset = (index - (total - 1) / 2) * spacing;
    final rotation = (index - (total - 1) / 2) * 0.05;

    Alignment alignment;
    double? top, bottom, left, right;
    double? angle;

    switch (position) {
      case 'left': alignment = Alignment.centerLeft; left = 140; top = fanOffset; angle = math.pi / 2 + rotation; break;
      case 'top': alignment = Alignment.topCenter; top = 140; left = fanOffset; angle = math.pi + rotation; break;
      case 'right': alignment = Alignment.centerRight; right = 140; bottom = fanOffset; angle = -math.pi / 2 + rotation; break;
      default: alignment = Alignment.center;
    }

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 400 + (index * 60)),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Align(
          alignment: alignment,
          child: Transform.translate(
            offset: Offset(
              (position == 'right' ? -20.0 : (position == 'left' ? 20.0 : 0)) * value, 
              (position == 'top' ? 20.0 : 0) * value
            ),
            child: Transform.rotate(
              angle: (angle ?? 0) * value,
              child: const PlayingCard(isFaceUp: false, width: 44, height: 66),
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
  final String playerName;
  final int order;
  final bool isTrickFinished;
  final String? winnerPosition;
  final bool isExpanded;

  const PlayedCardWidget({
    super.key,
    required this.card,
    required this.position,
    required this.playerName,
    required this.order,
    this.isTrickFinished = false,
    this.winnerPosition,
    this.isExpanded = false,
  });

  @override
  Widget build(BuildContext context) {
    double offsetX = 0;
    double offsetY = 0;
    double rotation = 0;

    const gridOffset = 45.0; // Half of (cardSize + gap)
    
    switch (position) {
      case 'bottom': offsetX = -gridOffset; offsetY = gridOffset; rotation = 0; break;
      case 'left': offsetX = -gridOffset; offsetY = -gridOffset; rotation = 0; break;
      case 'top': offsetX = gridOffset; offsetY = -gridOffset; rotation = 0; break;
      case 'right': offsetX = gridOffset; offsetY = gridOffset; rotation = 0; break;
    }

    double winOffsetX = 0;
    double winOffsetY = 0;
    if (isTrickFinished && winnerPosition != null) {
      switch (winnerPosition) {
        case 'bottom': winOffsetY = 240; break;
        case 'left': winOffsetX = -180; break;
        case 'top': winOffsetY = -240; break;
        case 'right': winOffsetX = 180; break;
      }
    }

    return Center(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 1.0, end: 0.0),
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
        builder: (context, value, child) {
          return TweenAnimationBuilder<double>(
            tween: isTrickFinished ? Tween(begin: 0.0, end: 1.0) : Tween(begin: 0.0, end: 0.0),
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeInQuint,
            builder: (context, winValue, child) {
              return Transform.translate(
                offset: Offset(
                  (offsetX * value) + (winOffsetX * winValue), 
                  (offsetY * value) + (winOffsetY * winValue),
                ),
                child: Transform.rotate(
                  angle: rotation + (order * 0.1),
                  child: Opacity(
                    opacity: 1.0 - (winValue * 0.8), // Fades out slightly as it reaches winner
                    child: Container(
                          width: 80,
                          height: 100,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: isTrickFinished && winnerPosition == position
                                ? Border.all(color: accentGold, width: 4)
                                : Border.all(color: Colors.white, width: 1),
                            boxShadow: [
                              BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 10, offset: const Offset(2, 4)),
                              if (isTrickFinished && winnerPosition == position)
                                BoxShadow(color: accentGold.withOpacity(0.4), blurRadius: 15, spreadRadius: 2),
                            ],
                          ),
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  card.value,
                                  style: TextStyle(
                                    color: (card.suit.code == 'H' || card.suit.code == 'D') ? Colors.red : Colors.black87,
                                    fontSize: 24,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                Text(
                                  CardModel.getSuitEmoji(card.suit.code),
                                  style: TextStyle(
                                    color: (card.suit.code == 'H' || card.suit.code == 'D') ? Colors.red : Colors.black87,
                                    fontSize: 18,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

Widget _buildBottomBar(String trumpSuit, Room room, int? playedCardsCount) {
  final currentTrick = ((playedCardsCount ?? 0) ~/ 4) + 1;
  final displayTrick = currentTrick.clamp(1, 13);
  final suitEmoji = CardModel.getSuitEmoji(trumpSuit);

  return Positioned(
    bottom: 0,
    left: 0,
    right: 0,
    child: Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: const BoxDecoration(
        color: Colors.black,
        border: Border(top: BorderSide(color: Color(0xFF1E2833), width: 0.5)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '${suitEmoji} TRUMP SUIT: ${CardModel.getSuitName(trumpSuit).toUpperCase()}',
            style: const TextStyle(color: accentGold, fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 0.8),
          ),
          const SizedBox(width: 24),
          const Text('·', style: TextStyle(color: Colors.white24, fontSize: 20)),
          const SizedBox(width: 24),
          Text(
            'ROUND ${room.currentRound}  ·  TRICK $displayTrick OF 13',
            style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 0.8),
          ),
        ],
      ),
    ),
  );
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
