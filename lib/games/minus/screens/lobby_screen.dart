import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import '../../../games/minus/providers/room_provider.dart';
import '../../../games/minus/models/game_models.dart';
import '../../../games/minus/widgets/spade_background.dart';
import 'game_table_screen.dart';

class LobbyScreen extends ConsumerWidget {
  const LobbyScreen({super.key});

  static const Color primaryBg = Color(0xFF0B2111);
  static const Color accentGold = Color(0xFFC7A14C);
  static const Color cardDark = Color(0xFF141414);
  static const Color whatsappGreen = Color(0xFF25D366);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final code = ref.watch(currentRoomCodeProvider);
    if (code == null) {
      return const Scaffold(backgroundColor: primaryBg, body: Center(child: Text('No room selected', style: TextStyle(color: Colors.white))));
    }

    final roomAsync = ref.watch(roomMetadataProvider(code));

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
      backgroundColor: primaryBg,
      body: roomAsync.when(
        data: (room) {
          if (room == null) return const Center(child: Text('Room not found', style: TextStyle(color: Colors.white)));
          final playersAsync = ref.watch(playersStreamProvider(room.id));

          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 500),
                  child: Column(
                    children: [
                      const Text(
                        'Waiting for Players',
                        style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: accentGold),
                      ),
                      const Text(
                        'Share this code with your friends',
                        style: TextStyle(fontSize: 14, color: Colors.white54),
                      ),
                      const SizedBox(height: 24),
                      
                      // Room Code Card
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 32),
                        decoration: BoxDecoration(
                          color: cardDark,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white10),
                        ),
                        child: Column(
                          children: [
                            Text(
                              code.split('').join('  '),
                              style: const TextStyle(
                                fontSize: 48,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: 8,
                              ),
                            ),
                            const Text('ROOM CODE', style: TextStyle(fontSize: 10, color: accentGold, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),

                      playersAsync.when(
                        data: (players) {
                          final localPlayerId = ref.watch(localPlayerIdProvider);
                          return _buildPlayerGrid(players, localPlayerId);
                        },
                        loading: () => const CircularProgressIndicator(color: accentGold),
                        error: (e, s) => Text('Error: $e', style: const TextStyle(color: Colors.red)),
                      ),
                      
                      const SizedBox(height: 32),
                      _buildInviteLink(context, code),
                      const SizedBox(height: 16),
                      _buildWhatsAppButton(code),
                      const SizedBox(height: 32),

                      // Start Game Button
                      if (room.hostId == ref.read(localPlayerIdProvider))
                        playersAsync.whenData((p) => p.length == 4).value ?? false
                          ? ElevatedButton(
                              onPressed: () => ref.read(lobbyServiceProvider).startGame(room.id),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: accentGold,
                                foregroundColor: primaryBg,
                                minimumSize: const Size(double.infinity, 60),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              ),
                              child: const Text('START GAME', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                            )
                          : Container(
                              width: double.infinity,
                              height: 60,
                              decoration: BoxDecoration(
                                color: accentGold.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: accentGold.withOpacity(0.3)),
                              ),
                              child: Center(
                                child: Text(
                                  'Waiting for all 4 players...',
                                  style: TextStyle(color: accentGold.withOpacity(0.5), fontWeight: FontWeight.bold),
                                ),
                              ),
                            )
                      else
                        const Text('Waiting for host to start...', style: TextStyle(color: Colors.white54, fontStyle: FontStyle.italic)),
                      
                      const SizedBox(height: 24),
                      TextButton.icon(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.arrow_back, color: Colors.white38, size: 16),
                        label: const Text('Leave Room', style: TextStyle(color: Colors.white38)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator(color: accentGold)),
        error: (e, s) => Center(child: Text('Error: $e', style: const TextStyle(color: Colors.white))),
      ),
    );
  }

  Widget _buildPlayerGrid(List<Player> players, String? localPlayerId) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 2.2,
      ),
      itemCount: 4,
      itemBuilder: (context, index) {
        if (index < players.length) {
          final player = players[index];
          final isYou = player.id == localPlayerId;
          return _buildPlayerCard(player.name, player.isHost, isYou);
        } else {
          return _buildWaitingCard();
        }
      },
    );
  }

  Widget _buildPlayerCard(String name, bool isHost, bool isYou) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isYou ? const Color(0xFF1B3321) : cardDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isYou ? Colors.green.withOpacity(0.3) : Colors.white10),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: isYou ? Colors.green.withOpacity(0.2) : Colors.blue.withOpacity(0.2),
            child: Text(name.substring(0, 1).toUpperCase(), style: const TextStyle(color: Colors.white70, fontSize: 14)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14, overflow: TextOverflow.ellipsis),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    if (isHost) _buildBadge('HOST', Colors.amber),
                    if (isHost && isYou) const SizedBox(width: 4),
                    if (isYou) _buildBadge('YOU', Colors.green),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWaitingCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: cardDark.withOpacity(0.4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Row(
        children: [
          Icon(Icons.add_circle_outline, color: Colors.white12, size: 24),
          const SizedBox(width: 10),
          const Text('Waiting...', style: TextStyle(color: Colors.white24, fontStyle: FontStyle.italic)),
        ],
      ),
    );
  }

  Widget _buildBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(color: color, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 0.5),
      ),
    );
  }

  Widget _buildInviteLink(BuildContext context, String code) {
    final url = '${Uri.base.origin}/?code=$code';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('INVITE LINK', style: TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  url.replaceFirst('https://', '').replaceFirst('http://', ''),
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.copy, color: accentGold, size: 20),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: url));
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Link copied!')));
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWhatsAppButton(String code) {
    final message = 'Join my Minus card game room: ${Uri.base.origin}/?code=$code';
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: whatsappGreen,
        foregroundColor: Colors.white,
        minimumSize: const Size(double.infinity, 60),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      onPressed: () => Share.share(message),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.share, size: 20),
          const SizedBox(width: 12),
          const Text('Share via WhatsApp / SMS', style: TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
