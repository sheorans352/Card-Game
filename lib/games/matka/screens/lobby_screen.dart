// Matka lobby screen — wait for players
// Independent of lib/games/minus/

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import '../providers/matka_provider.dart';
import '../models/matka_models.dart';
import 'game_table_screen.dart';

class MatkaLobbyScreen extends ConsumerWidget {
  final String roomId;

  const MatkaLobbyScreen({super.key, required this.roomId});

  static const _bg = Color(0xFF100820);
  static const _purple = Color(0xFF9B59B6);
  static const _gold = Color(0xFFFFD700);
  static const _card = Color(0xFF1A0D2B);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roomAsync = ref.watch(matkaRoomByIdProvider(roomId));
    final playersAsync = ref.watch(matkaPlayersProvider(roomId));
    final isHost = ref.watch(isMatkaHostProvider(roomId));
    final localPlayer = ref.watch(localMatkaPlayerProvider(roomId));
    final isLoaded = ref.watch(matkaSessionLoadedProvider);

    if (!isLoaded) {
      return const Scaffold(
        backgroundColor: _bg,
        body: Center(child: CircularProgressIndicator(color: _purple)),
      );
    }

    return Scaffold(
      backgroundColor: _bg,
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF1A0D2B), _bg],
              ),
            ),
          ),
          roomAsync.when(
            data: (room) {
              if (room == null) return const Center(child: Text('Room not found', style: TextStyle(color: Colors.white)));
              
              if (room.status == 'betting' || room.status == 'round_result' || room.status == 'shuffling') {
                Future.microtask(() {
                  context.go('/matka/table/$roomId');
                });
              }

              return SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    children: [
                      _buildHeader(room),
                      const SizedBox(height: 32),
                      Expanded(
                        child: playersAsync.when(
                          data: (players) => _buildPlayerList(players, localPlayer),
                          loading: () => const Center(child: CircularProgressIndicator(color: _purple)),
                          error: (e, s) => Center(child: Text('Error: $e', style: const TextStyle(color: Colors.red))),
                        ),
                      ),
                      const SizedBox(height: 24),
                      _buildFooter(context, ref, room, playersAsync.value ?? [], isHost, localPlayer),
                    ],
                  ),
                ),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator(color: _purple)),
            error: (e, s) => Center(child: Text('Error: $e', style: const TextStyle(color: Colors.red))),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(room) {
    return Column(
      children: [
        const Text(
          'LOBBY',
          style: TextStyle(
            color: _purple,
            fontSize: 12,
            fontWeight: FontWeight.w900,
            letterSpacing: 4,
          ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () {
            final baseUrl = Uri.base.toString().split('?').first.split('#').first;
            final shareUrl = '$baseUrl#/?code=${room.code}&game=matka';
            final text = 'Join my Matka game!\n\n'
                'Ante: ${room.anteAmount}\n'
                'Bet Step: x${room.betMultiple}\n\n'
                'Link: $shareUrl';
            Share.share(text);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.black26,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _gold.withOpacity(0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.share_rounded, color: _gold, size: 18),
                const SizedBox(width: 12),
                Text(
                  room.code,
                  style: const TextStyle(
                    color: _gold,
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 8,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Ante: ${room.anteAmount}  •  Step: x${room.betMultiple}  •  Decks: ${room.deckCount}',
          style: const TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildPlayerList(List<MatkaPlayer> players, MatkaPlayer? localPlayer) {
    return ListView.builder(
      itemCount: 8,
      itemBuilder: (context, index) {
        final hasPlayer = index < players.length;
        final player = hasPlayer ? players[index] : null;
        final isMe = player?.id == localPlayer?.id;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: hasPlayer ? _card : Colors.white.withOpacity(0.02),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isMe ? _purple : (hasPlayer ? Colors.white12 : Colors.white.withOpacity(0.05)),
              width: isMe ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: hasPlayer ? _purple.withOpacity(0.2) : Colors.white.withOpacity(0.02),
                child: Text(
                  hasPlayer ? player!.name[0].toUpperCase() : '${index + 1}',
                  style: TextStyle(
                    color: hasPlayer ? _purple : Colors.white12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hasPlayer ? (isMe ? '${player!.name} (You)' : player!.name) : 'Waiting...',
                      style: TextStyle(
                        color: hasPlayer ? Colors.white : Colors.white12,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    if (hasPlayer && player!.isHost)
                      const Text(
                        'HOST',
                        style: TextStyle(color: _gold, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 1),
                      ),
                  ],
                ),
              ),
              if (hasPlayer)
                Icon(
                  player!.isReady ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                  color: player.isReady ? Colors.green : Colors.white24,
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFooter(BuildContext context, WidgetRef ref, room, List<MatkaPlayer> players, bool isHost, MatkaPlayer? localPlayer) {
    final allReady = players.length >= 1 && players.every((p) => p.isReady);
    
    return Column(
      children: [
        if (isHost)
          ElevatedButton(
            onPressed: allReady ? () => _startGame(context, ref, room, players) : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: _purple,
              disabledBackgroundColor: Colors.white.withOpacity(0.05),
              minimumSize: const Size(double.infinity, 56),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: Text(
              allReady ? 'START GAME' : 'WAITING FOR READY STATUS',
              style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 2),
            ),
          )
        else
          ElevatedButton(
            onPressed: () {
              if (localPlayer != null) {
                ref.read(matkaLobbyServiceProvider).setReady(localPlayer.id, !localPlayer.isReady);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: localPlayer?.isReady == true ? Colors.green.withOpacity(0.2) : _purple,
              minimumSize: const Size(double.infinity, 56),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              side: localPlayer?.isReady == true ? const BorderSide(color: Colors.green) : null,
            ),
            child: Text(
              localPlayer?.isReady == true ? 'READY ✓' : 'TAP TO READYUP',
              style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 2),
            ),
          ),
        const SizedBox(height: 16),
        TextButton(
          onPressed: () {
            ref.read(matkaSessionProvider.notifier).clear();
            context.go('/matka');
          },
          child: const Text('Leave Room', style: TextStyle(color: Colors.white38)),
        ),
      ],
    );
  }

  Future<void> _startGame(BuildContext context, WidgetRef ref, room, List<MatkaPlayer> players) async {
    try {
      await ref.read(matkaGameServiceProvider).startGame(room, players);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to start: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}
