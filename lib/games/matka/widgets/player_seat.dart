// Player seat chip in the horizontal row

import 'package:flutter/material.dart';
import '../models/matka_models.dart';

class MatkaPlayerSeat extends StatelessWidget {
  final MatkaPlayer player;
  final bool isActive;  // currently in the hot seat
  final bool isLocalPlayer;

  const MatkaPlayerSeat({
    super.key,
    required this.player,
    this.isActive = false,
    this.isLocalPlayer = false,
  });

  @override
  Widget build(BuildContext context) {
    final Color accent = isActive
        ? const Color(0xFFFFD700)
        : isLocalPlayer
            ? const Color(0xFF9B59B6)
            : Colors.white24;

    final netPositive = player.netChips >= 0;
    final netColor = netPositive ? const Color(0xFF2ECC71) : const Color(0xFFE74C3C);
    final netStr = netPositive ? '+${player.netChips}' : '${player.netChips}';

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.symmetric(horizontal: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isActive
            ? const Color(0xFFFFD700).withOpacity(0.12)
            : Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent, width: isActive ? 1.5 : 0.5),
        boxShadow: isActive
            ? [BoxShadow(color: const Color(0xFFFFD700).withOpacity(0.2), blurRadius: 12)]
            : [],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Active indicator
          if (isActive)
            Container(
              width: 6,
              height: 6,
              margin: const EdgeInsets.only(bottom: 4),
              decoration: const BoxDecoration(
                color: Color(0xFFFFD700),
                shape: BoxShape.circle,
              ),
            ),
          // Name
          Text(
            (isLocalPlayer ? '${player.name} ✦' : player.name).toUpperCase(),
            style: TextStyle(
              color: isActive ? const Color(0xFFFFD700) : Colors.white70,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),
          // Net chips
          Text(
            netStr,
            style: TextStyle(
              color: netColor,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionBadge(String action) {
    String label;
    Color color;
    switch (action) {
      case 'win':
        label = '🏆 WIN';
        color = const Color(0xFF2ECC71);
        break;
      case 'loss':
        label = '❌ LOSS';
        color = const Color(0xFFE74C3C);
        break;
      case 'post':
        label = '🚫 POST';
        color = const Color(0xFFE67E22);
        break;
      case 'pass':
        label = '⏭ PASS';
        color = Colors.white38;
        break;
      default:
        label = action.toUpperCase();
        color = Colors.white24;
    }
    return Text(label, style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.bold));
  }
}
