import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/tehri_provider.dart';

class TehriHomeScreen extends ConsumerStatefulWidget {
  final String? prefilledCode;
  const TehriHomeScreen({super.key, this.prefilledCode});

  @override
  ConsumerState<TehriHomeScreen> createState() => _TehriHomeScreenState();
}

class _TehriHomeScreenState extends ConsumerState<TehriHomeScreen> {
  final _nameController = TextEditingController();
  final _codeController = TextEditingController();
  bool _isHostingTab = true;
  bool _isLoading = false;

  static const Color primaryBg = Color(0xFF100806); // Deep brown mahogany
  static const Color accentCopper = Color(0xFFE67E22);
  static const Color cardDark = Color(0xFF1A1210);

  @override
  void initState() {
    super.initState();
    if (widget.prefilledCode != null) {
      _codeController.text = widget.prefilledCode!;
      _isHostingTab = false;
    }
  }

  Widget _buildTabButton(String label, bool isActive, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            border: isActive ? Border.all(color: accentCopper, width: 1) : null,
            borderRadius: BorderRadius.circular(8),
            color: isActive ? accentCopper.withOpacity(0.1) : Colors.transparent,
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isActive ? accentCopper : Colors.white38,
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
      labelStyle: const TextStyle(color: accentCopper, fontSize: 12, fontWeight: FontWeight.bold),
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.white24),
      filled: true,
      fillColor: Colors.black26,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.white10),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: accentCopper, width: 1),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: primaryBg,
      body: Stack(
        children: [
          // Background Gradient
          Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.center,
                radius: 1.2,
                colors: [Color(0xFF2B1A0D), primaryBg],
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
                      const SizedBox(height: 32),
                      const Text('TEHRI', 
                        style: TextStyle(fontSize: 64, fontWeight: FontWeight.w900, letterSpacing: 8, color: accentCopper, fontFamily: 'Serif')),
                      const Text('CLASSIC INDIAN CARD GAME', 
                        style: TextStyle(fontSize: 10, letterSpacing: 4, color: Colors.white38, fontWeight: FontWeight.w500)),
                      
                      const SizedBox(height: 64),
                      
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(16)),
                        child: Row(children: [
                          _buildTabButton('Host Room', _isHostingTab, () => setState(() => _isHostingTab = true)),
                          _buildTabButton('Join Room', !_isHostingTab, () => setState(() => _isHostingTab = false)),
                        ]),
                      ),
                      
                      const SizedBox(height: 32),

                      if (_isHostingTab) _buildHostForm() else _buildJoinForm(),
                      
                      const SizedBox(height: 48),
                      _buildHowToPlay(),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Back Button
          Positioned(
            top: 16, left: 16,
            child: GestureDetector(
              onTap: () => context.go('/'),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black45,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: accentCopper.withOpacity(0.3)),
                ),
                child: Row(
                  children: const [
                    Icon(Icons.arrow_back_ios_new, color: accentCopper, size: 14),
                    SizedBox(width: 8),
                    Text('GAMES HUB', style: TextStyle(color: accentCopper, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1)),
                  ],
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
        color: cardDark,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('ENTRY NAME', style: TextStyle(color: accentCopper, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.5)),
          const SizedBox(height: 12),
          TextField(
            controller: _nameController,
            style: const TextStyle(color: Colors.white),
            decoration: _inputDecoration('', 'Enter your name...'),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _isLoading ? null : _hostGame,
            style: ElevatedButton.styleFrom(
              backgroundColor: accentCopper,
              foregroundColor: Colors.black,
              minimumSize: const Size(double.infinity, 60),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 8,
            ),
            child: _isLoading 
              ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
              : const Text('CREATE ROOM', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 2)),
          ),
        ],
      ),
    );
  }

  Widget _buildJoinForm() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: cardDark,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('ROOM CODE', style: TextStyle(color: accentCopper, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.5)),
          const SizedBox(height: 12),
          TextField(
            controller: _codeController,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontSize: 32, letterSpacing: 8, fontWeight: FontWeight.bold),
            maxLength: 6,
            decoration: _inputDecoration('', 'Enter code...').copyWith(counterText: ""),
          ),
          const SizedBox(height: 24),
          const Text('ENTRY NAME', style: TextStyle(color: accentCopper, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.5)),
          const SizedBox(height: 12),
          TextField(
            controller: _nameController,
            style: const TextStyle(color: Colors.white),
            decoration: _inputDecoration('', 'Enter your name...'),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _isLoading ? null : _joinGame,
            style: ElevatedButton.styleFrom(
              backgroundColor: accentCopper,
              foregroundColor: Colors.black,
              minimumSize: const Size(double.infinity, 60),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 8,
            ),
            child: _isLoading 
              ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
              : const Text('JOIN ROOM', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 2)),
          ),
        ],
      ),
    );
  }

  Widget _buildHowToPlay() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: cardDark.withOpacity(0.5),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        children: const [
          Icon(Icons.style, color: accentCopper, size: 32),
          SizedBox(height: 16),
          Text('Quick Rules', style: TextStyle(color: accentCopper, fontWeight: FontWeight.bold)),
          SizedBox(height: 12),
          Text('● 4 Players in 2 Teams (Opposites)\n● Bid 7+ Tricks to Win\n● Successful Bid: Points Down\n● Failed Bid: Points Double',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white54, fontSize: 12, height: 1.6),
          ),
        ],
      ),
    );
  }

  Future<void> _hostGame() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    setState(() => _isLoading = true);
    try {
      final res = await ref.read(tehriOpsProvider).createRoom(name);
      await ref.read(tehriSessionProvider.notifier).saveSession(res['roomCode']!, res['roomId']!, res['playerId']!, name);
      if (mounted) context.go('/tehri/lobby/${res['roomId']}');
    } catch (e) {
      debugPrint('Error hosting: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _joinGame() async {
    final name = _nameController.text.trim();
    final code = _codeController.text.trim();
    if (name.isEmpty || code.isEmpty) return;
    setState(() => _isLoading = true);
    try {
      final res = await ref.read(tehriOpsProvider).joinRoom(code, name);
      if (res != null) {
        await ref.read(tehriSessionProvider.notifier).saveSession(code, res['roomId']!, res['playerId']!, name);
        if (mounted) context.go('/tehri/lobby/${res['roomId']}');
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint('Error joining: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }
}
