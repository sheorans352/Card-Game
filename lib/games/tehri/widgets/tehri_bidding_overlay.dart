import 'package:flutter/material.dart';
import '../../minus/models/card_model.dart';

class TehriBiddingOverlay extends StatefulWidget {
  final int minBid;
  final int currentBid;
  final bool isInitial; // Initial bid by cutter or final bidding
  final Function(int bid, String trump) onBid;

  const TehriBiddingOverlay({
    super.key,
    required this.minBid,
    this.currentBid = 0,
    required this.isInitial,
    required this.onBid,
  });

  @override
  State<TehriBiddingOverlay> createState() => _TehriBiddingOverlayState();
}

class _TehriBiddingOverlayState extends State<TehriBiddingOverlay> {
  int _selectedBid = 7;
  String _selectedSuit = 'S';

  @override
  void initState() {
    super.initState();
    _selectedBid = widget.currentBid > 0 ? widget.currentBid + 1 : widget.minBid;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.9),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.amber.withOpacity(0.5)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            widget.isInitial ? 'SET TRUMP & BID' : 'OVERBID OR PASS',
            style: const TextStyle(color: Colors.amber, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          
          // Bid Selector
          Wrap(
            spacing: 10,
            children: List.generate(7, (index) {
              final bid = index + 7;
              final isEnabled = bid > widget.currentBid;
              return ChoiceChip(
                label: Text(bid.toString()),
                selected: _selectedBid == bid,
                onSelected: isEnabled ? (selected) {
                  setState(() => _selectedBid = bid);
                } : null,
              );
            }),
          ),
          
          const SizedBox(height: 20),
          
          // Suit Selector
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: ['S', 'H', 'D', 'C'].map((suit) {
              return GestureDetector(
                onTap: () => setState(() => _selectedSuit = suit),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _selectedSuit == suit ? Colors.amber.withOpacity(0.2) : Colors.transparent,
                    shape: BoxShape.circle,
                    border: Border.all(color: _selectedSuit == suit ? Colors.amber : Colors.white10),
                  ),
                  child: Text(
                    CardModel.getSuitEmoji(suit),
                    style: const TextStyle(fontSize: 24),
                  ),
                ),
              );
            }).toList(),
          ),
          
          const SizedBox(height: 30),
          
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              if (!widget.isInitial)
                TextButton(
                  onPressed: () => widget.onBid(0, _selectedSuit), // Pass
                  child: const Text('PASS', style: TextStyle(color: Colors.white54)),
                ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.amber, foregroundColor: Colors.black),
                onPressed: () => widget.onBid(_selectedBid, _selectedSuit),
                child: Text(widget.isInitial ? 'SET BID' : 'CONFIRM BID'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
