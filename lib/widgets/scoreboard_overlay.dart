import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/room_provider.dart';

class ScoreboardOverlay extends ConsumerWidget {
  final String roomId;
  const ScoreboardOverlay({super.key, required this.roomId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playersAsync = ref.watch(playersStreamProvider(roomId));

    return AlertDialog(
      backgroundColor: Colors.grey[900],
      title: const Text('SCOREBOARD', style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
      content: SizedBox(
        width: 400,
        child: playersAsync.when(
          data: (players) => SingleChildScrollView(
            child: DataTable(
              columnSpacing: 20,
              columns: const [
                DataColumn(label: Text('Player', style: TextStyle(color: Colors.amber, fontSize: 12))),
                DataColumn(label: Text('Bid', style: TextStyle(color: Colors.amber, fontSize: 12))),
                DataColumn(label: Text('Won', style: TextStyle(color: Colors.amber, fontSize: 12))),
                DataColumn(label: Text('Total', style: TextStyle(color: Colors.amber, fontSize: 12))),
              ],
              rows: players.map((p) => DataRow(cells: [
                DataCell(Text(p.name, style: const TextStyle(color: Colors.white, fontSize: 12))),
                DataCell(Text('${p.bid ?? "-"}', style: const TextStyle(color: Colors.white, fontSize: 12))),
                DataCell(Text('${p.tricksWon}', style: const TextStyle(color: Colors.white, fontSize: 12))),
                DataCell(Text('${p.totalScore}', style: TextStyle(color: p.totalScore >= 0 ? Colors.greenAccent : Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 12))),
              ])).toList(),
            ),
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, s) => Text('Error loading scores', style: TextStyle(color: Colors.red)),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('CLOSE', style: TextStyle(color: Colors.amber)),
        ),
      ],
    );
  }
}
