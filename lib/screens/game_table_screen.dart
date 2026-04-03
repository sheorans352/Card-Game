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

const Color primaryBg = Color(0xFF0A1A2F); 
const Color tableFelt = Color(0xFF0D1B2A);
const Color accentGold = Color(0xFFE5B84B); 
const Color playerCardBg = Color(0xFF101E33); 
const Color activeCardBg = Color(0xFF1A2F4A); 
const Color boxGreen = Color(0xFF4CAF50);
const Color boxRed = Color(0xFFEF5350);

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

    ref.listen<AsyncValue<Room?>>(roomMetadataProvider(roomCode), (previous, next) {
      next.whenData((room) {
        if (room == null) return;
        final players = ref.read(playersStreamProvider(room.id)).value;
        if (players == null || players.length < 4) return;
        final localId = ref.read(localPlayerIdProvider);
        final dealerIndexInList = room.dealerIndex % players.length;
        if (players[dealerIndexInList].id == localId) {
          if (room.status == 'shuffling' && previous?.value?.status != 'shuffling' && room.deckCutValue == null) {
            gameAudio.playShuffle();
            ref.read(cardServiceProvider).shuffleDeck(room.id);
          }
        }
      });
    });

    ref.listen<int?>(roomMetadataProvider(roomCode).select((data) => data.value?.currentRound), (prev, next) {
      if (next != null && prev != null && next > prev) {
        setState(() => _showScoreboard = true);
        ref.read(localPlayedCardsProvider.notifier).state = {};
      }
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
              if (localIndex == -1 || localPlayerId == null) return const Center(child: Text('Not in room'));

              final predictivePlayedCards = ref.watch(predictivePlayedCardsProvider(room.id));
              final playedCardsCount = predictivePlayedCards.length;
              final localHandAsync = ref.watch(playerHandProvider(localPlayerId));
              final myPlayedIds = predictivePlayedCards.where((m) => m['player_id'] == localPlayerId).map((m) => m['card_value'] as String).toSet();
              final pendingPlays = ref.watch(pendingCardPlayProvider);
              final localPlayed = ref.watch(localPlayedCardsProvider);

              final rotatedPlayers = List.generate(4, (i) => players[(localIndex + i) % players.length]);

              return Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [primaryBg, Color(0xFF050B14)]),
                ),
                child: Stack(
                  children: [
                    const SpadeBackground(),
                    
                    // 1. TOP HUD
                    _buildTopHUD(players, room, playedCardsCount),

                    // 2. SCOREBOARD BUTTON (Far Top Right)
                    Positioned(
                      top: MediaQuery.of(context).padding.top + 5,
                      right: 8,
                      child: GestureDetector(
                        onTap: () => setState(() => _showScoreboard = true),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.black45,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: accentGold.withOpacity(0.35)),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Icon(Icons.leaderboard_rounded, color: accentGold, size: 20),
                              SizedBox(height: 2),
                              Text('SCORE', style: TextStyle(color: accentGold, fontSize: 8, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // 3. HANDS (Tucked Behind)
                    ..._buildPlayerHands(ref, localHandAsync, myPlayedIds, pendingPlays, localPlayed, room.id, rotatedPlayers, localPlayerId),

                    // 4. TRICK LAYER
                    CardsLayer(
                      roomId: room.id,
                      players: rotatedPlayers,
                      localPlayerId: localPlayerId,
                      currentPhase: room.currentPhase ?? 'playing',
                      playerPositions: _playerKeys,
                    ),

                    // 5. AVATARS (On Top)
                    _buildPlayerAvatar(rotatedPlayers[0], 'bottom', ref.watch(predictiveTurnIdProvider(room.id)) == rotatedPlayers[0].id, room.dealerIndex == (players.indexOf(rotatedPlayers[0])), localPlayerId),
                    _buildPlayerAvatar(rotatedPlayers[1], 'left', ref.watch(predictiveTurnIdProvider(room.id)) == rotatedPlayers[1].id, room.dealerIndex == (players.indexOf(rotatedPlayers[1])), localPlayerId),
                    _buildPlayerAvatar(rotatedPlayers[2], 'top', ref.watch(predictiveTurnIdProvider(room.id)) == rotatedPlayers[2].id, room.dealerIndex == (players.indexOf(rotatedPlayers[2])), localPlayerId),
                    _buildPlayerAvatar(rotatedPlayers[3], 'right', ref.watch(predictiveTurnIdProvider(room.id)) == rotatedPlayers[3].id, room.dealerIndex == (players.indexOf(rotatedPlayers[3])), localPlayerId),

                    if (room.trumpSuit != null)
                      _buildBottomBar(room.trumpSuit!, room, playedCardsCount),

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
                       _buildBiddingWaitingOverlay(players, room, 'to make their Call...'),

                    if (room.currentPhase == 'cutting') const DeckCutOverlay(),

                    if (_showScoreboard)
                      Positioned.fill(
                        child: GestureDetector(
                          onTap: () => setState(() => _showScoreboard = false),
                          child: Container(
                            color: Colors.black87,
                            padding: const EdgeInsets.only(top: 80),
                            child: ScoreboardOverlay(roomId: room.id, players: players, onClose: () => setState(() => _showScoreboard = false)),
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator(color: accentGold)),
            error: (e, s) => Container(),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator(color: accentGold)),
        error: (e, s) => Container(),
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
              gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.black.withOpacity(0.8), Colors.black.withOpacity(0.5)]),
              border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.1), width: 0.5)),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Trump Info (Left)
                if (room.trumpSuit != null)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(_getSuitEmojiStatic(room.trumpSuit!), style: const TextStyle(fontSize: 18)),
                            const SizedBox(width: 8),
                            Text(_getSuitName(room.trumpSuit!).toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 1)),
                          ],
                        ),
                        const SizedBox(height: 2),
                        const Text('TRUMP SUIT', style: TextStyle(color: Colors.white24, fontSize: 8, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),

                // Center Info
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('ROUND ${room.currentRound ?? 1}', style: const TextStyle(color: Colors.white38, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                    Builder(
                      builder: (context) {
                        bool isActuallyPlaying = room.status == 'playing';
                        int trickNumber = isActuallyPlaying ? (playedCardsCount ~/ 4) + 1 : 1;
                        if (trickNumber > 13) trickNumber = 13; // Cap it
                        return Text('TRICK $trickNumber / 13', style: const TextStyle(color: accentGold, fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 1));
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlayerAvatar(Player player, String position, bool isTurn, bool isDealer, String localId) {
    final bool isLocal = player.id == localId;
    return Padding(
      padding: _getPaddingFromPosition(position),
      child: Align(
        alignment: _getAlignmentFromPosition(position),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 86, height: 120,
              decoration: BoxDecoration(
                color: playerCardBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isTurn ? accentGold : (isLocal ? activeCardBg : Colors.white10), width: isTurn ? 2 : 1),
                boxShadow: [if (isTurn) BoxShadow(color: accentGold.withOpacity(0.2), blurRadius: 15, spreadRadius: 2)],
              ),
              child: Column(
                children: [
                  Expanded(
                    flex: 3,
                    child: Center(
                      child: Container(
                        width: 50, height: 50,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: (player.totalScore < 0 ? boxRed : (isTurn ? accentGold : Colors.white)).withOpacity(0.12),
                          border: Border.all(color: (player.totalScore < 0 ? boxRed : (isTurn ? accentGold : Colors.white)).withOpacity(0.3), width: 1.5),
                        ),
                        child: Center(child: Text('${player.totalScore}', style: TextStyle(color: player.totalScore < 0 ? boxRed : Colors.white, fontSize: 18, fontWeight: FontWeight.w900))),
                      ),
                    ),
                  ),
                  Text(isLocal ? 'YOU' : player.name.toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900), overflow: TextOverflow.ellipsis),
                  const Spacer(),
                  Container(
                    width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 6),
                    decoration: const BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.vertical(bottom: Radius.circular(11))),
                    child: Column(children: [
                      Text('${player.tricksWon} / ${player.bid ?? 0}', style: TextStyle(color: isTurn ? accentGold : Colors.white54, fontSize: 11, fontWeight: FontWeight.bold)),
                      const Text('tricks', style: TextStyle(color: Colors.white24, fontSize: 7, fontWeight: FontWeight.bold)),
                    ]),
                  ),
                ],
              ),
            ),
            if (isDealer) const Padding(padding: EdgeInsets.only(top: 4), child: Text('DEALER', style: TextStyle(color: accentGold, fontSize: 8, fontWeight: FontWeight.w900))),
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
      case 'bottom': return const EdgeInsets.only(left: 20, bottom: 210);
      case 'left': return const EdgeInsets.only(left: 20, top: 100);
      case 'top': return const EdgeInsets.only(right: 20, top: 100);
      case 'right': return const EdgeInsets.only(right: 20, bottom: 210);
      default: return EdgeInsets.zero;
    }
  }

  List<Widget> _buildPlayerHands(WidgetRef ref, AsyncValue<List<Map<String, dynamic>>> localHandAsync, Set<String> myPlayedIds, Set<String> pendingPlays, Set<String> localPlayed, String roomId, List<Player> rotatedPlayers, String localPlayerId) {
    List<Widget> hands = [];
    localHandAsync.whenData((hand) {
      final playableIds = ref.watch(playableCardsProvider(roomId));
      final visible = hand.where((h) => !pendingPlays.contains(h['card_value']) && !localPlayed.contains(h['card_value']) && !myPlayedIds.contains(h['card_value'])).toList();
      for (var i = 0; i < visible.length; i++) {
        final id = (visible[i]['card_value'] as String).trim().toUpperCase();
        hands.add(HandCardWidget(card: CardModel.fromId(id), index: i, total: visible.length, isPlayable: playableIds.contains(id), onTap: () async {
          if (!playableIds.contains(id)) { gameAudio.playInvalidMove(); return; }
          gameAudio.playCardPlay();
          ref.read(pendingCardPlayProvider.notifier).update((s) => {...s, id});
          ref.read(localPlayedCardsProvider.notifier).update((s) => {...s, id});
          try { await ref.read(cardServiceProvider).playCard(roomId, localPlayerId, id); }
          catch (e) {
            ref.read(pendingCardPlayProvider.notifier).update((s) => s.where((v) => v != id).toSet());
            ref.read(localPlayedCardsProvider.notifier).update((s) => s.where((v) => v != id).toSet());
          }
        }));
      }
    });
    for (var i = 1; i < 4; i++) {
      final p = rotatedPlayers[i];
      final pos = _getPositionFromIndex(i);
      ref.watch(playerHandProvider(p.id)).whenData((hand) {
        final played = ref.watch(predictivePlayedCardsProvider(roomId)).where((m) => m['player_id'] == p.id).length;
        final size = (hand.length - played).clamp(0, 52);
        for (var j = 0; j < size; j++) hands.add(OpponentCardWidget(position: pos, index: j, total: size));
      });
    }
    return hands;
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

  Widget _buildBiddingWaitingOverlay(List<Player> players, Room room, String message) {
    final currentPlayer = players.isNotEmpty ? players[room.turnIndex % players.length] : null;
    return Positioned.fill(
      child: Container(color: Colors.black.withOpacity(0.82), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.lock_outline_rounded, color: accentGold, size: 48),
        const SizedBox(height: 24),
        Text('Waiting for ${currentPlayer?.name.split(" ").first ?? "player"}', style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
        Text(message, style: const TextStyle(color: Colors.white54, fontSize: 14)),
      ])),
    );
  }

  String _getSuitName(String suit) {
    switch (suit) { case 'S': return 'Spades'; case 'H': return 'Hearts'; case 'D': return 'Diamonds'; case 'C': return 'Clubs'; default: return ''; }
  }

  String _getSuitEmojiStatic(String code) {
    switch (code) { case 'S': return '♠️'; case 'H': return '♥️'; case 'D': return '♦️'; case 'C': return '♣️'; default: return ''; }
  }
}

