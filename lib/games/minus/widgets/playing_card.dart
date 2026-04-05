import 'package:flutter/material.dart';
import '../../../games/minus/models/card_model.dart';

class PlayingCard extends StatelessWidget {
  final CardModel? card;
  final bool isFaceUp;
  final double width;
  final double height;
  final VoidCallback? onTap;
  final bool isPlayable;

  static const Color accentGold = Color(0xFFC7A14C);
  static const Color cardDark = Color(0xFF141414);

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
    final color = isRed ? const Color(0xFFB71C1C) : const Color(0xFF212121);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: isFaceUp ? Colors.white : cardDark,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.4),
              blurRadius: 6,
              offset: const Offset(2, 4),
            ),
          ],
          border: Border.all(
            color: isFaceUp ? Colors.black12 : accentGold.withOpacity(0.5), 
            width: isFaceUp ? 0.5 : 1.5
          ),
        ),
        child: isFaceUp ? _buildFront(color) : _buildBack(),
      ),
    );
  }

  Widget _buildFront(Color color) {
    if (card == null) return const SizedBox();

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white, Colors.grey.shade100],
        ),
      ),
      child: Stack(
        children: [
          // Corner indicators
          Positioned(
            top: 6,
            left: 6,
            child: Column(
              children: [
                Text(
                  card!.value,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w900,
                    fontSize: width * 0.22,
                    height: 1,
                  ),
                ),
                Text(
                  _getSuitEmoji(card!.suit.code),
                  style: TextStyle(fontSize: width * 0.18, color: color),
                ),
              ],
            ),
          ),
          // Center Large Suit (Premium Faint Pattern)
          Center(
            child: Text(
              _getSuitEmoji(card!.suit.code),
              style: TextStyle(
                fontSize: width * 0.5,
                color: color.withOpacity(0.08),
              ),
            ),
          ),
          // Bottom rotated indicators
          Positioned(
            bottom: 6,
            right: 6,
            child: RotatedBox(
              quarterTurns: 2,
              child: Column(
                children: [
                  Text(
                    card!.value,
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w900,
                      fontSize: width * 0.22,
                      height: 1,
                    ),
                  ),
                  Text(
                    _getSuitEmoji(card!.suit.code),
                    style: TextStyle(fontSize: width * 0.18, color: color),
                  ),
                ],
              ),
            ),
          ),
          // Add subtle gold border for face cards or high cards (Ace, King, Queen, Jack)
          if (['A', 'K', 'Q', 'J'].contains(card!.value))
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: accentGold.withOpacity(0.2), width: 2),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBack() {
    return Container(
      margin: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: accentGold.withOpacity(0.2)),
      ),
      child: Stack(
        children: [
          CustomPaint(
            size: Size(width, height),
            painter: CardBackPainter(accentGold.withOpacity(0.1)),
          ),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.auto_awesome, color: accentGold.withOpacity(0.3), size: width * 0.4),
                const SizedBox(height: 4),
                Text(
                  'MINUS',
                  style: TextStyle(
                    color: accentGold.withOpacity(0.3),
                    fontSize: width * 0.12,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                  ),
                ),
              ],
            ),
          ),
        ],
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
  final Color patternColor;
  CardBackPainter(this.patternColor);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = patternColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;

    const spacing = 8.0;
    for (double i = -size.height; i < size.width; i += spacing) {
      canvas.drawLine(Offset(i, 0), Offset(i + size.height, size.height), paint);
    }
    for (double i = 0; i < size.width + size.height; i += spacing) {
      canvas.drawLine(Offset(i, 0), Offset(i - size.height, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
