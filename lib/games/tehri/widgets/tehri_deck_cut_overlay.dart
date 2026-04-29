import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/tehri_provider.dart';

class TehriDeckCutOverlay extends ConsumerStatefulWidget {
  final String roomId;
  const TehriDeckCutOverlay({super.key, required this.roomId});

  @override
  ConsumerState<TehriDeckCutOverlay> createState() => _TehriDeckCutOverlayState();
}

class _TehriDeckCutOverlayState extends ConsumerState<TehriDeckCutOverlay> {
  static const Color accentCopper = Color(0xFFE67E22);
  static const Color cardDark = Color(0xFF100E1A);
  static const Color accentGold = Color(0xFFE5B84B);

  double _cutPercentage = 0.5;
  bool _isConfirming = false;

  @override
  Widget build(BuildContext context) {
    final roomAsync = ref.watch(tehriRoomProvider(widget.roomId));
    final playersAsync = ref.watch(tehriPlayersProvider(widget.roomId));
    final me = ref.watch(localTehriPlayerProvider(widget.roomId));

    return roomAsync.when(
      data: (room) {
        if (room == null || room.status != 'cutting') return const SizedBox();
        final isCutter = room.cutterId == me?.id;

        // Get cutter name from players list
        final players = playersAsync.value ?? [];
        final cutterPlayer = players.firstWhere(
          (p) => p.id == room.cutterId,
          orElse: () => players.first,
        );
        final cutterName = isCutter ? 'You' : cutterPlayer.name;

        return Align(
          alignment: const Alignment(0, -0.35), // Move up from center
          child: Container(
            width: 380, // More compact on desktop
            margin: const EdgeInsets.symmetric(horizontal: 24),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: cardDark.withOpacity(0.97),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: accentCopper.withOpacity(0.5), width: 1.5),
              boxShadow: [
                BoxShadow(color: accentCopper.withOpacity(0.2), blurRadius: 24, spreadRadius: 4),
                BoxShadow(color: Colors.black.withOpacity(0.6), blurRadius: 12),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'CUT THE DECK',
                  style: TextStyle(
                    color: accentGold,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 4,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  isCutter
                    ? 'Slide to choose your cut point'
                    : 'Waiting for $cutterName to cut the deck...',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.5),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 24),

                if (isCutter) ...[
                  // Compact deck visual
                  SizedBox(
                    height: 100,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Bottom pile
                        Positioned(
                          left: 50,
                          child: Container(
                            width: 70, height: 95,
                            decoration: BoxDecoration(
                              color: const Color(0xFF1A1210),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.white12),
                              boxShadow: [BoxShadow(color: Colors.black54, blurRadius: 6)],
                            ),
                          ),
                        ),
                        // Top pile (cut portion — slides right)
                        AnimatedPositioned(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOut,
                          left: 90 + (_cutPercentage * 50),
                          top: 0,
                          child: Container(
                            width: 70, height: 95,
                            decoration: BoxDecoration(
                              color: const Color(0xFF1A1210),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: accentCopper.withOpacity(0.6), width: 1.5),
                              boxShadow: [BoxShadow(color: accentCopper.withOpacity(0.2), blurRadius: 8)],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Cut position indicator
                  Text(
                    'Cut at card ${(_cutPercentage * 51).round() + 1} / 52',
                    style: const TextStyle(color: Colors.white38, fontSize: 10),
                  ),
                  const SizedBox(height: 12),
                  SliderTheme(
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
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _isConfirming ? null : () async {
                      setState(() => _isConfirming = true);
                      final cutIdx = (_cutPercentage * 51).round();
                      await ref.read(tehriOpsProvider).cutDeck(room.id, cutIdx);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accentCopper,
                      foregroundColor: Colors.black,
                      minimumSize: const Size(double.infinity, 48),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: _isConfirming
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                      : const Text('CONFIRM CUT', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                  ),
                ] else ...[
                  // Non-cutter waiting state — simple spinner + name
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(
                        width: 16, height: 16,
                        child: CircularProgressIndicator(color: accentCopper, strokeWidth: 2),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        '$cutterName is cutting...',
                        style: const TextStyle(color: Colors.white54, fontSize: 12, fontStyle: FontStyle.italic),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      },
      loading: () => const SizedBox(),
      error: (e, s) => const SizedBox(),
    );
  }
}
