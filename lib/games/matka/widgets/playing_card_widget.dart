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
            ? [BoxShadow(color: Colors.black54, blurRadius: 16, offset: const Offset(0, 6))]
            : [BoxShadow(color: Colors.black38, blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: cardId == null ? _buildBack() : _buildFace(MatkaCard.fromId(cardId!)),
    );
  }

  Widget _buildBack() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF2D1B69), Color(0xFF1A0D2B)],
          ),
        ),
        child: Center(
          child: Opacity(
            opacity: 0.15,
            child: Text(
              '🂠',
              style: TextStyle(fontSize: width * 0.6, color: Colors.white),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFace(MatkaCard card) {
    final color = card.isRed ? const Color(0xFFE53935) : const Color(0xFF1A1A1A);
    final bgColor = Colors.white;

    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Container(
        color: bgColor,
        padding: const EdgeInsets.all(6),
        child: Stack(
          children: [
            // Top-left rank + suit
            Positioned(
              top: 0,
              left: 2,
              child: Column(
                children: [
                  Text(card.value,
                      style: TextStyle(
                          color: color,
                          fontSize: width * 0.22,
                          fontWeight: FontWeight.bold,
                          height: 1.1)),
                  Text(card.suitSymbol,
                      style: TextStyle(color: color, fontSize: width * 0.18, height: 1, fontFamily: 'sans-serif')),
                ],
              ),
            ),
            // Center suit
            Center(
              child: Text(
                card.suitSymbol,
                style: TextStyle(
                    color: color.withOpacity(0.5), fontSize: width * 0.55, fontFamily: 'sans-serif'),
              ),
            ),
            // Bottom-right rank + suit (rotated)
            Positioned(
              bottom: 0,
              right: 2,
              child: RotatedBox(
                quarterTurns: 2,
                child: Column(
                  children: [
                    Text(card.value,
                        style: TextStyle(
                            color: color,
                            fontSize: width * 0.22,
                            fontWeight: FontWeight.bold,
                            height: 1.1)),
                    Text(card.suitSymbol,
                        style: TextStyle(color: color, fontSize: width * 0.18, height: 1, fontFamily: 'sans-serif')),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
