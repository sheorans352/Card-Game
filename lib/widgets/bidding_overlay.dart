import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/card_model.dart';
import '../services/audio_service.dart';
import 'dart:ui';

class BiddingOverlay extends ConsumerStatefulWidget {
  final bool isRoundTwo;
  final int? lockedBid;
  final int currentHighBid;
  final bool isTrumpSelection;
  final Function(int bid) onBidSubmitted;
  final Function(Suit suit) onTrumpSelected;
  final VoidCallback onPass;
  
  const BiddingOverlay({
    super.key, 
    this.isRoundTwo = false,
    this.lockedBid,
    this.currentHighBid = 0,
    this.isTrumpSelection = false,
    required this.onBidSubmitted, 
    required this.onTrumpSelected,
    required this.onPass,
  });

  @override
  ConsumerState<BiddingOverlay> createState() => _BiddingOverlayState();
}

class _BiddingOverlayState extends ConsumerState<BiddingOverlay> {
  late int _selectedBid;
  Suit? _selectedTrump;

  @override
  void initState() {
    super.initState();
    _selectedBid = widget.lockedBid ?? (widget.currentHighBid == 0 ? 5 : widget.currentHighBid + 1);
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(40)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.85),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
            border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.4),
                blurRadius: 30,
                spreadRadius: 10,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Pull Handle
              Container(
                width: 40, height: 4, 
                decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(height: 24),
              const Text(
                'PLACE YOUR BID',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.amber, letterSpacing: 2),
              ),
              const SizedBox(height: 24),
              
              // Bid Selector (Hide if just selecting trump)
              if (!widget.isTrumpSelection)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildBidControl(Icons.remove, () {
                      gameAudio.playBiddingTick();
                      final min = widget.currentHighBid == 0 ? 5 : widget.currentHighBid + 1;
                      setState(() => _selectedBid = (_selectedBid > min) ? _selectedBid - 1 : min);
                    }),
                    Container(
                      width: 80,
                      alignment: Alignment.center,
                      child: Text(
                        '$_selectedBid',
                        style: const TextStyle(fontSize: 48, fontWeight: FontWeight.w900, color: Colors.white, shadows: [
                          Shadow(color: Colors.amber, blurRadius: 15),
                        ]),
                      ),
                    ),
                    _buildBidControl(Icons.add, () {
                      gameAudio.playBiddingTick();
                      final max = 13;
                      setState(() => _selectedBid = (_selectedBid < max) ? _selectedBid + 1 : max);
                    }),
                  ],
                ),
              
              const SizedBox(height: 24),
              
              // Trump Selector (Only if isTrumpSelection)
              if (widget.isTrumpSelection) ...[
                const Text(
                  'CHOOSE TRUMP SUIT',
                  style: TextStyle(fontSize: 14, color: Colors.white60, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: Suit.values.map((suit) {
                    final isSelected = _selectedTrump == suit;
                    return GestureDetector(
                      onTap: () {
                        gameAudio.playBiddingTick();
                        setState(() => _selectedTrump = suit);
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isSelected ? Colors.amber.withOpacity(0.3) : Colors.white.withOpacity(0.05),
                          shape: BoxShape.circle,
                          border: Border.all(color: isSelected ? Colors.amber : Colors.transparent, width: 2),
                        ),
                        child: Text(
                          _getSuitEmoji(suit),
                          style: const TextStyle(fontSize: 24),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
              ],
                            // Actions
              Row(
                children: [
                  if (!widget.isTrumpSelection)
                    Expanded(
                      child: TextButton(
                        onPressed: widget.onPass,
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.white60,
                          padding: const EdgeInsets.symmetric(vertical: 18),
                        ),
                        child: const Text('PASS', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  if (!widget.isTrumpSelection)
                    const SizedBox(width: 16),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: widget.isTrumpSelection 
                          ? (_selectedTrump == null ? null : () => widget.onTrumpSelected(_selectedTrump!))
                          : () => widget.onBidSubmitted(_selectedBid),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.amber,
                        foregroundColor: Colors.black,
                        elevation: 8,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: Text(
                        widget.isTrumpSelection ? 'SET TRUMP SUIT' : 'BID $_selectedBid',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBidControl(IconData icon, VoidCallback onPressed) {
    return Material(
      color: Colors.white.withOpacity(0.1),
      shape: const CircleBorder(),
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(icon, color: Colors.white, size: 28),
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
