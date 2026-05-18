import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class HubScreen extends StatefulWidget {
  const HubScreen({super.key});

  @override
  State<HubScreen> createState() => _HubScreenState();
}

class _HubScreenState extends State<HubScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _shimmerCtrl;

  static const Color bgDeep     = Color(0xFF060810);
  static const Color gold       = Color(0xFFFFD700);
  static const Color goldDim    = Color(0xFFC7A14C);

  @override
  void initState() {
    super.initState();
    _shimmerCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 3))
      ..repeat();

    // Deep link redirection: If 'code' is present in URL, redirect to Minus
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final state = GoRouterState.of(context);
      final code = state.uri.queryParameters['code'] ?? state.uri.queryParameters['room'];
      final gameType = state.uri.queryParameters['game'];

      if (code != null && code.isNotEmpty) {
        if (gameType == 'matka') {
          context.go('/matka?code=$code');
        } else if (gameType == 'tehri') {
          context.go('/tehri?code=$code');
        } else {
          // Default to Minus
          context.go('/minus?code=$code');
        }
      }
    });
  }

  @override
  void dispose() {
    _shimmerCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isDesktop = width > 900;
    final crossCount = isDesktop ? 3 : 2;

    return Scaffold(
      backgroundColor: bgDeep,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // ── HERO HEADER ─────────────────────────────────────────────────────
          SliverToBoxAdapter(child: _buildHero()),

          // ── SECTION TITLE ───────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
              child: Row(
                children: [
                  Container(width: 3, height: 18, color: gold),
                  const SizedBox(width: 10),
                  const Text(
                    'CHOOSE YOUR GAME',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 3,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── GAME GRID ────────────────────────────────────────────────────────
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverGrid(
              delegate: SliverChildListDelegate([
                _GameCard(
                  name: 'MINUS',
                  tagline: 'Trick-Taking',
                  bulletPoints: const [
                    '4 Players Game',
                    'First to Score 31 wins',
                    'Scored based on how many hand you could or could not take',
                  ],
                  gradient: const [Color(0xFF0D2B1A), Color(0xFF0A1C12)],
                  accentColor: gold,
                  isLive: true,
                  onTap: () => context.go('/minus'),
                  shimmerCtrl: _shimmerCtrl,
                ),
                _GameCard(
                  name: 'MATKA',
                  tagline: 'The Numbers Game',
                  gradient: const [Color(0xFF1A0D2B), Color(0xFF12091C)],
                  accentColor: const Color(0xFF9B59B6),
                  isLive: true,
                  onTap: () => context.go('/matka'),
                  shimmerCtrl: _shimmerCtrl,
                ),
                _GameCard(
                  name: 'TEHRI',
                  tagline: 'Classic Indian Card Game',
                  gradient: const [Color(0xFF2B1A0D), Color(0xFF1C1209)],
                  accentColor: const Color(0xFFE67E22),
                  isLive: true,
                  onTap: () => context.go('/tehri'),
                  shimmerCtrl: _shimmerCtrl,
                ),
                _GameCard(
                  name: '3 PATTI',
                  tagline: 'Indian Poker · 3–6 Players',
                  gradient: const [Color(0xFF1A0D0D), Color(0xFF120909)],
                  accentColor: const Color(0xFFE74C3C),
                  isLive: false,
                  shimmerCtrl: _shimmerCtrl,
                ),
                _GameCard(
                  name: 'POKER',
                  tagline: 'Texas Hold\'em',
                  gradient: const [Color(0xFF0D1A2B), Color(0xFF09121C)],
                  accentColor: const Color(0xFF3498DB),
                  isLive: false,
                  shimmerCtrl: _shimmerCtrl,
                ),
              ]),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossCount,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: isDesktop ? 1.56 : 0.78,
              ),
            ),
          ),

          // ── BLOG SECTION ────────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 48, 24, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(width: 3, height: 18, color: gold),
                      const SizedBox(width: 10),
                      const Text(
                        'LATEST ARTICLES',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 3,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  GestureDetector(
                    onTap: () => context.go('/blogs'),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF1A1A2E), Color(0xFF16213E)],
                        ),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: gold.withOpacity(0.2)),
                      ),
                      child: Row(
                        children: [
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Learn How to Win!',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Explore our guides and strategies to master your favorite card games.',
                                  style: TextStyle(
                                    color: Colors.white38,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: gold.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.arrow_forward, color: gold),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── FOOTER ──────────────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 48),
              child: Column(
                children: [
                  const Text('CASINO DELIGHT',
                      style: TextStyle(color: Colors.white12, fontSize: 10, letterSpacing: 4)),
                  const SizedBox(height: 4),
                  Text('More games coming soon',
                      style: TextStyle(color: Colors.white.withOpacity(0.08), fontSize: 10)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHero() {
    return Container(
      height: 260,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF0F1A0F), Color(0xFF060810)],
        ),
      ),
      child: Stack(
        children: [
          // Decorative suit symbols — large faded background
          Positioned(
            top: 10, left: -20,
            child: _FadedSuit('♠', size: 120, opacity: 0.04),
          ),
          Positioned(
            bottom: 10, right: -20,
            child: _FadedSuit('♦', size: 110, opacity: 0.04),
          ),
          Positioned(
            top: 30, right: 40,
            child: _FadedSuit('♥', size: 70, opacity: 0.05),
          ),
          Positioned(
            bottom: 30, left: 40,
            child: _FadedSuit('♣', size: 60, opacity: 0.05),
          ),

          // Brand
          Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: const EdgeInsets.only(top: 48),
              child: ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  colors: [Color(0xFFFFD700), Color(0xFFC7A14C), Color(0xFFFFD700)],
                  stops: [0.0, 0.5, 1.0],
                ).createShader(bounds),
                child: const Text(
                  'CASINO DELIGHT',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 6,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── FADED SUIT SYMBOL ───────────────────────────────────────────────────────
class _FadedSuit extends StatelessWidget {
  final String symbol;
  final double size;
  final double opacity;
  const _FadedSuit(this.symbol, {required this.size, required this.opacity});

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: opacity,
      child: Text(symbol,
          style: TextStyle(
            color: Colors.white,
            fontSize: size,
            fontWeight: FontWeight.bold,
          )),
    );
  }
}

// ── GAME CARD ──────────────────────────────────────────────────────────────
class _GameCard extends StatefulWidget {
  final String name;
  final String tagline;
  final List<String> bulletPoints;
  final List<Color> gradient;
  final Color accentColor;
  final bool isLive;
  final VoidCallback? onTap;
  final AnimationController shimmerCtrl;

  const _GameCard({
    required this.name,
    required this.tagline,
    this.bulletPoints = const [],
    required this.gradient,
    required this.accentColor,
    required this.isLive,
    required this.shimmerCtrl,
    this.onTap,
  });

  @override
  State<_GameCard> createState() => _GameCardState();
}

class _GameCardState extends State<_GameCard> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        onTap: widget.isLive ? widget.onTap : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          transform: Matrix4.identity()
            ..translate(0.0, _hovering && widget.isLive ? -4.0 : 0.0),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: widget.gradient,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _hovering && widget.isLive
                  ? widget.accentColor.withOpacity(0.8)
                  : widget.accentColor.withOpacity(0.15),
              width: _hovering && widget.isLive ? 1.5 : 0.5,
            ),
            boxShadow: _hovering && widget.isLive
                ? [BoxShadow(color: widget.accentColor.withOpacity(0.2), blurRadius: 24, spreadRadius: 2)]
                : [],
          ),
          child: Stack(
            children: [
              // COMING SOON overlay shimmer
              if (!widget.isLive)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      color: Colors.black.withOpacity(0.45),
                    ),
                  ),
                ),

              // Card content
              Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top row: Game name and Live badge
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            widget.name,
                            style: TextStyle(
                              color: widget.isLive ? Colors.white : Colors.white38,
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: widget.isLive
                                ? widget.accentColor.withOpacity(0.15)
                                : Colors.white.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: widget.isLive
                                  ? widget.accentColor.withOpacity(0.6)
                                  : Colors.white12,
                              width: 0.5,
                            ),
                          ),
                          child: Text(
                            widget.isLive ? '● LIVE' : 'COMING SOON',
                            style: TextStyle(
                              color: widget.isLive ? widget.accentColor : Colors.white24,
                              fontSize: 8,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 4),

                    // Tagline
                    Text(
                      widget.tagline,
                      style: TextStyle(
                        color: widget.isLive ? Colors.white38 : Colors.white12,
                        fontSize: 10,
                        letterSpacing: 0.5,
                      ),
                    ),

                    if (widget.bulletPoints.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      ...widget.bulletPoints.map((point) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '• ',
                              style: TextStyle(
                                color: widget.isLive ? Colors.white54 : Colors.white24,
                                fontSize: 12,
                              ),
                            ),
                            Expanded(
                              child: Text(
                                point,
                                style: TextStyle(
                                  color: widget.isLive ? Colors.white54 : Colors.white24,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )),
                    ],

                    const Spacer(),

                    // Action button (LIVE only)
                    if (widget.isLive)
                      Container(
                        width: double.infinity,
                        height: 40,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [widget.accentColor, widget.accentColor.withOpacity(0.7)],
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Center(
                          child: Text(
                            'PLAY NOW →',
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 2,
                            ),
                          ),
                        ),
                      )
                    else
                      Container(
                        width: double.infinity,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.04),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white10),
                        ),
                        child: const Center(
                          child: Text(
                            'COMING SOON',
                            style: TextStyle(
                              color: Colors.white24,
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 2,
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
      ),
    );
  }
}
