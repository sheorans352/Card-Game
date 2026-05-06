import 'package:flutter/material.dart';
import '../../../games/minus/models/card_model.dart';

class PlayingCard extends StatelessWidget {
  final CardModel? card;
  final bool isFaceUp;
  final double width;
  final double height;
  final VoidCallback? onTap;
  final bool isPlayable;
  final bool isDimmed;

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
    this.isDimmed = false,
  });

  @override
  Widget build(BuildContext context) {
    final bool isRed = card?.suit.code == 'H' || card?.suit.code == 'D';
    final color = isRed ? const Color(0xFFB71C1C) : const Color(0xFF212121);

    return GestureDetector(
      onTapDown: onTap != null ? (_) => onTap!() : null,
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
    final String val = card!.value;
    final String suit = card!.suit.code;

    final bool isRed = suit == 'H' || suit == 'D';
    final Color color = isRed ? const Color(0xFFE53935) : const Color(0xFF000000); // Vibrant Red and True Black

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDimmed 
            ? [Colors.grey.shade50, Colors.grey.shade100] 
            : [Colors.white, const Color(0xFFF9F9F9)],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDimmed ? 0.05 : 0.15),
            blurRadius: 3,
            offset: const Offset(0, 1.5),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Corner indicators
          Positioned(
            top: 4, left: 5,
            child: _buildCornerInfo(val, suit, color, isDimmed),
          ),
          Positioned(
            bottom: 4, right: 5,
            child: RotatedBox(quarterTurns: 2, child: _buildCornerInfo(val, suit, color, isDimmed)),
          ),

          // Main Center Content
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 26),
            child: Center(child: _buildMainContent(val, suit, color, isDimmed)),
          ),

          // Brightened gold border for face cards
          if (['A', 'K', 'Q', 'J'].contains(val))
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFFFD700).withOpacity(0.3), width: 1.5),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCornerInfo(String val, String suit, Color color, bool isDimmed) {
    final displayColor = isDimmed ? color.withOpacity(0.4) : color;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          val,
          style: TextStyle(
            color: displayColor,
            fontWeight: FontWeight.w900,
            fontSize: width * 0.2,
            height: 1,
            shadows: isDimmed ? null : [Shadow(color: Colors.black.withOpacity(0.05), offset: const Offset(0.5, 0.5), blurRadius: 0.5)],
          ),
        ),
        Text(
          _getSuitEmoji(suit),
          style: TextStyle(
            fontSize: width * 0.15, 
            color: displayColor, 
            fontWeight: FontWeight.w900,
            shadows: isDimmed ? null : [Shadow(color: Colors.black.withOpacity(0.05), offset: const Offset(0.5, 0.5), blurRadius: 0.5)],
          ),
        ),
      ],
    );
  }

  Widget _buildMainContent(String val, String suit, Color color, bool isDimmed) {
    final displayColor = isDimmed ? color.withOpacity(0.4) : color;
    final shadows = isDimmed ? null : [Shadow(color: Colors.black.withOpacity(0.08), offset: const Offset(1, 1), blurRadius: 1)];
    
    // Aces and Face Cards (J, Q, K) use the "Old Style" Large Center Suit
    if (['A', 'J', 'Q', 'K'].contains(val)) {
      return Text(
        _getSuitEmoji(suit), 
        style: TextStyle(
          fontSize: width * 0.48, 
          color: displayColor,
          fontWeight: FontWeight.w900,
          shadows: shadows,
        )
      );
    }

    // Pips for 2-10
    final int count = int.tryParse(val) ?? 0;
    return _buildPips(count, suit, displayColor, shadows);
  }

  Widget _buildPips(int count, String suit, Color color, List<Shadow>? shadows) {
    final emoji = _getSuitEmoji(suit);
    final style = TextStyle(fontSize: width * 0.16, color: color, fontWeight: FontWeight.w900, shadows: shadows);

    switch (count) {
      case 2:
        return Column(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(emoji, style: style), Text(emoji, style: style)]);
      case 3:
        return Column(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(emoji, style: style), Text(emoji, style: style), Text(emoji, style: style)]);
      case 4:
        return Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(emoji, style: style), Text(emoji, style: style)]),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(emoji, style: style), Text(emoji, style: style)]),
          ],
        );
      case 5:
        return Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(emoji, style: style), Text(emoji, style: style)]),
            Text(emoji, style: style),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(emoji, style: style), Text(emoji, style: style)]),
          ],
        );
      case 6:
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(emoji, style: style), Text(emoji, style: style), Text(emoji, style: style)]),
            Column(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(emoji, style: style), Text(emoji, style: style), Text(emoji, style: style)]),
          ],
        );
      case 7:
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(emoji, style: style), Text(emoji, style: style), Text(emoji, style: style)]),
            Text(emoji, style: style),
            Column(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(emoji, style: style), Text(emoji, style: style), Text(emoji, style: style)]),
          ],
        );
      case 8:
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(emoji, style: style), Text(emoji, style: style), Text(emoji, style: style), Text(emoji, style: style)]),
            Column(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(emoji, style: style), Text(emoji, style: style), Text(emoji, style: style), Text(emoji, style: style)]),
          ],
        );
      case 9:
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(emoji, style: style), Text(emoji, style: style), Text(emoji, style: style), Text(emoji, style: style)]),
            Text(emoji, style: style),
            Column(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(emoji, style: style), Text(emoji, style: style), Text(emoji, style: style), Text(emoji, style: style)]),
          ],
        );
      case 10:
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(emoji, style: style), Text(emoji, style: style), Text(emoji, style: style), Text(emoji, style: style)]),
            Column(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [Text(emoji, style: style), Text(emoji, style: style)]),
            Column(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(emoji, style: style), Text(emoji, style: style), Text(emoji, style: style), Text(emoji, style: style)]),
          ],
        );
      default:
        return Text(emoji, style: style);
    }
  }

  Widget _buildBack() {
    return Container(
      margin: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: accentGold.withOpacity(0.3), width: 1),
      ),
      child: Stack(
        children: [
          CustomPaint(
            size: Size(width, height),
            painter: CardBackPainter(accentGold.withOpacity(0.08)),
          ),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.diamond_rounded, color: accentGold.withOpacity(0.4), size: width * 0.3),
                const SizedBox(height: 8),
                Text(
                  'CASINO\nDELIGHT',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: accentGold.withOpacity(0.6),
                    fontSize: width * 0.1,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'dukankidukan.in',
                  style: TextStyle(
                    color: accentGold.withOpacity(0.3),
                    fontSize: width * 0.06,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.5,
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

    const spacing = 10.0;
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
