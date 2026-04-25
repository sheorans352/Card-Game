import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/tehri_provider.dart';
import '../models/tehri_models.dart';

class TehriDeckCutOverlay extends ConsumerStatefulWidget {
  final String roomId;
  const TehriDeckCutOverlay({super.key, required this.roomId});

  @override
  ConsumerState<TehriDeckCutOverlay> createState() => _TehriDeckCutOverlayState();
}

class _TehriDeckCutOverlayState extends ConsumerState<TehriDeckCutOverlay> {
  static const Color primaryBg = Color(0xFF100806);
  static const Color accentCopper = Color(0xFFE67E22);
  static const Color cardDark = Color(0xFF1A1210);

  double _cutPercentage = 0.5;
  bool _isConfirming = false;

  @override
  Widget build(BuildContext context) {
    final roomAsync = ref.watch(tehriRoomProvider(widget.roomId));
    final me = ref.watch(localTehriPlayerProvider(widget.roomId));

    return roomAsync.when(
      data: (room) {
        if (room == null || room.status != 'cutting') return const SizedBox();
        final isCutter = room.cutterId == me?.id;

        return Container(
          color: Colors.black.withOpacity(0.9),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'CUT THE DECK',
                style: TextStyle(
                  color: accentCopper,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 6,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                isCutter ? 'SLIDE TO CHOOSE YOUR CUT' : 'WAITING FOR CUTTER...',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.4),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 60),
              
              // Animated Deck Visual
              SizedBox(
                height: 240,
                width: 320,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Bottom half
                    Transform(
                      transform: Matrix4.identity()
                        ..setEntry(3, 2, 0.001)
                        ..rotateX(-0.3),
                      child: Container(
                        width: 150,
                        height: 200,
                        decoration: BoxDecoration(
                          color: cardDark,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white10, width: 1),
                          boxShadow: [
                            BoxShadow(color: Colors.black, blurRadius: 20, offset: const Offset(10, 10)),
                          ],
                        ),
                        child: _buildCardBackPattern(),
                      ),
                    ),
                    // Top half (Animated cut)
                    AnimatedPositioned(
                      duration: const Duration(milliseconds: 400),
                      curve: Curves.easeOutCubic,
                      left: 85 + (_cutPercentage * 60),
                      top: 15 - (_cutPercentage * 30),
                      child: Transform(
                        transform: Matrix4.identity()
                          ..setEntry(3, 2, 0.001)
                          ..rotateX(-0.3)
                          ..rotateZ(0.08 * _cutPercentage),
                        child: Container(
                          width: 150,
                          height: 200,
                          decoration: BoxDecoration(
                            color: cardDark,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: accentCopper.withOpacity(0.5), width: 1.5),
                            boxShadow: [
                              BoxShadow(color: Colors.black87, blurRadius: 15, offset: const Offset(-5, 5)),
                              if (isCutter) BoxShadow(color: accentCopper.withOpacity(0.2), blurRadius: 10, spreadRadius: 1),
                            ],
                          ),
                          child: _buildCardBackPattern(isTop: true),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 80),
              
              if (isCutter) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 60),
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: accentCopper,
                      inactiveTrackColor: Colors.white10,
                      thumbColor: accentCopper,
                      overlayColor: accentCopper.withOpacity(0.2),
                    ),
                    child: Slider(
                      value: _cutPercentage,
                      onChanged: _isConfirming ? null : (val) => setState(() => _cutPercentage = val),
                    ),
                  ),
                ),
                const SizedBox(height: 40),
                ElevatedButton(
                  onPressed: _isConfirming ? null : () async {
                    setState(() => _isConfirming = true);
                    final cutIdx = (_cutPercentage * 51).round();
                    await ref.read(tehriOpsProvider).cutDeck(room.id, cutIdx);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accentCopper,
                    foregroundColor: Colors.black,
                    minimumSize: const Size(240, 56),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                  ),
                  child: _isConfirming 
                    ? const CircularProgressIndicator(color: Colors.black)
                    : const Text('CONFIRM CUT', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 2)),
                ),
              ] else ...[
                const CircularProgressIndicator(color: accentCopper, strokeWidth: 2),
                const SizedBox(height: 20),
                const Text('Waiting for cutter...', style: TextStyle(color: Colors.white24, fontStyle: FontStyle.italic)),
              ],
            ],
          ),
        );
      },
      loading: () => const SizedBox(),
      error: (e, s) => const SizedBox(),
    );
  }

  Widget _buildCardBackPattern({bool isTop = false}) {
    return Opacity(
      opacity: isTop ? 0.3 : 0.15,
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.style, color: accentCopper, size: 40),
            SizedBox(height: 10),
            Text('TEHRI', style: TextStyle(color: accentCopper, fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 4)),
          ],
        ),
      ),
    );
  }
}
