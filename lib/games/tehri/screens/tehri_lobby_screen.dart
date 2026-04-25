import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:go_router/go_router.dart';
import '../providers/tehri_provider.dart';
import '../models/tehri_models.dart';

class TehriLobbyScreen extends ConsumerWidget {
  final String roomId;
  const TehriLobbyScreen({super.key, required this.roomId});

  static const Color primaryBg = Color(0xFF100806);
  static const Color accentCopper = Color(0xFFE67E22);
  static const Color cardDark = Color(0xFF1A1210);
  static const Color whatsappGreen = Color(0xFF25D366);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionAsync = ref.watch(tehriSessionProvider);
    final roomAsync = ref.watch(tehriRoomProvider(roomId));
    final playersAsync = ref.watch(tehriPlayersProvider(roomId));
    final localPlayerId = ref.watch(localTehriPlayerIdProvider);

    if (sessionAsync.isLoading) {
      return const Scaffold(backgroundColor: primaryBg, body: Center(child: CircularProgressIndicator(color: accentCopper)));
    }

    ref.listen(tehriRoomProvider(roomId), (previous, next) {
      next.whenData((room) {
        if (room != null && room.status != 'waiting') {
          context.go('/tehri/table/$roomId');
        }
      });
    });

    return Scaffold(
      backgroundColor: primaryBg,
      body: roomAsync.when(
        data: (room) {
          if (room == null) return const Center(child: Text('Room not found', style: TextStyle(color: Colors.white)));
          
          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 500),
                  child: Column(
                    children: [
                      const Text('Tehri Lobby',
                        style: TextStyle(fontSize: 36, fontWeight: FontWeight.w900, color: accentCopper, letterSpacing: 2)),
                      const Text('WAITING FOR PLAYERS',
                        style: TextStyle(fontSize: 10, color: Colors.white38, fontWeight: FontWeight.bold, letterSpacing: 2)),
                      
                      const SizedBox(height: 32),
                      
                      // Room Code Card
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 32),
                        decoration: BoxDecoration(
                          color: cardDark,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: accentCopper.withOpacity(0.2)),
                        ),
                        child: Column(
                          children: [
                            Text(
                              room.code.split('').join('  '),
                              style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 8),
                            ),
                            const Text('ROOM CODE', style: TextStyle(fontSize: 10, color: accentCopper, fontWeight: FontWeight.bold, letterSpacing: 2)),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 48),

                      playersAsync.when(
                        data: (players) {
                          final localPlayerId = ref.watch(localTehriPlayerIdProvider);
                          return _buildPlayerGrid(players, localPlayerId);
                        },
                        loading: () => const CircularProgressIndicator(color: accentCopper),
                        error: (e, s) => Text('Error: $e', style: const TextStyle(color: Colors.red)),
                      ),
                      
                      const SizedBox(height: 48),
                      _buildInviteLink(context, room.code),
                      const SizedBox(height: 16),
                      _buildWhatsAppButton(room.code),
                      const SizedBox(height: 40),

                      // Start Game Button
                      if (room.hostId == localPlayerId)
                        playersAsync.whenData((p) => p.length == 4).value ?? false
                          ? ElevatedButton(
                              onPressed: () => ref.read(tehriOpsProvider).startGame(roomId),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: accentCopper,
                                foregroundColor: Colors.black,
                                minimumSize: const Size(double.infinity, 64),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                elevation: 8,
                              ),
                              child: const Text('START GAME', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, letterSpacing: 2)),
                            )
                          : _buildWaitingIndicator()
                      else
                        const Text('Waiting for host to start...', style: TextStyle(color: Colors.white24, fontStyle: FontStyle.italic)),
                      
                      const SizedBox(height: 32),
                      TextButton(
                        onPressed: () => context.go('/tehri'),
                        child: const Text('Leave Room', style: TextStyle(color: Colors.white24)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator(color: accentCopper)),
        error: (e, s) => Center(child: Text('Error: $e', style: const TextStyle(color: Colors.white))),
      ),
    );
  }

  Widget _buildPlayerGrid(List<TehriPlayer> players, String? localPlayerId) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
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
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isYou ? accentCopper.withOpacity(0.1) : cardDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isYou ? accentCopper.withOpacity(0.5) : Colors.white10),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: isYou ? accentCopper : Colors.white10,
            child: Text(name.substring(0, 1).toUpperCase(), style: TextStyle(color: isYou ? Colors.black : Colors.white38)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13), overflow: TextOverflow.ellipsis),
                if (isHost || isYou) const SizedBox(height: 4),
                Row(
                  children: [
                    if (isHost) _buildBadge('HOST', Colors.orange),
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
      decoration: BoxDecoration(
        color: cardDark.withOpacity(0.4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: const Center(child: Text('Waiting...', style: TextStyle(color: Colors.white12, fontSize: 12))),
    );
  }

  Widget _buildBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(color: color.withOpacity(0.2), borderRadius: BorderRadius.circular(4)),
      child: Text(text, style: TextStyle(color: color, fontSize: 7, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildInviteLink(BuildContext context, String code) {
    final url = '${Uri.base.origin}/?game=tehri&code=$code';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: cardDark, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white10)),
      child: Row(
        children: [
          Expanded(child: Text(url, style: const TextStyle(color: Colors.white38, fontSize: 11), overflow: TextOverflow.ellipsis)),
          IconButton(
            icon: const Icon(Icons.copy, color: accentCopper, size: 20),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: url));
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Link copied!')));
            },
          ),
        ],
      ),
    );
  }

  Widget _buildWhatsAppButton(String code) {
    final message = 'Join my Tehri game room: ${Uri.base.origin}/?game=tehri&code=$code';
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: whatsappGreen,
        foregroundColor: Colors.white,
        minimumSize: const Size(double.infinity, 60),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      onPressed: () => Share.share(message),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.share, size: 20),
          SizedBox(width: 12),
          Text('INVITE FRIENDS', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
        ],
      ),
    );
  }

  Widget _buildWaitingIndicator() {
    return Container(
      width: double.infinity,
      height: 64,
      decoration: BoxDecoration(
        color: accentCopper.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accentCopper.withOpacity(0.2)),
      ),
      child: const Center(child: Text('Need 4 players to start', style: TextStyle(color: Colors.white24, fontWeight: FontWeight.bold))),
    );
  }
}
