import 'package:flutter/material.dart';
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
    final code = Uri.base.queryParameters['code'];
    if (code != null) {
      _codeController.text = code;
      _isHostingTab = false; // Switch to join tab if code is provided
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(currentRoomCodeProvider.notifier).state = code;
      });
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
                          Icon(Icons.spades, color: Colors.white.withOpacity(0.15), size: 24),
                          const SizedBox(width: 16),
                          Icon(Icons.favorite, color: Colors.red.withOpacity(0.5), size: 24),
                          const SizedBox(width: 16),
                          const Icon(Icons.diamond, color: Colors.blue, size: 24),
                          const SizedBox(width: 16),
                          Icon(Icons.clubs, color: Colors.white.withOpacity(0.15), size: 24),
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

                      if (_isHostingTab) ...[
                        _buildHostForm(),
                      ] else ...[
                        _buildJoinForm(),
                      ],
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
        ],
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
              // Simplified 6-dot or digit display
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

  Future<void> _hostGame() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      _showError('Please enter your name');
      return;
    }
    try {
      final result = await ref.read(lobbyServiceProvider).createRoom(name);
      ref.read(currentRoomCodeProvider.notifier).state = result['roomCode'];
      ref.read(localPlayerIdProvider.notifier).state = result['playerId'];
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
    if (name.isEmpty || code.isEmpty) {
      _showError('Name and Room Code are required');
      return;
    }
    try {
      final result = await ref.read(lobbyServiceProvider).joinRoom(code, name);
      if (result != null) {
        ref.read(currentRoomCodeProvider.notifier).state = code;
        ref.read(localPlayerIdProvider.notifier).state = result['playerId'];
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
