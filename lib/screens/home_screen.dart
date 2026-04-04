import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:html' as html;
import '../providers/room_provider.dart';
import '../widgets/spade_background.dart';
import 'lobby_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _nameController = TextEditingController();
  final _codeController = TextEditingController();
  bool _isHostingTab = true;

  static const Color primaryBg = Color(0xFF0B2111);
  static const Color accentGold = Color(0xFFC7A14C);
  static const Color cardDark = Color(0xFF121212);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final persistedName = ref.read(localPlayerNameProvider);
      if (persistedName != null) {
        _nameController.text = persistedName;
      }
    });
    _checkInitialSession();
  }

  Future<void> _checkInitialSession() async {
    // Correctly handle both direct and hash-based URLs
    final uri = Uri.parse(Uri.base.toString().replaceFirst('/#/', '/'));
    final urlParams = uri.queryParameters;
    final urlCode = urlParams['room'] ?? urlParams['code'];
    
    if (urlCode != null) {
      _codeController.text = urlCode;
      setState(() { _isHostingTab = false; });
      ref.read(currentRoomCodeProvider.notifier).state = urlCode;
      
      // If we also have a playerId in URL, try auto-join
      final urlPlayerId = urlParams['playerId'];
      if (urlPlayerId != null) {
        ref.read(localPlayerIdProvider.notifier).state = urlPlayerId;
        _autoJoin(urlCode, urlPlayerId);
      }
    }
  }

  Future<void> _autoJoin(String code, String playerId) async {
    try {
      final result = await ref.read(lobbyServiceProvider).joinRoom(
        code, 
        '', 
        existingPlayerId: playerId
      );
      if (result != null && mounted) {
        Navigator.of(context).push(MaterialPageRoute(builder: (context) => const LobbyScreen()));
      }
    } catch (e) {
      debugPrint('Auto-join failed: $e');
    }
  }

  Widget _buildTabButton(String label, bool isActive, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            border: isActive ? Border.all(color: accentGold, width: 1) : null,
            borderRadius: BorderRadius.circular(8),
            color: isActive ? accentGold.withOpacity(0.1) : Colors.transparent,
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isActive ? accentGold : Colors.white38,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label, String hint) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: accentGold, fontSize: 12, fontWeight: FontWeight.bold),
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.white24),
      filled: true,
      fillColor: Colors.black26,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Colors.white10),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: accentGold, width: 1),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<String?>(currentRoomCodeProvider, (previous, next) {
      if (next != null && next != _codeController.text) {
        _codeController.text = next;
        setState(() { _isHostingTab = false; });
        
        // Sync URL for Web
        if (kIsWeb) {
          final uri = Uri.base;
          final newUri = uri.replace(queryParameters: {
            ...uri.queryParameters,
            'code': next,
          });
          html.window.history.replaceState(null, '', '#${newUri.path}${newUri.query.isNotEmpty ? '?' + newUri.query : ''}');
        }
      }
    });

    return Scaffold(
      backgroundColor: primaryBg,
      body: Stack(
        children: [
          // Subtle radial gradient background
          Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.center,
                radius: 1.5,
                colors: [
                  Color(0xFF15331B),
                  primaryBg,
                ],
              ),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: Column(
                    children: [
                      const Text(
                        'MINUS',
                        style: TextStyle(
                          fontSize: 64,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2,
                          color: accentGold,
                          fontFamily: 'Serif', // Use default serif if custom not available
                        ),
                      ),
                      const Text(
                        'TRICK-TAKING CARD GAME',
                        style: TextStyle(
                          fontSize: 12,
                          letterSpacing: 4,
                          color: Colors.white54,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildSuitIcon('♠', Colors.white.withOpacity(0.15)),
                          const SizedBox(width: 16),
                          _buildSuitIcon('♥', Colors.red.withOpacity(0.5)),
                          const SizedBox(width: 16),
                          _buildSuitIcon('♦', Colors.blue.withOpacity(0.5)),
                          const SizedBox(width: 16),
                          _buildSuitIcon('♣', Colors.white.withOpacity(0.15)),
                        ],
                      ),
                      const SizedBox(height: 48),
                      
                      // Tab Switcher
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.black26,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            _buildTabButton('Host Game', _isHostingTab, () => setState(() => _isHostingTab = true)),
                            _buildTabButton('Join Game', !_isHostingTab, () => setState(() => _isHostingTab = false)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),

                      if (ref.watch(currentRoomCodeProvider) != null && 
                          ref.watch(localPlayerIdProvider) != null && 
                          (Uri.base.queryParameters['room'] == null && Uri.base.queryParameters['code'] == null))
                        _buildRejoinButton(),

                       if (_isHostingTab) ...[
                        _buildHostForm(),
                      ] else ...[
                        _buildJoinForm(),
                      ],

                      const SizedBox(height: 48),
                      _buildRulesSection(),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRulesSection() {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: cardDark.withOpacity(0.7),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: accentGold.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.menu_book_rounded, color: accentGold, size: 24),
              SizedBox(width: 12),
              Text('HOW TO PLAY: MINUS', style: TextStyle(color: accentGold, fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 2)),
            ],
          ),
          const SizedBox(height: 24),
          const Text(
            'Minus is a strategic, 4-player trick-taking game. Your success depends on your ability to predict exactly how many hands you can win.',
            style: TextStyle(color: Colors.white70, fontSize: 13, fontStyle: FontStyle.italic),
          ),
          
          const SizedBox(height: 32),
          _buildRichRuleHeader('🏆 THE OBJECTIVE'),
          _buildRichRuleText('The goal is to be the first player to reach 31 Points.'),
          _buildRichRuleBullet('Win your bid', 'If you win at least as many tricks as you bid, you gain those points.'),
          _buildRichRuleBullet('Fail your bid', 'If you win fewer tricks than you bid, you lose those points (Minus).'),

          const SizedBox(height: 24),
          _buildRichRuleHeader('📦 THE 5-4-4 DEALING PHASES'),
          _buildRichRuleText('The deck of 52 cards is dealt in three distinct stages:'),
          _buildRichRuleBullet('Phase 1 (The First 5)', 'Every player gets 5 cards. This is where the Trump Battle happens.'),
          _buildRichRuleBullet('Phase 2 (The Next 4)', 'Once the trump is set, 4 more cards are dealt to everyone.'),
          _buildRichRuleBullet('Phase 3 (The Final 4)', 'The last 4 cards are dealt. Everyone now has a full hand of 13 cards.'),

          const SizedBox(height: 24),
          _buildRichRuleHeader('⚖️ STRATEGIC BIDDING'),
          _buildRichRuleBullet('Phase 1 (Priority Bidding)', 'You can Bid 5 or more to "Lock" the Trump suit once you get your first 5 cards. If you lock the suit, your bid is final.'),
          _buildRichRuleBullet('Phase 2 (Final Call)', 'After all 13 cards are dealt, everyone else submits their final bid (2–13).'),
          _buildRichRuleBullet('The 9+ Override', 'If no one bid 5+ in Phase 1, the default Trump is Spades. However, a player can still change the Trump, but only if they bid 9 or more.'),

          const SizedBox(height: 24),
          _buildRichRuleHeader('⚔️ GAMEPLAY: "MUST-WIN" RULES'),
          _buildRichRuleText('The person who set the Trump (or the person who cut the deck if no trump was set) leads the first card.'),
          _buildRichRuleBullet('Follow Suit', 'You must play a card of the same suit as the lead card.'),
          _buildRichRuleBullet('The Power Rule', 'If you have a card in the lead suit that is higher than the current winner on the table, you MUST play it. No hiding high cards!'),
          _buildRichRuleBullet('Cutting with Trump', 'If void of a suit, you can play a Trump. If a Trump was already played, you must play a higher Trump if possible.'),
          _buildRichRuleBullet('Throwing Away', 'If you have no lead suit and no trumps, you can play any card.'),
        ],
      ),
    );
  }

  Widget _buildRichRuleHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(title, style: const TextStyle(color: accentGold, fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 1)),
    );
  }

  Widget _buildRichRuleText(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildRichRuleBullet(String label, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Icon(Icons.circle, color: accentGold, size: 6),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.5),
                children: [
                  TextSpan(text: '$label: ', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  TextSpan(text: description),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHostForm() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: cardDark.withOpacity(0.9),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('YOUR NAME', style: TextStyle(color: accentGold, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.5)),
          const SizedBox(height: 12),
          TextField(
            controller: _nameController,
            style: const TextStyle(color: Colors.white),
            decoration: _inputDecoration('', 'Enter your name...'),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _hostGame,
            style: ElevatedButton.styleFrom(
              backgroundColor: accentGold,
              foregroundColor: primaryBg,
              minimumSize: const Size(double.infinity, 60),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 8,
            ),
            child: const Text('Create Room & Get Link', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ),
          if (ref.read(localPlayerNameProvider) != null)
             Padding(
               padding: const EdgeInsets.only(top: 16),
               child: Center(
                 child: Text('Welcome back, ${ref.read(localPlayerNameProvider)}!', 
                   style: const TextStyle(color: Colors.white38, fontSize: 12, fontStyle: FontStyle.italic)),
               ),
             ),
        ],
      ),
    );
  }

  Widget _buildRejoinButton() {
    final code = ref.watch(currentRoomCodeProvider);
    return Padding(
      padding: const EdgeInsets.only(bottom: 32),
      child: InkWell(
        onTap: () => _autoJoin(code!, ref.read(localPlayerIdProvider)!),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: accentGold.withOpacity(0.15),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: accentGold.withOpacity(0.5)),
          ),
          child: Row(
            children: [
              const Icon(Icons.history_rounded, color: accentGold, size: 28),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('RE-JOIN LAST GAME', style: TextStyle(color: accentGold, fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 1)),
                    Text('Room: $code', style: const TextStyle(color: Colors.white70, fontSize: 11)),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios_rounded, color: accentGold, size: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildJoinForm() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: cardDark.withOpacity(0.9),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white10),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('ROOM CODE', style: TextStyle(color: accentGold, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.5)),
              const SizedBox(height: 16),
              TextField(
                controller: _codeController,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 24, letterSpacing: 12, fontWeight: FontWeight.bold),
                maxLength: 6,
                decoration: _inputDecoration('', '● ● ● ● ● ●').copyWith(counterText: ""),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 24),
              const Text('YOUR NAME', style: TextStyle(color: accentGold, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.5)),
              const SizedBox(height: 12),
              TextField(
                controller: _nameController,
                style: const TextStyle(color: Colors.white),
                decoration: _inputDecoration('', 'Enter your name...'),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _joinGame,
                style: ElevatedButton.styleFrom(
                  backgroundColor: accentGold,
                  foregroundColor: primaryBg,
                  minimumSize: const Size(double.infinity, 60),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 8,
                ),
                child: const Text('Join Room', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              ),
            ],
          ),
        ),
      ],
    );
  }
  Widget _buildSuitIcon(String char, Color color) {
    return Text(
      char,
      style: TextStyle(color: color, fontSize: 24),
    );
  }

  Future<void> _hostGame() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      _showError('Please enter your name');
      return;
    }
    try {
      final result = await ref.read(lobbyServiceProvider).createRoom(name);
      final roomCode = result['roomCode']!;
      final playerId = result['playerId']!;
      
      await ref.read(sessionProvider.notifier).saveSession(roomCode, playerId, name);
      if (mounted) {
        Navigator.of(context).push(MaterialPageRoute(builder: (context) => const LobbyScreen()));
      }
    } catch (e) {
      _showError('Failed to host game: $e');
    }
  }

  Future<void> _joinGame() async {
    final name = _nameController.text.trim();
    final code = _codeController.text.trim();
    final existingPlayerId = ref.read(localPlayerIdProvider);

    if (name.isEmpty && existingPlayerId == null) {
      _showError('Please enter your name');
      return;
    }
    if (code.isEmpty) {
      _showError('Room Code is required');
      return;
    }
    try {
      final result = await ref.read(lobbyServiceProvider).joinRoom(
        code, 
        name, 
        existingPlayerId: existingPlayerId
      );
      if (result != null) {
        final playerId = result['playerId']!;
        await ref.read(sessionProvider.notifier).saveSession(code, playerId, name);
        if (mounted) {
          Navigator.of(context).push(MaterialPageRoute(builder: (context) => const LobbyScreen()));
        }
      } else {
        _showError('Invalid Room Code or Room Full');
      }
    } catch (e) {
      _showError('Error joining room: $e');
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.redAccent));
  }
}
