import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../games/minus/providers/room_provider.dart';
import '../../../shared/services/audio_service.dart';

class DeckCutOverlay extends ConsumerStatefulWidget {
  const DeckCutOverlay({super.key});

  @override
  ConsumerState<DeckCutOverlay> createState() => _DeckCutOverlayState();
}

class _DeckCutOverlayState extends ConsumerState<DeckCutOverlay> {
  static const Color primaryBg = Color(0xFF0B2111);
  static const Color accentGold = Color(0xFFC7A14C);
  static const Color cardDark = Color(0xFF141414);

  double _cutPercentage = 0.5;
  bool _isConfirming = false;

  @override
  Widget build(BuildContext context) {
    final roomCode = ref.watch(currentRoomCodeProvider);
    if (roomCode == null) return const SizedBox();

    final roomAsync = ref.watch(roomMetadataProvider(roomCode));
    final isCutter = ref.watch(isCutterProvider(roomCode));

    return roomAsync.when(
      data: (room) {
        if (room == null || room.currentPhase != 'cutting') return const SizedBox();

        return Container(
          color: Colors.black.withOpacity(0.85),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'CUT THE DECK',
                style: TextStyle(
                  color: accentGold,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 6,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                isCutter ? 'SLIDE TO CHOOSE YOUR CUT' : 'WAITING FOR OPONENT TO CUT...',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.4),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 60),
              // Luxury 3D Deck Visual
              SizedBox(
                height: 240,
                width: 320,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Bottom half (Deep container)
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
                            BoxShadow(
                              color: Colors.black,
                              blurRadius: 20,
                              offset: const Offset(10, 10),
                            ),
                          ],
                        ),
                        child: _buildCardBackPattern(),
                      ),
                    ),
                    // Top half (Animated cut part)
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
                            border: Border.all(color: accentGold.withOpacity(0.5), width: 1.5),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black87,
                                blurRadius: 15,
                                offset: const Offset(-5, 5),
                              ),
                              if (isCutter)
                                BoxShadow(
                                  color: accentGold.withOpacity(0.2),
                                  blurRadius: 10,
                                  spreadRadius: 1,
                                ),
                            ],
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [Color(0xFF2A2A2A), Color(0xFF141414)],
                            ),
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
                      activeTrackColor: accentGold,
                      inactiveTrackColor: Colors.white10,
                      thumbColor: accentGold,
                      overlayColor: accentGold.withOpacity(0.2),
                      trackHeight: 2,
                    ),
                    child: Slider(
                      value: _cutPercentage,
                      onChanged: _isConfirming
                          ? null
                          : (val) {
                              if ((val * 51).round() != (_cutPercentage * 51).round()) {
                                gameAudio.playBiddingTick();
                              }
                              setState(() => _cutPercentage = val);
                            },
                    ),
                  ),
                ),
                const SizedBox(height: 40),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _isConfirming
                      ? null
                      : () async {
                          setState(() => _isConfirming = true);
                          gameAudio.playShuffle();
                          final cutIndex = (_cutPercentage * 51).round();
                          await ref
                              .read(cardServiceProvider)
                              .cutDeck(room.id, cutIndex);
                        },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 240,
                    height: 56,
                    decoration: BoxDecoration(
                      color: _isConfirming ? Colors.black26 : accentGold,
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        if (!_isConfirming)
                          BoxShadow(color: accentGold.withOpacity(0.4), blurRadius: 20, offset: const Offset(0, 8)),
                      ],
                    ),
                    child: Center(
                      child: _isConfirming
                          ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: primaryBg, strokeWidth: 3))
                          : const Text(
                              'CONFIRM CUT',
                              style: TextStyle(
                                color: primaryBg,
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.5,
                              ),
                            ),
                    ),
                  ),
                ),
              ] else ...[
                const CircularProgressIndicator(color: accentGold, strokeWidth: 2),
                const SizedBox(height: 20),
                Text(
                  'Waiting for opponent...',
                  style: TextStyle(color: Colors.white.withOpacity(0.3), fontStyle: FontStyle.italic),
                ),
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
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.auto_awesome, color: accentGold, size: 40),
            const SizedBox(height: 10),
            Text(
              'MINUS',
              style: TextStyle(
                color: accentGold,
                fontSize: 14,
                fontWeight: FontWeight.w900,
                letterSpacing: 4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
