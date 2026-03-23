import 'package:flutter/material.dart';

class DeckCutOverlay extends StatefulWidget {
  final Function(int) onCutConfirmed;

  const DeckCutOverlay({super.key, required this.onCutConfirmed});

  @override
  State<DeckCutOverlay> createState() => _DeckCutOverlayState();
}

class _DeckCutOverlayState extends State<DeckCutOverlay> {
  double _cutPoint = 26;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 100),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.9),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.amber, width: 2),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'CUT THE DECK',
            style: TextStyle(
              color: Colors.amber,
              fontSize: 24,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Choose where to split the deck',
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 32),
          Text(
            '${_cutPoint.round()} Cards',
            style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
          ),
          Slider(
            value: _cutPoint,
            min: 1,
            max: 51,
            divisions: 50,
            activeColor: Colors.amber,
            inactiveColor: Colors.white10,
            onChanged: (val) => setState(() => _cutPoint = val),
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: () => widget.onCutConfirmed(_cutPoint.round()),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('CONFIRM CUT', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
