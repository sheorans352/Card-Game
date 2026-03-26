import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

    return Container(
      decoration: BoxDecoration(
        color: primaryBg.withOpacity(0.98),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        border: Border.all(color: accentGold.withOpacity(0.2), width: 1.5),
      ),
      child: Column(
        children: [
          const SizedBox(height: 30),
          const Text(
            'Scoreboard',
            style: TextStyle(color: accentGold, fontSize: 32, fontWeight: FontWeight.w900, letterSpacing: 1),
          ),
          const SizedBox(height: 4),
          const Text(
            'Race to 31 — Rounds 1 to 5',
            style: TextStyle(color: Colors.white38, fontSize: 13),
          ),
          const SizedBox(height: 30),

          // Table Header (Avatars)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                const SizedBox(width: 80, child: Text('ROUND', style: TextStyle(color: Colors.white24, fontSize: 10, fontWeight: FontWeight.bold))),
                ...players.map((p) => Expanded(
                  child: Center(
                    child: Container(
                       width: 40, height: 40,
                       decoration: const BoxDecoration(color: Colors.white10, shape: BoxShape.circle),
                       child: Center(child: Text(p.name.substring(0, 2).toUpperCase(), style: const TextStyle(color: Color(0xFF2E7D32), fontSize: 12, fontWeight: FontWeight.bold))),
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
                  return const Center(child: Text('No rounds completed yet', style: TextStyle(color: Colors.white30)));
                }

                // Group results by round_number
                final Map<int, List<dynamic>> grouped = {};
                for (var r in results) {
                  final rd = r['round_number'] as int;
                  grouped.putIfAbsent(rd, () => []).add(r);
                }

                final roundNumbers = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: roundNumbers.length + 1, // +1 for TOTAL row
                  itemBuilder: (context, index) {
                    if (index == roundNumbers.length) {
                       return _buildTotalRow(players);
                    }

                    final rdNum = roundNumbers[index];
                    final rdResults = grouped[rdNum]!;
                    
                    return Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 80, 
                            child: Row(
                              children: [
                                Text('R$rdNum', style: const TextStyle(color: Colors.white24, fontSize: 14)),
                                if (rdNum == roundNumbers.first) const Icon(Icons.arrow_left, color: accentGold, size: 20),
                              ],
                            ),
                          ),
                          ...players.map((p) {
                            final res = rdResults.firstWhere((r) => r['player_id'] == p.id, orElse: () => null);
                            if (res == null) return const Expanded(child: SizedBox());
                            
                            final points = res['points_earned'] ?? 0;
                            final isNegative = points < 0;

                            return Expanded(
                              child: Container(
                                margin: const EdgeInsets.all(4),
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                decoration: BoxDecoration(
                                  color: isNegative ? boxRed.withOpacity(0.15) : Colors.white.withOpacity(0.05),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: isNegative ? boxRed.withOpacity(0.3) : Colors.white10),
                                ),
                                child: Column(
                                  children: [
                                    Text(
                                      '${points >= 0 ? "+" : ""}$points',
                                      style: TextStyle(
                                        color: isNegative ? boxRed : Colors.lightGreenAccent,
                                        fontWeight: FontWeight.w900,
                                        fontSize: 18,
                                      ),
                                    ),
                                    Text('${res['tricks_won']}/${res['bid']}', style: TextStyle(color: Colors.white38, fontSize: 9)),
                                  ],
                                ),
                              ),
                            );
                          }),
                        ],
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFFC7A14C))),
              error: (e, _) => Center(child: Text('Error loading scores: $e', style: const TextStyle(color: Colors.redAccent))),
            ),
          ),

                  // Race to 31 Progress Bars
          _buildRaceTo31Indicators(players),
          
          const Spacer(),

          // Legend Footer
          _buildLegend(),

          // Back Button
          Padding(
            padding: const EdgeInsets.all(24),
            child: ElevatedButton(
              onPressed: onClose,
              style: ElevatedButton.styleFrom(
                backgroundColor: accentGold,
                foregroundColor: Colors.black,
                minimumSize: const Size(double.infinity, 56),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Back to Game Table', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                  SizedBox(width: 8),
                  Icon(Icons.arrow_forward, size: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTotalRow(List<dynamic> players) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          const SizedBox(width: 80, child: Text('TOTAL', style: TextStyle(color: accentGold, fontWeight: FontWeight.w900, fontSize: 14))),
          ...players.map((p) => Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: accentGold.withOpacity(0.3)),
              ),
              child: Center(
                child: Text('${p.totalScore}', style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900)),
              ),
            ),
          )),
        ],
      ),
    );
  }

  Widget _buildRaceTo31Indicators(List<dynamic> players) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('RACE TO 31', style: TextStyle(color: Colors.white24, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1)),
          const SizedBox(height: 12),
          Row(
            children: players.map((p) {
               final double progress = (p.totalScore as int).clamp(0, 31) / 31.0;
               return Expanded(
                 child: Padding(
                   padding: const EdgeInsets.symmetric(horizontal: 4),
                   child: Column(
                     children: [
                       ClipRRect(
                         borderRadius: BorderRadius.circular(2),
                         child: LinearProgressIndicator(
                           value: progress,
                           minHeight: 4,
                           backgroundColor: Colors.white10,
                           color: accentGold,
                         ),
                       ),
                       const SizedBox(height: 4),
                       Text('${p.totalScore}/31', style: const TextStyle(color: Colors.white24, fontSize: 9)),
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _legendItem('+5', 'Bid met or exceeded', Colors.lightGreenAccent),
          _legendItem('-7', 'Bid missed (deducted)', boxRed),
          _legendItem('4/6', 'Tricks taken / bid', Colors.white38),
        ],
      ),
    );
  }

  Widget _legendItem(String val, String label, Color color) {
    return Column(
      children: [
        Text(val, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14)),
        Text(label, style: const TextStyle(color: Colors.white24, fontSize: 8)),
      ],
    );
  }
}
