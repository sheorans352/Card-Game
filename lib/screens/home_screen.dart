import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: cardDark.withOpacity(0.6),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.menu_book_rounded, color: accentGold, size: 20),
              SizedBox(width: 12),
              Text('HOW TO PLAY', style: TextStyle(color: accentGold, fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 2)),
            ],
          ),
          const SizedBox(height: 24),
          
          _buildRuleCategory('BIDDING'),
          _buildRuleItem(Icons.gavel_rounded, 'Minimum Bid', 'The minimum bid required to play is 2.'),
          _buildRuleItem(Icons.auto_awesome_rounded, 'First 5 Hands', 'Place a bid to change the trump suit during the first 5 hands.'),
          _buildRuleItem(Icons.looks_9_rounded, 'Power Bid', 'Bid 9 or more to change the trump suit even after 23 cards have been played.'),
          
          const SizedBox(height: 20),
          _buildRuleCategory('GAMEPLAY'),
          _buildRuleItem(Icons.spades_rounded, 'Default Trump', 'SPADES is the default trump suit if no high bid is made.'),
          _buildRuleItem(Icons.emoji_events_rounded, 'Play to Win', 'You must play your highest card to win the trick whenever possible (with exceptions).'),
          _buildRuleItem(Icons.style_rounded, 'Follow Lead', 'You must play a card of the leading suit unless you are void of that suit.'),
          _buildRuleItem(Icons.star_rounded, 'Trump Wins', 'Any trump card wins the trick unless a higher trump is played.'),
          
          const SizedBox(height: 20),
          _buildRuleCategory('SCORING'),
          _buildRuleItem(Icons.trending_down_rounded, 'Minus Score', 'Failing to meet your bid reduces your total score by the amount of the bid.'),
          _buildRuleItem(Icons.military_tech_rounded, 'Victory', 'The first player to reach 31 points wins the game!'),
        ],
      ),
    );
  }

  Widget _buildRuleCategory(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, top: 4),
      child: Text(title, style: const TextStyle(color: Colors.white24, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
    );
  }

  Widget _buildRuleItem(IconData icon, String title, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: accentGold.withOpacity(0.7), size: 16),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(description, style: const TextStyle(color: Colors.white54, fontSize: 12, height: 1.4)),
              ],
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
