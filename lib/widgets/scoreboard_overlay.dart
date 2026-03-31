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
  static const Color accentGold = Color(0xFFFFD700); 
  static const Color dangerRed = Color(0xFFFF4D4D);
  static const Color glassWhite = Colors.white10;

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
              Colors.black.withOpacity(0.9),
              Colors.black.withOpacity(0.95),
            ],
          ),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(44)),
          border: Border.all(color: Colors.white.withOpacity(0.1), width: 0.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.8),
              blurRadius: 60,
              offset: const Offset(0, -15),
            ),
          ],
        ),
        child: Column(
          children: [
            const SizedBox(height: 14),
            // Pull Handle
            Container(
              width: 50, height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 28),
            
            // Header Section
            Column(
              children: [
                ShaderMask(
                  shaderCallback: (Rect bounds) {
                    return const LinearGradient(
                      colors: [accentGold, Color(0xFFFFFACD), accentGold],
                    ).createShader(bounds);
                  },
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.emoji_events_rounded, color: Colors.white, size: 36),
                      SizedBox(width: 16),
                      Text(
                        'HALL OF FAME',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 6,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'RACE TO 31 • MINUS CHAMPIONSHIP',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.3),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 48),

            // Main Score List
            Expanded(
              child: resultsAsync.when(
                data: (results) {
                  return ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    physics: const BouncingScrollPhysics(),
                    children: [
                      ...players.map((p) {
                        final totalScore = _calculateTotalScore(p.id, results);
                        final isDanger = totalScore >= 25;
                        final progress = (totalScore / 31).clamp(0.0, 1.0);
                        
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 40),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      _buildAvatar(p.name, isDanger),
                                      const SizedBox(width: 20),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            p.name.toUpperCase(),
                                            style: TextStyle(
                                              color: isDanger ? dangerRed : Colors.white,
                                              fontSize: 16,
                                              fontWeight: FontWeight.w900,
                                              letterSpacing: 1.2,
                                              shadows: [
                                                if (isDanger) Shadow(color: dangerRed.withOpacity(0.5), blurRadius: 10),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: isDanger ? dangerRed.withOpacity(0.1) : Colors.white.withOpacity(0.05),
                                              borderRadius: BorderRadius.circular(4),
                                              border: Border.all(color: isDanger ? dangerRed.withOpacity(0.2) : Colors.white12),
                                            ),
                                            child: Text(
                                              isDanger ? 'DANGER ZONE' : 'SAFE ZONE',
                                              style: TextStyle(
                                                color: isDanger ? dangerRed : Colors.white24,
                                                fontSize: 9,
                                                fontWeight: FontWeight.w900,
                                                letterSpacing: 1,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  Column(
                                    crossAxisAlignment: Alignment.end,
                                    children: [
                                      Text(
                                        '$totalScore',
                                        style: TextStyle(
                                          color: isDanger ? dangerRed : Colors.white,
                                          fontSize: 38,
                                          height: 1,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: -1,
                                          fontFeatures: const [FontFeature.tabularFigures()],
                                        ),
                                      ),
                                      Text(
                                        'POINTS',
                                        style: TextStyle(
                                          color: isDanger ? dangerRed.withOpacity(0.4) : Colors.white10,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              _buildProgressBar(context, progress, isDanger),
                            ],
                          ),
                        );
                      }),
                      const SizedBox(height: 30),
                    ],
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator(color: accentGold)),
                error: (e, s) => Center(child: Text('Score sync in progress...', style: TextStyle(color: Colors.white.withOpacity(0.1)))),
              ),
            ),

            // Footer Section
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 0, 28, 48),
              child: Column(
                children: [
                  const Text(
                    'LAST MAN STANDING WINS',
                    style: TextStyle(color: Colors.white12, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 2),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    width: double.infinity,
                    height: 64,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      gradient: const LinearGradient(
                        colors: [accentGold, Color(0xFFDAA520)],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: accentGold.withOpacity(0.3),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: onClose,
                        borderRadius: BorderRadius.circular(24),
                        child: const Center(
                          child: Text(
                            'RESUME ACTION',
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 2,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar(String name, bool isDanger) {
    return Container(
      width: 56, height: 56,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDanger 
            ? [dangerRed.withOpacity(0.6), dangerRed.withOpacity(0.2)]
            : [accentGold.withOpacity(0.6), accentGold.withOpacity(0.2)],
        ),
        boxShadow: [
          BoxShadow(
            color: (isDanger ? dangerRed : accentGold).withOpacity(0.2),
            blurRadius: 15,
            spreadRadius: 2,
          ),
        ],
        border: Border.all(
          color: (isDanger ? dangerRed : accentGold).withOpacity(0.4),
          width: 2,
        ),
      ),
      child: Center(
        child: Text(
          name.substring(0, 1).toUpperCase(),
          style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900),
        ),
      ),
    );
  }

  Widget _buildProgressBar(BuildContext context, double progress, bool isDanger) {
    return Stack(
      children: [
        Container(
          height: 12,
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(6),
          ),
        ),
        LayoutBuilder(
          builder: (context, constraints) {
            return AnimatedContainer(
              duration: const Duration(milliseconds: 1200),
              curve: Curves.elasticOut,
              height: 12,
              width: constraints.maxWidth * progress,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDanger 
                    ? [dangerRed.withOpacity(0.8), dangerRed]
                    : [const Color(0xFFFFF700), accentGold],
                ),
                borderRadius: BorderRadius.circular(6),
                boxShadow: [
                  BoxShadow(
                    color: (isDanger ? dangerRed : accentGold).withOpacity(0.5),
                    blurRadius: 12,
                    spreadRadius: 1,
                  ),
                ],
              ),
            );
          }
        ),
      ],
    );
  }

  int _calculateTotalScore(String playerId, List<Map<String, dynamic>> results) {
    return results
      .where((r) => r['player_id'] == playerId)
      .fold(0, (sum, item) => sum + (item['score'] as int));
  }
}
