import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import '../providers/room_provider.dart';
import '../models/game_models.dart';
import 'game_table_screen.dart';
import 'home_screen.dart';

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
                child: Container(
                  padding: const EdgeInsets.all(32),
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
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(width: 48), // Spacer to center the code
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
                                tooltip: 'Copy Invite Link',
                                onPressed: () {
                                  final link = 'https://sheorans352.github.io/Card-Game/#/?room=$code';
                                  Clipboard.setData(ClipboardData(text: link));
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Invite link copied to clipboard!')),
                                  );
                                },
                              ),
                              IconButton(
                                icon: const Icon(Icons.share, size: 20, color: Colors.white54),
                                tooltip: 'Share to Contacts',
                                onPressed: () {
                                  final link = 'https://sheorans352.github.io/Card-Game/#/?room=$code';
                                  Share.share('Join my Minus game room: $code\nLink: $link');
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                      const Text(
                        'ROOM CODE',
                        style: TextStyle(fontSize: 14, color: Colors.white38),
                      ),
                      const SizedBox(height: 32),
                      const Divider(color: Colors.white10),
                      const SizedBox(height: 16),
                      const Text(
                        'PLAYERS',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 200,
                        child: playersAsync.when(
                          data: (players) => ListView.builder(
                            itemCount: players.length,
                            itemBuilder: (context, index) {
                              final player = players[index];
                              return ListTile(
                                leading: const Icon(Icons.person, color: Colors.white70),
                                title: Text(
                                  player.name,
                                  style: const TextStyle(color: Colors.white),
                                ),
                                trailing: player.isHost
                                    ? const Chip(
                                        label: Text('HOST', style: TextStyle(fontSize: 10, color: Colors.black)),
                                        backgroundColor: Colors.amber,
                                      )
                                    : null,
                              );
                            },
                          ),
                          loading: () => const Center(child: CircularProgressIndicator()),
                          error: (e, s) => Center(child: Text('Error: $e', style: const TextStyle(color: Colors.red))),
                        ),
                      ),
                      const SizedBox(height: 32),
                      playersAsync.when(
                        data: (players) {
                          // Mock local player check: assume 'Guest' isn't the local player if others exist
                          final localPlayer = players.firstWhere((p) => p.isHost, orElse: () => players.first);
                          final isHost = localPlayer.isHost;
                          
                          return ElevatedButton(
                            onPressed: isHost ? () async {
                              final roomData = room;
                              final playerIds = players.map((p) => p.id).toList();
                              
                              if (playerIds.length < 4) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Need 4 players to start!')),
                                  );
                                  return;
                              }

                              await ref.read(cardServiceProvider).dealInitialFive(roomData.id, playerIds);
                            } : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              minimumSize: const Size(double.infinity, 60),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: Text(
                              isHost ? 'START GAME' : 'WAITING FOR HOST...',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                            ),
                          );
                        },
                        loading: () => const SizedBox(),
                        error: (e, s) => const SizedBox(),
                      ),
                    ],
                  ),
                ),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, s) => Center(child: Text('Error loading room: $e')),
          ),
        ],
      ),
    );
  }
}
