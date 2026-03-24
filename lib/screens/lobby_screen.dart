import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import '../providers/room_provider.dart';
import '../models/game_models.dart';
import '../widgets/spade_background.dart';
import 'game_table_screen.dart';

class LobbyScreen extends ConsumerWidget {
  const LobbyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final code = ref.watch(currentRoomCodeProvider);
    if (code == null) {
      return const Scaffold(body: Center(child: Text('No room selected')));
    }

    final roomAsync = ref.watch(roomMetadataProvider(code));

    // Listen for phase change to transition to Game Table
    ref.listen(roomMetadataProvider(code), (previous, next) {
      next.whenData((room) {
        if (room != null && room.currentPhase != 'lobby') {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const GameTableScreen()),
          );
        }
      });
    });

    return Scaffold(
      body: Stack(
        children: [
          const SpadeBackground(),
          roomAsync.when(
            data: (room) {
              if (room == null) return const Center(child: Text('Room not found'));
              final playersAsync = ref.watch(playersStreamProvider(room.id));

              return Center(
                child: SingleChildScrollView(
                  child: Container(
                    padding: const EdgeInsets.all(32),
                    margin: const EdgeInsets.symmetric(vertical: 40),
                    constraints: const BoxConstraints(maxWidth: 500),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.8),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'LOBBY',
                          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white70),
                        ),
                        const SizedBox(height: 16),
                        FittedBox(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const SizedBox(width: 48),
                              Text(
                                code,
                                style: const TextStyle(
                                  fontSize: 64,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 12,
                                  color: Colors.white,
                                ),
                              ),
                              Column(
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.copy, size: 20, color: Colors.white54),
                                    onPressed: () {
                                      final origin = Uri.base.origin;
                                      final link = '$origin/#/?room=$code';
                                      Clipboard.setData(ClipboardData(text: link));
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Invite link copied!')),
                                      );
                                    },
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.share, size: 20, color: Colors.white54),
                                    onPressed: () {
                                      final origin = Uri.base.origin;
                                      final link = '$origin/#/?room=$code';
                                      Share.share('Join my Minus game: $link');
                                    },
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const Text('ROOM CODE', style: TextStyle(fontSize: 14, color: Colors.white38)),
                        const SizedBox(height: 32),
                        const Text('PLAYERS', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                        const SizedBox(height: 16),
                        playersAsync.when(
                          data: (players) => ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: players.length,
                            itemBuilder: (context, index) {
                              final player = players[index];
                              return ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: player.isHost ? Colors.amber : Colors.deepPurple,
                                  child: Text(player.name.substring(0, 1).toUpperCase()),
                                ),
                                title: Text(player.name, style: const TextStyle(color: Colors.white)),
                                trailing: player.isHost ? const Icon(Icons.star, color: Colors.amber) : null,
                              );
                            },
                          ),
                          loading: () => const CircularProgressIndicator(),
                          error: (e, s) => Text('Error: $e'),
                        ),
                        const SizedBox(height: 32),
                        if (room.hostId == ref.read(localPlayerIdProvider))
                          ElevatedButton(
                            onPressed: playersAsync.whenData((p) => p.length == 4).value ?? false
                                ? () => ref.read(lobbyServiceProvider).startGame(room.id)
                                : null,
                            child: const Text('START GAME'),
                          )
                        else
                          const Text('Waiting for host...', style: TextStyle(color: Colors.white54, fontStyle: FontStyle.italic)),
                      ],
                    ),
                  ),
                ),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, s) => Center(child: Text('Error: $e')),
          ),
        ],
      ),
    );
  }
}
