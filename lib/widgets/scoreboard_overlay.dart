import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:ui';
import '../providers/room_provider.dart';

class ScoreboardOverlay extends ConsumerWidget {
  final String roomId;
  final List<dynamic> players;
  final VoidCallback onClose;

  const ScoreboardOverlay({
    super.key,
    required this.roomId,
    required this.players,
    required this.onClose,
  });

  static const Color primaryBg = Color(0xFF062A14);
  static const Color accentGold = Color(0xFFC7A14C);
  static const Color boxGreen = Color(0xFF1B5E20);
  static const Color boxRed = Color(0xFFC62828);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resultsAsync = ref.watch(roundResultsProvider(roomId));
    final roomAsync = ref.watch(roomMetadataByIdProvider(roomId));
    final currentRound = roomAsync.value?.currentRound ?? 1;

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.82),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(40)),
          border: Border.all(color: Colors.white10),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 40, offset: const Offset(0, -10)),
          ],
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            // Pull Handle
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.stars_rounded, color: accentGold, size: 28),
                const SizedBox(width: 12),
                const Text(
                  'HALL OF FAME',
                  style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: 3),
                ),
              ],
            ),
            const Text('Race through 31 points to victory', style: TextStyle(color: Colors.white38, fontSize: 11)),
            const SizedBox(height: 32),

            // Table Header (Avatars)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              child: Row(
                children: [
                  const SizedBox(width: 70, child: Text('ROUND', style: TextStyle(color: Colors.white24, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1))),
                  ...players.map((p) => Expanded(
                    child: Center(
                      child: Container(
                        width: 42, height: 42,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: [accentGold.withOpacity(0.3), Colors.white10]),
                          shape: BoxShape.circle,
                          border: Border.all(color: accentGold.withOpacity(0.4), width: 1.5),
                        ),
                        child: Center(child: Text(p.name.substring(0, 1).toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900))),
                      ),
                    ),
                  )),
                ],
              ),
            ),

            // Results List
            Expanded(
              child: resultsAsync.when(
                data: (results) {
                  if (results.isEmpty) {
                    return const Center(child: Text('Scores will appear after the first round', style: TextStyle(color: Colors.white24, fontSize: 13)));
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    physics: const BouncingScrollPhysics(),
                    itemCount: currentRound + 1,
                    itemBuilder: (context, index) {
                      if (index == currentRound) return _buildTotalRow(players);

                      final rdNum = currentRound - index;
                      final isCurrentRound = rdNum == currentRound;
                      final historicalResults = results.where((r) => r['round_number'] == rdNum).toList();

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                          decoration: BoxDecoration(
                            color: isCurrentRound ? accentGold.withOpacity(0.08) : Colors.white.withOpacity(0.03),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: isCurrentRound ? accentGold.withOpacity(0.3) : Colors.white10),
                          ),
                          child: Row(
                            children: [
                              SizedBox(width: 70, child: Text('R$rdNum', style: TextStyle(
                                  color: isCurrentRound ? accentGold : Colors.white24, fontSize: 14, fontWeight: FontWeight.w900))),
                              ...players.map((p) {
                                if (isCurrentRound) {
                                   return Expanded(
                                     child: Column(
                                       children: [
                                         Text('${p.tricksWon}/${p.bid ?? "?"}', style: const TextStyle(color: accentGold, fontWeight: FontWeight.w900, fontSize: 18)),
                                         const Text('LIVE', style: TextStyle(color: accentGold, fontSize: 8, fontWeight: FontWeight.bold)),
                                       ],
                                     ),
                                   );
                                } else {
                                    final res = historicalResults.where((r) => r['player_id'] == p.id).firstOrNull;
                                    if (res == null) return const Expanded(child: SizedBox());
                                    final points = res['points_earned'] ?? 0;
                                    final isNegative = points < 0;

                                    return Expanded(
                                      child: Column(
                                        children: [
                                          Text('$points', style: TextStyle(
                                            color: isNegative ? boxRed : Colors.lightGreenAccent,
                                            fontWeight: FontWeight.w900, fontSize: 17,
                                          )),
                                          Text('${res['tricks_won']}/${res['bid']}', style: const TextStyle(color: Colors.white24, fontSize: 9)),
                                        ],
                                      ),
                                    );
                                }
                              }),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator(color: accentGold)),
                error: (e, _) => Center(child: Text('Error: $e', style: const TextStyle(color: boxRed))),
              ),
            ),

            // Race to 31 Progress
            _buildRaceTo31Indicators(players),
            
            const SizedBox(height: 20),
            _buildLegend(),
            const SizedBox(height: 12),

            // Back Button
            Padding(
              padding: const EdgeInsets.all(24),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: BackdropFilter(
                   filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                   child: ElevatedButton(
                    onPressed: onClose,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accentGold.withOpacity(0.8),
                      foregroundColor: Colors.black,
                      minimumSize: const Size(double.infinity, 64),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      elevation: 0,
                    ),
                    child: const Text('RESUME GAME', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 2)),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTotalRow(List<dynamic> players) {
    return Container(
      margin: const EdgeInsets.only(top: 16, bottom: 24),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [Colors.white.withOpacity(0.05), Colors.transparent]),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accentGold.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          const SizedBox(width: 70, child: Text('SCORE', style: TextStyle(color: accentGold, fontWeight: FontWeight.bold, fontSize: 12))),
          ...players.map((p) => Expanded(
            child: Center(
              child: Text('${p.totalScore}', style: TextStyle(
                  color: p.totalScore < 0 ? boxRed : Colors.white, fontSize: 26, fontWeight: FontWeight.w900,
                  shadows: [if (p.totalScore >= 20) Shadow(color: accentGold.withOpacity(0.5), blurRadius: 10)]
              )),
            ),
          )),
        ],
      ),
    );
  }

  Widget _buildRaceTo31Indicators(List<dynamic> players) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('CHAMPIONSHIP PROGRESS', style: TextStyle(color: Colors.white24, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 2)),
          const SizedBox(height: 16),
          Row(
            children: players.map((p) {
               final score = (p.totalScore as int).clamp(0, 31);
               final double progress = score / 31.0;
               final isNearWin = score >= 25;
               
               return Expanded(
                 child: Padding(
                   padding: const EdgeInsets.symmetric(horizontal: 5),
                   child: Column(
                     children: [
                       Stack(
                         children: [
                           Container(height: 6, decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(3))),
                           AnimatedContainer(
                             duration: const Duration(seconds: 1),
                             height: 6, width: progress * 100, // Approximation for flex
                             decoration: BoxDecoration(
                               gradient: LinearGradient(colors: isNearWin ? [Colors.orange, accentGold] : [accentGold, accentGold.withOpacity(0.4)]),
                               borderRadius: BorderRadius.circular(3),
                               boxShadow: [if (isNearWin) BoxShadow(color: accentGold.withOpacity(0.5), blurRadius: 8, spreadRadius: 1)],
                             ),
                           ),
                         ],
                       ),
                       const SizedBox(height: 6),
                       Text('${p.totalScore}/31', style: TextStyle(color: isNearWin ? accentGold : Colors.white24, fontSize: 10, fontWeight: FontWeight.bold)),
                     ],
                   ),
                 ),
               );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildLegend() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _legendItem('WINS', Colors.lightGreenAccent),
        _legendItem('PENALTY', boxRed),
        _legendItem('STATS', Colors.white24),
      ],
    );
  }

  Widget _legendItem(String label, Color color) {
    return Row(
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(color: Colors.white24, fontSize: 10, fontWeight: FontWeight.bold)),
      ],
    );
  }
}
