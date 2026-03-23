import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/card_model.dart';

class BiddingOverlay extends ConsumerStatefulWidget {
  final Function(int bid, Suit? trump) onBidSubmitted;
  final VoidCallback onPass;
  const BiddingOverlay({super.key, required this.onBidSubmitted, required this.onPass});

  @override
  ConsumerState<BiddingOverlay> createState() => _BiddingOverlayState();
}

class _BiddingOverlayState extends ConsumerState<BiddingOverlay> {
  int _selectedBid = 1;
  Suit? _selectedTrump;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Place your Bid',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                onPressed: () => setState(() => _selectedBid = (_selectedBid > 1) ? _selectedBid - 1 : 1),
                icon: const Icon(Icons.remove_circle_outline, color: Colors.white70, size: 32),
              ),
              Container(
                width: 100,
                alignment: Alignment.center,
                child: Text(
                  '$_selectedBid',
                  style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: Colors.amber),
                ),
              ),
              IconButton(
                onPressed: () => setState(() => _selectedBid = (_selectedBid < 13) ? _selectedBid + 1 : 13),
                icon: const Icon(Icons.add_circle_outline, color: Colors.white70, size: 32),
              ),
            ],
          ),
          const SizedBox(height: 24),
          if (_selectedBid >= 5) ...[
            const Text(
              'Select Trump Suit',
              style: TextStyle(fontSize: 16, color: Colors.white70),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: Suit.values.map((suit) {
                final isSelected = _selectedTrump == suit;
                return GestureDetector(
                  onTap: () => setState(() => _selectedTrump = suit),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.amber.withOpacity(0.2) : Colors.transparent,
                      shape: BoxShape.circle,
                      border: Border.all(color: isSelected ? Colors.amber : Colors.white10),
                    ),
                    child: Text(
                      _getSuitEmoji(suit),
                      style: const TextStyle(fontSize: 32),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
          ],
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: widget.onPass,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white70,
                    side: const BorderSide(color: Colors.white10),
                    minimumSize: const Size(0, 60),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Text('PASS'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: (_selectedBid >= 5 && _selectedTrump == null)
                      ? null
                      : () => widget.onBidSubmitted(_selectedBid, _selectedTrump),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber,
                    foregroundColor: Colors.black,
                    minimumSize: const Size(0, 60),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: Text(
                    _selectedBid >= 5 ? 'LOCK TRUMP & BID' : 'BID ${_selectedBid}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _getSuitEmoji(Suit suit) {
    switch (suit) {
      case Suit.spades: return '♠️';
      case Suit.hearts: return '♥️';
      case Suit.diamonds: return '♦️';
      case Suit.clubs: return '♣️';
    }
  }
}
