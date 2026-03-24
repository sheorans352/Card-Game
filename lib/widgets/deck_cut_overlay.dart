import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/room_provider.dart';
import '../services/card_service.dart';

class DeckCutOverlay extends ConsumerStatefulWidget {
  const DeckCutOverlay({super.key});

  @override
  ConsumerState<DeckCutOverlay> createState() => _DeckCutOverlayState();
}

class _DeckCutOverlayState extends ConsumerState<DeckCutOverlay> {
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
          color: Colors.black54,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'CUT THE DECK',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 4,
                ),
              ),
              const SizedBox(height: 40),
              // 3D Deck Visual
              SizedBox(
                height: 200,
                width: 300,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Bottom half of the visual deck
                    Transform(
                      transform: Matrix4.identity()
                        ..setEntry(3, 2, 0.001)
                        ..rotateX(-0.2),
                      child: Container(
                        width: 140,
                        height: 180,
                        decoration: BoxDecoration(
                          color: Colors.blueGrey[800],
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.5),
                              blurRadius: 10,
                              offset: const Offset(5, 5),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Top half (the cut part)
                    AnimatedPositioned(
                      duration: const Duration(milliseconds: 300),
                      left: 80 + (_cutPercentage * 40),
                      top: 10 - (_cutPercentage * 20),
                      child: Transform(
                        transform: Matrix4.identity()
                          ..setEntry(3, 2, 0.001)
                          ..rotateX(-0.2)
                          ..rotateZ(0.05),
                        child: Container(
                          width: 140,
                          height: 180,
                          decoration: BoxDecoration(
                            color: Colors.blueGrey[700],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.white24),
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
                            ),
                          ),
                          child: const Center(
                            child: Icon(Icons.style, color: Colors.white10, size: 80),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 60),
              if (isCutter) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: Colors.amber,
                      inactiveTrackColor: Colors.white24,
                      thumbColor: Colors.amber,
                      overlayColor: Colors.amber.withOpacity(0.2),
                    ),
                    child: Slider(
                      value: _cutPercentage,
                      onChanged: _isConfirming
                          ? null
                          : (val) => setState(() => _cutPercentage = val),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _isConfirming
                      ? null
                      : () async {
                          setState(() => _isConfirming = true);
                          final cutIndex = (_cutPercentage * 51).round();
                          await ref
                              .read(cardServiceProvider)
                              .cutDeck(room.id, cutIndex);
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  ),
                  child: _isConfirming
                      ? const CircularProgressIndicator(color: Colors.black)
                      : const Text('CONFIRM CUT',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ] else ...[
                const Text(
                  'Waiting for player to cut...',
                  style: TextStyle(color: Colors.white70, fontStyle: FontStyle.italic),
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
}
