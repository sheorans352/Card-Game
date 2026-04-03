import 'package:flutter/material.dart';
import 'dart:math' as math;

class WinnerOverlay extends StatefulWidget {
  final String winnerName;
  final VoidCallback onRestart;

  const WinnerOverlay({super.key, required this.winnerName, required this.onRestart});

  @override
  State<WinnerOverlay> createState() => _WinnerOverlayState();
}

class _WinnerOverlayState extends State<WinnerOverlay> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<Particle> _particles = [];
  final math.Random _random = math.Random();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 10))..repeat();
    
    // Generate firecrackers and sparkles
    for (int i = 0; i < 150; i++) {
      _particles.add(Particle(
        color: Colors.primaries[_random.nextInt(Colors.primaries.length)],
        size: _random.nextDouble() * 8 + 4,
        velocity: Offset((_random.nextDouble() - 0.5) * 15, (_random.nextDouble() - 0.5) * 15),
        position: const Offset(0.5, 0.4), // Center area
      ));
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withOpacity(0.9),
      child: Stack(
        children: [
          // Background Graffiti/Colors
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return CustomPaint(
                painter: CelebrationPainter(_particles, _controller.value),
                size: Size.infinite,
              );
            },
          ),
          
          // Main Winner Content
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  '🏆 VICTORY 🏆',
                  style: TextStyle(color: Color(0xFFE5B84B), fontSize: 48, fontWeight: FontWeight.w900, letterSpacing: 4),
                ),
                const SizedBox(height: 24),
                ShaderMask(
                  shaderCallback: (bounds) => const LinearGradient(
                    colors: [Colors.purple, Colors.blue, Colors.green, Colors.yellow, Colors.orange, Colors.red],
                  ).createShader(bounds),
                  child: Text(
                    widget.winnerName.toUpperCase(),
                    style: const TextStyle(color: Colors.white, fontSize: 64, fontWeight: FontWeight.w900),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'IS THE ULTIMATE CHAMPION!',
                  style: TextStyle(color: Colors.white70, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 2),
                ),
                const SizedBox(height: 60),
                ElevatedButton(
                  onPressed: widget.onRestart,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE5B84B),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  ),
                  child: const Text('NEW GAME', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class Particle {
  final Color color;
  final double size;
  final Offset velocity;
  Offset position;
  double life = 1.0;

  Particle({required this.color, required this.size, required this.velocity, required this.position});
}

class CelebrationPainter extends CustomPainter {
  final List<Particle> particles;
  final double progress;
  final math.Random random = math.Random();

  CelebrationPainter(this.particles, this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    for (var p in particles) {
      // Update position
      p.position += p.velocity * 0.01;
      p.life -= 0.002;
      if (p.life <= 0) {
        p.life = 1.0;
        p.position = Offset(random.nextDouble(), random.nextDouble() * 0.5);
      }

      final drawPos = Offset(p.position.dx * size.width, p.position.dy * size.height);
      paint.color = p.color.withOpacity(p.life);
      
      // Draw sparkles/graffiti dots
      canvas.drawCircle(drawPos, p.size * p.life, paint);
      
      // Occasionally draw firecracker "flash"
      if (random.nextDouble() > 0.99) {
        canvas.drawCircle(drawPos, p.size * 5 * p.life, paint..color = Colors.white.withOpacity(0.5));
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
