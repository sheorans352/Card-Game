import 'package:flutter/material.dart';
import '../models/card_model.dart';

class PlayingCard extends StatelessWidget {
  final CardModel? card;
  final bool isFaceUp;
  final double width;
  final double height;
  final VoidCallback? onTap;

  final bool isPlayable;

  const PlayingCard({
    super.key,
    this.card,
    this.isFaceUp = true,
    this.width = 60,
    this.height = 90,
    this.onTap,
    this.isPlayable = true,
  });

  @override
  Widget build(BuildContext context) {
    final bool isRed = card?.suit.code == 'H' || card?.suit.code == 'D';
    final color = isRed ? Colors.red.shade900 : Colors.black;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: isFaceUp ? Colors.white : const Color(0xFF1A237E), // Deep Blue Card Back
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 4,
              offset: const Offset(2, 2),
            ),
          ],
          border: Border.all(color: Colors.white24, width: 0.5),
        ),
        child: isFaceUp ? _buildFront(color) : _buildBack(),
      ),
    );
  }

  Widget _buildFront(Color color) {
    if (card == null) return const SizedBox();

    return Stack(
      children: [
        // Corner indicators
        Positioned(
          top: 4,
          left: 4,
          child: Column(
            children: [
              Text(
                card!.value,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: width * 0.2,
                  height: 1,
                ),
              ),
              Text(
                _getSuitEmoji(card!.suit.code),
                style: TextStyle(fontSize: width * 0.15),
              ),
            ],
          ),
        ),
        // Center Large Suit
        Center(
          child: Text(
            _getSuitEmoji(card!.suit.code),
            style: TextStyle(
              fontSize: width * 0.5,
              color: color.withOpacity(0.35),
            ),
          ),
        ),
        // Bottom rotated indicators
        Positioned(
          bottom: 4,
          right: 4,
          child: RotatedBox(
            quarterTurns: 2,
            child: Column(
              children: [
                Text(
                  card!.value,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: width * 0.25,
                    height: 1,
                  ),
                ),
                Text(
                  _getSuitEmoji(card!.suit.code),
                  style: TextStyle(fontSize: width * 0.22),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBack() {
    return Container(
      margin: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFF283593),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.white10),
      ),
      child: CustomPaint(
        painter: CardBackPainter(),
        child: const Center(
          child: Icon(Icons.ac_unit, color: Colors.white12, size: 24),
        ),
      ),
    );
  }

  String _getSuitEmoji(String code) {
    switch (code) {
      case 'S': return '♠';
      case 'H': return '♥';
      case 'D': return '♦';
      case 'C': return '♣';
      default: return '';
    }
  }
}

class CardBackPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.05)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    const spacing = 10.0;
    for (double i = 0; i < size.width + size.height; i += spacing) {
      canvas.drawLine(Offset(i, 0), Offset(0, i), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
