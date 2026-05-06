// Matka playing card widget — standalone, no Minus dependencies

import 'package:flutter/material.dart';
import '../models/card_model.dart';

class MatkaPlayingCard extends StatelessWidget {
  final String? cardId; // null = face-down
  final double width;
  final double height;
  final bool elevated;

  const MatkaPlayingCard({
    super.key,
    this.cardId,
    this.width = 72,
    this.height = 100,
    this.elevated = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        boxShadow: elevated
            ? [BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 12, offset: const Offset(0, 4))]
            : [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: cardId == null ? _buildBack() : _buildFace(MatkaCard.fromId(cardId!)),
    );
  }

  Widget _buildBack() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFC7A14C).withOpacity(0.3), width: 1.5),
      ),
      child: Stack(
        children: [
          CustomPaint(
            size: Size(width, height),
            painter: CardBackPainter(const Color(0xFFC7A14C).withOpacity(0.08)),
          ),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.diamond_rounded, color: const Color(0xFFC7A14C).withOpacity(0.4), size: width * 0.3),
                const SizedBox(height: 8),
                Text(
                  'CASINO\nDELIGHT',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: const Color(0xFFC7A14C).withOpacity(0.6),
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
                    color: const Color(0xFFC7A14C).withOpacity(0.3),
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

  Widget _buildFace(MatkaCard card) {
    final color = card.isRed ? const Color(0xFFE53935) : const Color(0xFF000000);
    final val = card.value;
    final suit = card.suitSymbol;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white, const Color(0xFFF9F9F9)],
        ),
      ),
      child: Stack(
        children: [
          // Corner indicators
          Positioned(
            top: 4, left: 6,
            child: _buildCornerInfo(val, suit, color),
          ),
          Positioned(
            bottom: 4, right: 6,
            child: RotatedBox(quarterTurns: 2, child: _buildCornerInfo(val, suit, color)),
          ),

          // Main Center Content
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 24),
            child: Center(child: _buildMainContent(val, suit, color)),
          ),

          // Subtle gold border for face cards
          if (['A', 'K', 'Q', 'J'].contains(val))
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFFD700).withOpacity(0.25), width: 1.5),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCornerInfo(String val, String suit, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(val,
            style: TextStyle(
              color: color,
              fontSize: width * 0.22,
              fontWeight: FontWeight.w900,
              height: 1,
              shadows: [Shadow(color: Colors.black.withOpacity(0.05), offset: const Offset(0.5, 0.5), blurRadius: 0.5)],
            )),
        Text(suit,
            style: TextStyle(
              color: color, 
              fontSize: width * 0.18, 
              height: 1, 
              fontFamily: 'sans-serif',
              shadows: [Shadow(color: Colors.black.withOpacity(0.05), offset: const Offset(0.5, 0.5), blurRadius: 0.5)],
            )),
      ],
    );
  }

  Widget _buildMainContent(String val, String suit, Color color) {
    final shadows = [Shadow(color: Colors.black.withOpacity(0.08), offset: const Offset(1, 1), blurRadius: 1)];
    
    if (['A', 'J', 'Q', 'K'].contains(val)) {
      return Text(suit,
          style: TextStyle(
            color: color, 
            fontSize: width * 0.55, 
            fontFamily: 'sans-serif',
            fontWeight: FontWeight.w900,
            shadows: shadows,
          ));
    }

    final int count = int.tryParse(val) ?? 0;
    return _buildPips(count, suit, color, shadows);
  }

  Widget _buildPips(int count, String suit, Color color, List<Shadow>? shadows) {
    final style = TextStyle(fontSize: width * 0.18, color: color, fontWeight: FontWeight.w900, shadows: shadows);

    switch (count) {
      case 2:
        return Column(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(suit, style: style), Text(suit, style: style)]);
      case 3:
        return Column(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(suit, style: style), Text(suit, style: style), Text(suit, style: style)]);
      case 4:
        return Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(suit, style: style), Text(suit, style: style)]),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(suit, style: style), Text(suit, style: style)]),
          ],
        );
      case 5:
        return Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(suit, style: style), Text(suit, style: style)]),
            Text(suit, style: style),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(suit, style: style), Text(suit, style: style)]),
          ],
        );
      case 6:
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(suit, style: style), Text(suit, style: style), Text(suit, style: style)]),
            Column(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(suit, style: style), Text(suit, style: style), Text(suit, style: style)]),
          ],
        );
      case 7:
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(suit, style: style), Text(suit, style: style), Text(suit, style: style)]),
            Text(suit, style: style),
            Column(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(suit, style: style), Text(suit, style: style), Text(suit, style: style)]),
          ],
        );
      case 8:
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(suit, style: style), Text(suit, style: style), Text(suit, style: style), Text(suit, style: style)]),
            Column(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(suit, style: style), Text(suit, style: style), Text(suit, style: style), Text(suit, style: style)]),
          ],
        );
      case 9:
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(suit, style: style), Text(suit, style: style), Text(suit, style: style), Text(suit, style: style)]),
            Text(suit, style: style),
            Column(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(suit, style: style), Text(suit, style: style), Text(suit, style: style), Text(suit, style: style)]),
          ],
        );
      case 10:
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(suit, style: style), Text(suit, style: style), Text(suit, style: style), Text(suit, style: style)]),
            Column(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [Text(suit, style: style), Text(suit, style: style)]),
            Column(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(suit, style: style), Text(suit, style: style), Text(suit, style: style), Text(suit, style: style)]),
          ],
        );
      default:
        return Text(suit, style: style);
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