class CardsLayer extends ConsumerWidget {
  final String roomId;
  final List<Player> players;
  final String localPlayerId;
  final String currentPhase;
  final Map<String, GlobalKey> playerPositions;
  const CardsLayer({super.key, required this.roomId, required this.players, required this.localPlayerId, required this.currentPhase, required this.playerPositions});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playedMaps = ref.watch(predictivePlayedCardsProvider(roomId));
    if (playedMaps.isEmpty) return const SizedBox();
    final trickSize = playedMaps.length % 4;
    final isFinished = trickSize == 0;
    final startIndex = playedMaps.length - (isFinished ? 4 : trickSize);
    final currentTrick = playedMaps.sublist(startIndex < 0 ? 0 : startIndex);
    String? winnerPos;
    if (isFinished) {
      final roomCode = ref.read(currentRoomCodeProvider);
      final room = roomCode != null ? ref.read(roomMetadataProvider(roomCode)).value : null;
      final winnerId = Player.evaluateTrickWinner(currentTrick, room?.trumpSuit, players);
      if (winnerId != null) {
        final winnerIdx = players.indexWhere((p) => p.id == winnerId);
        if (winnerIdx != -1) winnerPos = _getPositionFromIndex(winnerIdx);
      }
    }
    return Stack(children: currentTrick.map((m) {
      final p = players.firstWhere((p) => p.id == m['player_id']);
      return PlayedCardWidget(card: CardModel.fromId(m['card_value']), position: _getPositionFromIndex(players.indexOf(p)), playerName: p.name, order: currentTrick.indexOf(m), isTrickFinished: isFinished, winnerPosition: winnerPos);
    }).toList());
  }

  String _getPositionFromIndex(int index) {
    switch (index) { case 0: return 'bottom'; case 1: return 'left'; case 2: return 'top'; case 3: return 'right'; default: return 'bottom'; }
  }
}

