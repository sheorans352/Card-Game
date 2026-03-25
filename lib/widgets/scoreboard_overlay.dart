import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/room_provider.dart';

class ScoreboardOverlay extends ConsumerWidget {
  final String roomId;
  const ScoreboardOverlay({super.key, required this.roomId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playersAsync = ref.watch(playersStreamProvider(roomId));

class ScoreboardOverlay extends ConsumerWidget {
  final String roomId;
  const ScoreboardOverlay({super.key, required this.roomId});

  static const Color accentGold = Color(0xFFC7A14C);
  static const Color cardDark = Color(0xFF141414);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playersAsync = ref.watch(playersStreamProvider(roomId));

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(24),
        constraints: const BoxConstraints(maxWidth: 500),
        decoration: BoxDecoration(
          color: cardDark.withOpacity(0.95),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: accentGold.withOpacity(0.3), width: 1.5),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 20, spreadRadius: 5),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'SCOREBOARD',
              style: TextStyle(
                color: accentGold,
                fontSize: 28,
                fontWeight: FontWeight.w900,
                letterSpacing: 3,
              ),
            ),
            const SizedBox(height: 24),
            playersAsync.when(
              data: (players) {
                // Sort players by total score descending for rankings
                final sortedPlayers = [...players]..sort((a, b) => b.totalScore.compareTo(a.totalScore));
                
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columnSpacing: 24,
                    headingRowHeight: 40,
                    dataRowHeight: 50,
                    dividerThickness: 0.5,
                    columns: const [
                      DataColumn(label: Text('RANK', style: TextStyle(color: accentGold, fontSize: 10, fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('PLAYER', style: TextStyle(color: accentGold, fontSize: 10, fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('BID', style: TextStyle(color: accentGold, fontSize: 10, fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('WON', style: TextStyle(color: accentGold, fontSize: 10, fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('TOTAL', style: TextStyle(color: accentGold, fontSize: 10, fontWeight: FontWeight.bold))),
                    ],
                    rows: sortedPlayers.asMap().entries.map((entry) {
                      final idx = entry.key;
                      final p = entry.value;
                      return DataRow(cells: [
                        DataCell(Text('#${idx + 1}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                        DataCell(Text(p.name, style: const TextStyle(color: Colors.white70))),
                        DataCell(Text('${p.bid ?? "-"}', style: const TextStyle(color: Colors.white54))),
                        DataCell(Text('${p.tricksWon}', style: const TextStyle(color: Colors.white54))),
                        DataCell(Text('${p.totalScore}', style: TextStyle(
                          color: p.totalScore >= 0 ? Colors.greenAccent[400] : Colors.redAccent,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ))),
                      ]);
                    }).toList(),
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator(color: accentGold)),
              error: (e, s) => const Text('Error loading scores', style: TextStyle(color: Colors.redAccent)),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: accentGold,
                foregroundColor: const Color(0xFF0B2111),
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 5,
              ),
              child: const Text('BACK TO GAME', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2)),
            ),
          ],
        ),
      ),
    );
  }
}
