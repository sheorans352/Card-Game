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

  static const Color accentGold = Color(0xFFFFD700);
  static const Color boxRed = Color(0xFFFF4D4D);
  static const Color boxGreen = Color(0xFF00E676);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resultsAsync = ref.watch(roundResultsProvider(roomId));

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withOpacity(0.85),
              Colors.black.withOpacity(0.95),
            ],
          ),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(44)),
          border: Border.all(color: Colors.white10),
        ),
        child: Column(
          children: [
            const SizedBox(height: 14),
            Container(width: 50, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 28),
            
            // Title
            const Text(
              'RACE TO 31',
              style: TextStyle(color: accentGold, fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: 4),
            ),
            const SizedBox(height: 4),
            const Text(
              'ROUND PERFORMANCE SUMMARY',
              style: TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 2),
            ),
            const SizedBox(height: 32),

            // Table Content
            Expanded(
              child: resultsAsync.when(
                data: (results) {
                  final rounds = _groupResultsByRound(results);
                  
                  return SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    physics: const BouncingScrollPhysics(),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.03),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: Colors.white10),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Table(
                        columnWidths: const {
                          0: FixedColumnWidth(60), // Round #
                        },
                        border: TableBorder.symmetric(
                          inside: const BorderSide(color: Colors.white10, width: 0.5),
                        ),
                        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                        children: [
                          // Header Row (Names)
                          _buildHeaderRow(),
                          // Round Rows
                          ...rounds.entries.map((e) => _buildRoundRow(e.key, e.value)),
                          // Total Row
                          _buildTotalRow(results),
                        ],
                      ),
                    ),
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator(color: accentGold)),
                error: (e, s) => const Center(child: Text('Syncing results...', style: TextStyle(color: Colors.white24))),
              ),
            ),

            // Footer Button
            Padding(
              padding: const EdgeInsets.all(28),
              child: Container(
                width: double.infinity,
                height: 56,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: const LinearGradient(colors: [accentGold, Color(0xFFDAA520)]),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: onClose,
                    borderRadius: BorderRadius.circular(20),
                    child: const Center(
                      child: Text('BACK TO TABLE', style: TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  TableRow _buildHeaderRow() {
    return TableRow(
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.05)),
      children: [
        const _Cell(text: 'RD', isHeader: true),
        ...players.map((p) => _Cell(text: p.name.toUpperCase(), isHeader: true)),
      ],
    );
  }

  TableRow _buildRoundRow(int roundNum, List<Map<String, dynamic>> roundResults) {
    return TableRow(
      children: [
        _Cell(text: '#$roundNum', isLabel: true),
        ...players.map((p) {
          final result = roundResults.firstWhere((r) => r['player_id'] == p.id, orElse: () => {});
          if (result.isEmpty) return const _Cell(text: '-');

          final bid = result['bid'] ?? 0;
          final tricks = result['tricks_taken'] ?? 0;
          final score = result['score'] ?? 0;
          final isSuccess = score > 0;

          return _Cell(
            text: isSuccess ? '$tricks/$bid' : '$score',
            color: isSuccess ? boxGreen : boxRed,
            subText: isSuccess ? '+5' : null,
          );
        }),
      ],
    );
  }

  TableRow _buildTotalRow(List<Map<String, dynamic>> allResults) {
    return TableRow(
      decoration: BoxDecoration(color: accentGold.withOpacity(0.05)),
      children: [
        const _Cell(text: 'TOTAL', isLabel: true, color: accentGold),
        ...players.map((p) {
          final total = allResults
              .where((r) => r['player_id'] == p.id)
              .fold(0, (sum, item) => sum + (item['score'] as int));
          
          return _Cell(
            text: '$total', 
            isHeader: true, 
            color: total < 0 ? boxRed : (total >= 25 ? Colors.orange : Colors.white)
          );
        }),
      ],
    );
  }

  Map<int, List<Map<String, dynamic>>> _groupResultsByRound(List<Map<String, dynamic>> results) {
    final Map<int, List<Map<String, dynamic>>> rounds = {};
    for (var r in results) {
      final roundNum = r['round_number'] as int;
      rounds.putIfAbsent(roundNum, () => []).add(r);
    }
    return rounds;
  }
}

class _Cell extends StatelessWidget {
  final String text;
  final String? subText;
  final bool isHeader;
  final bool isLabel;
  final Color? color;

  const _Cell({
    required this.text,
    this.subText,
    this.isHeader = false,
    this.isLabel = false,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: color ?? (isHeader ? Colors.white : (isLabel ? Colors.white60 : Colors.white70)),
              fontSize: isHeader ? 14 : 13,
              fontWeight: isHeader ? FontWeight.w900 : (isLabel ? FontWeight.bold : FontWeight.normal),
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          if (subText != null)
            Text(
              subText!,
              style: TextStyle(color: color?.withOpacity(0.5) ?? Colors.white24, fontSize: 9, fontWeight: FontWeight.bold),
            ),
        ],
      ),
    );
  }
}
