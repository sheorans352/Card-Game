// Animated pot display widget for Matka

import 'package:flutter/material.dart';

class MatkaPotDisplay extends StatelessWidget {
  final int potAmount;
  final int anteAmount;

  const MatkaPotDisplay({
    super.key,
    required this.potAmount,
    required this.anteAmount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFFFFD700).withOpacity(0.12),
            const Color(0xFF9B59B6).withOpacity(0.08),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFFFD700).withOpacity(0.35)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            '💰  POT',
            style: TextStyle(
              color: Colors.white38,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 3,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            potAmount.toString(),
            style: const TextStyle(
              color: Color(0xFFFFD700),
              fontSize: 38,
              fontWeight: FontWeight.w900,
              letterSpacing: 2,
            ),
          ),
          Text(
            'Ante: $anteAmount per round',
            style: const TextStyle(color: Colors.white24, fontSize: 10),
          ),
        ],
      ),
    );
  }
}