class HandCardWidget extends StatelessWidget {
  final CardModel card; final int index; final int total; final bool isPlayable; final VoidCallback? onTap;
  const HandCardWidget({super.key, required this.card, required this.index, required this.total, required this.isPlayable, this.onTap});
  @override
  Widget build(BuildContext context) {
    final fanOffset = (index - (total - 1) / 2) * 22.0;
    final rotation = (index - (total - 1) / 2) * 0.08;
    return Align(alignment: Alignment.bottomCenter, child: TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0), duration: Duration(milliseconds: 600 + (index * 100)), curve: Curves.easeOutBack,
      builder: (context, value, child) => Transform.translate(offset: Offset(fanOffset * value, -85 - (1 - value) * 400), child: Transform.rotate(angle: rotation * value, child: GestureDetector(onTap: onTap, child: Opacity(opacity: isPlayable ? 1.0 : 0.6, child: PlayingCard(card: card, isFaceUp: true, isPlayable: isPlayable, width: 70, height: 105))))),
    ));
  }
}

class OpponentCardWidget extends StatelessWidget {
  final String position; final int index; final int total;
  const OpponentCardWidget({super.key, required this.position, required this.index, required this.total});
  @override
  Widget build(BuildContext context) {
    final fanOffset = (index - (total - 1) / 2) * 12.0;
    final rotation = (index - (total - 1) / 2) * 0.05;
    Alignment alignment; EdgeInsets padding; double angle;
    switch (position) {
      case 'left': alignment = Alignment.topLeft; padding = const EdgeInsets.only(left: 20, top: 100); angle = math.pi / 6 + (rotation * 0.5); break;
      case 'top': alignment = Alignment.topRight; padding = const EdgeInsets.only(right: 20, top: 100); angle = -math.pi / 6 + (rotation * 0.5); break;
      case 'right': alignment = Alignment.bottomRight; padding = const EdgeInsets.only(right: 20, bottom: 210); angle = -math.pi / 12 + (rotation * 0.5); break;
      default: alignment = Alignment.center; padding = EdgeInsets.zero; angle = 0;
    }
    return Align(alignment: alignment, child: Padding(padding: padding, child: SizedBox(width: 86, height: 120, child: Stack(alignment: Alignment.center, clipBehavior: Clip.none, children: [Transform.translate(offset: Offset(fanOffset, -10), child: Transform.rotate(angle: angle, child: const PlayingCard(isFaceUp: false, width: 44, height: 66)))]))));
  }
}

