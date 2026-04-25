import 'package:flutter/material.dart';
import '../../minus/models/card_model.dart';

class TehriBiddingOverlay extends StatefulWidget {
  final int minBid;
  final int currentBid;
  final bool isInitial;
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

class _TehriBiddingOverlayState extends State<TehriBiddingOverlay>
    with SingleTickerProviderStateMixin {
  late int _selectedBid;
  String _selectedSuit = 'S';
  bool _submitted = false;
  late AnimationController _slideCtrl;
  late Animation<Offset> _slideAnim;

  static const Color accentGold = Color(0xFFE5B84B);
  static const Color cardDark = Color(0xFF100E1A);

  @override
  void initState() {
    super.initState();
    _selectedBid = widget.currentBid > 0 ? widget.currentBid + 1 : widget.minBid;
    _slideCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _slideAnim = Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
        .animate(CurvedAnimation(parent: _slideCtrl, curve: Curves.easeOutCubic));
    _slideCtrl.forward();
  }

  @override
  void dispose() {
    _slideCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 64, left: 0, right: 0,
      child: SlideTransition(
        position: _slideAnim,
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          decoration: BoxDecoration(
            color: cardDark,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(color: accentGold.withOpacity(0.4)),
            boxShadow: [
              BoxShadow(color: accentGold.withOpacity(0.15), blurRadius: 20, spreadRadius: 2),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle
              Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: Colors.white12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 12),

              Text(
                widget.isInitial ? 'SET TRUMP & BID' : 'OVERBID OR PASS',
                style: const TextStyle(
                  color: accentGold,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 16),

              // Bid Chips
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: List.generate(7, (index) {
                  final bid = index + 7;
                  final isEnabled = bid > widget.currentBid;
                  final isSelected = _selectedBid == bid;
                  return GestureDetector(
                    onTap: isEnabled && !_submitted ? () => setState(() => _selectedBid = bid) : null,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: 44, height: 44,
                      decoration: BoxDecoration(
                        color: isSelected ? accentGold : Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                          color: isSelected ? accentGold : Colors.white10,
                          width: isSelected ? 2 : 1,
                        ),
                        boxShadow: isSelected
                          ? [BoxShadow(color: accentGold.withOpacity(0.4), blurRadius: 8)]
                          : [],
                      ),
                      child: Center(
                        child: Text(
                          bid.toString(),
                          style: TextStyle(
                            color: isSelected ? Colors.black : (isEnabled ? Colors.white70 : Colors.white24),
                            fontWeight: FontWeight.w900,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),

              const SizedBox(height: 16),

              // Suit Selector
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: ['S', 'H', 'D', 'C'].map((suit) {
                  final isSelected = _selectedSuit == suit;
                  final isRed = suit == 'H' || suit == 'D';
                  return GestureDetector(
                    onTap: _submitted ? null : () => setState(() => _selectedSuit = suit),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      decoration: BoxDecoration(
                        color: isSelected
                          ? (isRed ? Colors.red.withOpacity(0.2) : Colors.white.withOpacity(0.1))
                          : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected ? (isRed ? Colors.red : Colors.white54) : Colors.white10,
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Text(
                        CardModel.getSuitEmoji(suit),
                        style: const TextStyle(fontSize: 28),
                      ),
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: 20),

              // Action Buttons
              Row(
                children: [
                  if (!widget.isInitial) ...[
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _submitted ? null : () {
                          setState(() => _submitted = true);
                          widget.onBid(0, _selectedSuit);
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white38,
                          side: const BorderSide(color: Colors.white10),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('PASS'),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: _submitted ? null : () {
                        setState(() => _submitted = true);
                        widget.onBid(_selectedBid, _selectedSuit);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accentGold,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _submitted
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                        : Text(
                            widget.isInitial ? 'CONFIRM BID' : 'OVERBID',
                            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
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
}
