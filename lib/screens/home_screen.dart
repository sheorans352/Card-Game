import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/room_provider.dart';
import 'lobby_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _nameController = TextEditingController();
  final _codeController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    // Sync Room Code from URL if available
    ref.listen<String?>(currentRoomCodeProvider, (previous, next) {
      if (next != null && next != _codeController.text) {
        _codeController.text = next;
      }
    });

    return Scaffold(
      body: Stack(
        children: [
          const SpadeBackground(),
          Center(
            child: Container(
              padding: const EdgeInsets.all(32),
              constraints: const BoxConstraints(maxWidth: 400),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.8),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white10),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                   const Text(
                    'MINUS',
                    style: TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 8,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 32),
                  TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Your Name',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () async {
                      if (_nameController.text.isEmpty) return;
                      final result = await ref.read(lobbyServiceProvider).createRoom(_nameController.text);
                      ref.read(currentRoomCodeProvider.notifier).state = result['roomCode'];
                      ref.read(localPlayerIdProvider.notifier).state = result['playerId'];
                      if (context.mounted) {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (context) => const LobbyScreen()),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 50),
                    ),
                    child: const Text('Host Game'),
                  ),
                  const SizedBox(height: 16),
                  const Divider(color: Colors.white24),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _codeController,
                    decoration: const InputDecoration(
                      labelText: 'Room Code',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton(
                    onPressed: () async {
                      if (_nameController.text.isEmpty || _codeController.text.isEmpty) return;
                      final result = await ref.read(lobbyServiceProvider).joinRoom(_codeController.text, _nameController.text);
                      if (result != null) {
                        ref.read(currentRoomCodeProvider.notifier).state = _codeController.text;
                        ref.read(localPlayerIdProvider.notifier).state = result['playerId'];
                        if (context.mounted) {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (context) => const LobbyScreen()),
                          );
                        }
                      } else {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Invalid Room Code')),
                          );
                        }
                      }
                    },
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 50),
                    ),
                    child: const Text('Join Game'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class SpadeBackground extends StatelessWidget {
  const SpadeBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF121212),
      child: CustomPaint(
        painter: _SpadePainter(),
        child: Container(),
      ),
    );
  }
}

class _SpadePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.03)
      ..style = PaintingStyle.fill;

    const spacing = 80.0;
    for (double x = 0; x < size.width; x += spacing) {
      for (double y = 0; y < size.height; y += spacing) {
        _drawSpade(canvas, Offset(x + (y % (spacing * 2) == 0 ? 0 : spacing / 2), y), 20, paint);
      }
    }
  }

  void _drawSpade(Canvas canvas, Offset center, double size, Paint paint) {
    final path = Path();
    // Simplified spade shape
    path.moveTo(center.dx, center.dy - size / 2);
    path.cubicTo(center.dx + size / 2, center.dy - size / 2, center.dx + size / 2, center.dy, center.dx, center.dy + size / 3);
    path.cubicTo(center.dx - size / 2, center.dy, center.dx - size / 2, center.dy - size / 2, center.dx, center.dy - size / 2);
    
    // Stem
    path.moveTo(center.dx, center.dy + size / 4);
    path.lineTo(center.dx - size / 8, center.dy + size / 2);
    path.lineTo(center.dx + size / 8, center.dy + size / 2);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
