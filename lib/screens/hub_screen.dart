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
    final crossCount = width > 900 ? 3 : 2;

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
                  tagline: 'Trick-Taking · 4 Players',
                  symbols: '♠ ♥ ♦ ♣',
                  gradient: const [Color(0xFF0D2B1A), Color(0xFF0A1C12)],
                  accentColor: gold,
                  isLive: true,
                  onTap: () => context.go('/minus'),
                  shimmerCtrl: _shimmerCtrl,
                ),
                _GameCard(
                  name: 'MATKA',
                  tagline: 'The Numbers Game',
                  symbols: '🎰',
                  gradient: const [Color(0xFF1A0D2B), Color(0xFF12091C)],
                  accentColor: const Color(0xFF9B59B6),
                  isLive: true,
                  onTap: () => context.go('/matka'),
                  shimmerCtrl: _shimmerCtrl,
                ),
                _GameCard(
                  name: 'TEHRI',
                  tagline: 'Classic Indian Card Game',
                  symbols: '🃏',
                  gradient: const [Color(0xFF2B1A0D), Color(0xFF1C1209)],
                  accentColor: const Color(0xFFE67E22),
                  isLive: true,
                  onTap: () => context.go('/tehri'),
                  shimmerCtrl: _shimmerCtrl,
                ),
                _GameCard(
                  name: '3 PATTI',
                  tagline: 'Indian Poker · 3–6 Players',
                  symbols: '♠ ♥ ♣',
                  gradient: const [Color(0xFF1A0D0D), Color(0xFF120909)],
                  accentColor: const Color(0xFFE74C3C),
                  isLive: false,
                  shimmerCtrl: _shimmerCtrl,
                ),
                _GameCard(
                  name: 'POKER',
                  tagline: 'Texas Hold\'em',
                  symbols: '♠ ♦',
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
                childAspectRatio: 0.78,
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
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Gold bar accent
                Container(
                  width: 32, height: 2,
                  margin: const EdgeInsets.only(bottom: 16),
                  color: goldDim,
                ),

                // HINDI Title
                ShaderMask(
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

                const SizedBox(height: 8),

                // Tagline
                const Text(
                  'कैसीनो डिलाइट',
                  style: TextStyle(
                    color: Colors.white38,
                    fontSize: 14,
                    letterSpacing: 2,
                    fontStyle: FontStyle.italic,
                  ),
                ),

                const SizedBox(height: 24),

                // Suit divider
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(width: 60, height: 0.5, color: Colors.white12),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: Text('♠ ♥ ♦ ♣',
                          style: TextStyle(color: Colors.white24, fontSize: 12, letterSpacing: 6)),
                    ),
                    Container(width: 60, height: 0.5, color: Colors.white12),
                  ],
                ),
              ],
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
  final String symbols;
  final List<Color> gradient;
  final Color accentColor;
  final bool isLive;
  final VoidCallback? onTap;
  final AnimationController shimmerCtrl;

  const _GameCard({
    required this.name,
    required this.tagline,
    required this.symbols,
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
              // Background symbol — large, faded
              Positioned(
                right: -12, bottom: -12,
                child: Opacity(
                  opacity: widget.isLive ? 0.06 : 0.03,
                  child: Text(
                    widget.symbols.split(' ').first,
                    style: TextStyle(color: widget.accentColor, fontSize: 100),
                  ),
                ),
              ),

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
                    // Live / Coming Soon badge
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

                    const Spacer(),

                    // Symbols display
                    Text(
                      widget.symbols,
                      style: TextStyle(
                        color: widget.isLive
                            ? widget.accentColor.withOpacity(0.8)
                            : Colors.white12,
                        fontSize: 22,
                        letterSpacing: 4,
                      ),
                    ),

                    const SizedBox(height: 8),

                    // Game name
                    Text(
                      widget.name,
                      style: TextStyle(
                        color: widget.isLive ? Colors.white : Colors.white38,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1,
                      ),
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

                    const SizedBox(height: 16),

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