class PlayedCardWidget extends StatelessWidget {
  final CardModel card; final String position; final String playerName; final int order; final bool isTrickFinished; final String? winnerPosition;
  const PlayedCardWidget({super.key, required this.card, required this.position, required this.playerName, required this.order, this.isTrickFinished = false, this.winnerPosition});
  @override
  Widget build(BuildContext context) {
    double offsetX = 0, offsetY = 0;
    switch (position) { case 'bottom': offsetX = -45; offsetY = 45; break; case 'left': offsetX = -45; offsetY = -45; break; case 'top': offsetX = 45; offsetY = -45; break; case 'right': offsetX = 45; offsetY = 45; break; }
    double wX = 0, wY = 0;
    if (isTrickFinished && winnerPosition != null) {
      switch (winnerPosition) { case 'bottom': wX = -350; wY = 450; break; case 'left': wX = -350; wY = -450; break; case 'top': wX = 350; wY = -450; break; case 'right': wX = 350; wY = 450; break; }
    }
    return Center(child: TweenAnimationBuilder<double>(
      tween: isTrickFinished ? Tween(begin: 0.0, end: 1.0) : Tween(begin: 0.0, end: 0.0), duration: const Duration(milliseconds: 500), curve: Curves.easeInQuint,
      builder: (context, val, child) => Transform.translate(offset: Offset(offsetX + (wX * val), offsetY + (wY * val)), child: Opacity(opacity: 1.0 - (val * 0.8), child: Container(width: 80, height: 100, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: isTrickFinished && winnerPosition == position ? Border.all(color: accentGold, width: 4) : Border.all(color: Colors.white, width: 1), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 10, offset: const Offset(2, 4))]), child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Text(card.value, style: TextStyle(color: (card.suit.code == 'H' || card.suit.code == 'D') ? Colors.red : Colors.black87, fontSize: 24, fontWeight: FontWeight.w900)), Text(CardModel.getSuitEmoji(card.suit.code), style: TextStyle(color: (card.suit.code == 'H' || card.suit.code == 'D') ? Colors.red : Colors.black87, fontSize: 18))]))))),
    ));
  }
}

Widget _buildBottomBar(String trumpSuit, Room room, int? playedCardsCount) {
  final displayTrick = ((playedCardsCount ?? 0) ~/ 4 + 1).clamp(1, 13);
  return Positioned(bottom: 0, left: 0, right: 0, child: Container(height: 44, padding: const EdgeInsets.symmetric(horizontal: 24), decoration: const BoxDecoration(color: Colors.black, border: Border(top: BorderSide(color: Color(0xFF1E2833), width: 0.5))), child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Text('${CardModel.getSuitEmoji(trumpSuit)} TRUMP SUIT: ${CardModel.getSuitName(trumpSuit).toUpperCase()}', style: const TextStyle(color: accentGold, fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 0.8)), const SizedBox(width: 24), const Text('·', style: TextStyle(color: Colors.white24, fontSize: 20)), const SizedBox(width: 24), Text('ROUND ${room.currentRound}  ·  TRICK $displayTrick OF 13', style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 0.8))])));
}
