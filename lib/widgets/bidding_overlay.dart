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
  final bool isScenarioB; // bidding_2 where all passed Phase 1 (trump override at 9+)
  final String? trumpSuit;
  final Function(int bid) onBidSubmitted;
  final Function(Suit suit) onTrumpSelected;
  final VoidCallback onPass;
  
  const BiddingOverlay({
    super.key, 
    this.isRoundTwo = false,
    this.lockedBid,
    this.currentHighBid = 0,
    this.isTrumpSelection = false,
    this.isScenarioB = false,
    this.trumpSuit,
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
    _initializeBid();
  }

  @override
  void didUpdateWidget(covariant BiddingOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If we transition into Round 2 or Scenario B changes, or Trump Selection ends
    if (widget.isRoundTwo != oldWidget.isRoundTwo || 
        widget.isScenarioB != oldWidget.isScenarioB ||
        widget.isTrumpSelection != oldWidget.isTrumpSelection) {
      _initializeBid();
    }
  }

  void _initializeBid() {
    if (widget.isRoundTwo) {
      // Round 2 declarations start at 2 (min trick count is 2)
      _selectedBid = 2;
    } else {
      _selectedBid = widget.lockedBid ?? (widget.currentHighBid == 0 ? 5 : widget.currentHighBid + 1);
    }
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
              // Title
              Text(
                widget.isRoundTwo
                  ? (widget.isScenarioB ? 'FINAL CALL' : 'YOUR CALL')
                  : 'PLACE YOUR BID',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.amber, letterSpacing: 2),
              ),

              // Trump badge — shown in Round 2
              if (widget.isRoundTwo && widget.trumpSuit != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.amber.withOpacity(0.5)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_getTrumpEmoji(widget.trumpSuit!), style: const TextStyle(fontSize: 18)),
                      const SizedBox(width: 8),
                      Text(
                        'Trump: ${_getTrumpName(widget.trumpSuit!)}',
                        style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],

              // Scenario B hint: bid 9+ to change trump
              if (widget.isRoundTwo && widget.isScenarioB) ...[
                const SizedBox(height: 6),
                Text('Bid 9+ to override Trump suit',
                  style: TextStyle(color: Colors.white.withOpacity(0.45), fontSize: 11, fontStyle: FontStyle.italic)),
              ],
              const SizedBox(height: 16),
              
              // Bid Selector (Hide if just selecting trump)
              if (!widget.isTrumpSelection)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildBidControl(Icons.remove, () {
                      gameAudio.playBiddingTick();
                      // Round 2: min 2 (trick declarations). Round 1: min 5 or currentHigh+1
                      final min = widget.isRoundTwo ? 2 : (widget.currentHighBid == 0 ? 5 : widget.currentHighBid + 1);
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
                      const max = 13;
                      setState(() => _selectedBid = (_selectedBid < max) ? _selectedBid + 1 : max);
                    }),
                  ],
                ),

              const SizedBox(height: 16),
              
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
                  // PASS button: only shown in Round 1 (not Round 2, not trump selection)
                  if (!widget.isTrumpSelection && !widget.isRoundTwo)
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
                  if (!widget.isTrumpSelection && !widget.isRoundTwo)
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

  String _getTrumpEmoji(String trumpCode) {
    switch (trumpCode) {
      case 'S': return '♠️';
      case 'H': return '♥️';
      case 'D': return '♦️';
      case 'C': return '♣️';
      default: return '♠️';
    }
  }

  String _getTrumpName(String trumpCode) {
    switch (trumpCode) {
      case 'S': return 'Spades';
      case 'H': return 'Hearts';
      case 'D': return 'Diamonds';
      case 'C': return 'Clubs';
      default: return 'Spades';
    }
  }
}
