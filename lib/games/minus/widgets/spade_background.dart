import 'package:flutter/material.dart';

class SpadeBackground extends StatelessWidget {
  const SpadeBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
        ),
      ),
      child: Opacity(
        opacity: 0.03,
        child: Center(
          child: Transform.scale(
            scale: 2.0,
            child: const Text('♠', style: TextStyle(fontSize: 400)),
          ),
        ),
      ),
    );
  }
}
