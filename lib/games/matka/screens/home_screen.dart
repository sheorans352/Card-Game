// Matka home screen — host or join a room
// Independent of lib/games/minus/

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/matka_provider.dart';
import 'lobby_screen.dart';

class MatkaHomeScreen extends ConsumerStatefulWidget {
  const MatkaHomeScreen({super.key});

  @override
  ConsumerState<MatkaHomeScreen> createState() => _MatkaHomeScreenState();
}

class _MatkaHomeScreenState extends ConsumerState<MatkaHomeScreen> {
  final _nameCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  bool _isHosting = true;
  int _deckCount = 1;
  int _anteAmount = 100;
  int _betMultiple = 10;
  bool _loading = false;
  MatkaRoom? _previewRoom;

  static const _bg = Color(0xFF100820);
  static const _purple = Color(0xFF9B59B6);
  static const _gold = Color(0xFFFFD700);
  static const _card = Color(0xFF1A0D2B);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final name = ref.read(matkaPlayerNameProvider);
      if (name != null) _nameCtrl.text = name;
      _checkInitialSession();
    });

    _codeCtrl.addListener(_onCodeChanged);
  }

  void _onCodeChanged() async {
    final code = _codeCtrl.text.trim();
    if (code.length == 6) {
      try {
        final data = await Supabase.instance.client
            .from('matka_rooms')
            .select()
            .eq('code', code.toUpperCase())
            .maybeSingle();

        if (data != null && mounted) {
          setState(() => _previewRoom = MatkaRoom.fromMap(data));
        }
      } catch (_) {
        if (mounted) setState(() => _previewRoom = null);
      }
    } else {
      if (_previewRoom != null) setState(() => _previewRoom = null);
    }
  }

  void _checkInitialSession() {
    final state = GoRouterState.of(context);
    final urlCode = state.uri.queryParameters['room'] ?? state.uri.queryParameters['code'];
    if (urlCode != null && urlCode.isNotEmpty) {
      setState(() {
        _codeCtrl.text = urlCode;
        _isHosting = false;
      });
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _codeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: Stack(
        children: [
          // Gradient background
          Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(-0.3, -0.5),
                radius: 1.4,
                colors: [Color(0xFF2D1B4E), _bg],
              ),
            ),
          ),

          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(
                    children: [
                      const SizedBox(height: 32),
                      // Title
                      ShaderMask(
                        shaderCallback: (b) => const LinearGradient(
                          colors: [_gold, _purple, _gold],
                        ).createShader(b),
                        child: const Text(
                          'MATKA',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 64,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 6,
                          ),
                        ),
                      ),
                      const Text(
                        'IN-BETWEEN BETTING GAME',
                        style: TextStyle(
                          color: Colors.white38,
                          fontSize: 11,
                          letterSpacing: 4,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Removed decorative emojis
                      const SizedBox(height: 40),

                      // Tab selector
                      _tabSelector(),
                      const SizedBox(height: 28),

                      if (_isHosting) _hostForm() else _joinForm(),
                      const SizedBox(height: 40),
                      _rulesSection(),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Back button
          Positioned(
            top: 0, left: 0, right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.only(left: 12, top: 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: GestureDetector(
                    onTap: () => context.go('/'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: _gold.withOpacity(0.3)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.arrow_back_ios_new_rounded, color: _gold, size: 12),
                          SizedBox(width: 6),
                          Text('GAMES HUB',
                              style: TextStyle(
                                  color: _gold,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.5)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tabSelector() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
          color: Colors.black26, borderRadius: BorderRadius.circular(12)),
      child: Row(children: [
        _tab('Host Game', _isHosting, () => setState(() => _isHosting = true)),
        _tab('Join Game', !_isHosting, () => setState(() => _isHosting = false)),
      ]),
    );
  }

  Widget _tab(String label, bool active, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: active ? _purple.withOpacity(0.2) : Colors.transparent,
            border: active ? Border.all(color: _purple, width: 1) : null,
          ),
          child: Text(label,
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: active ? _purple : Colors.white38,
                  fontWeight: FontWeight.bold,
                  fontSize: 15)),
        ),
      ),
    );
  }

  Widget _hostForm() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _card.withOpacity(0.9),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _purple.withOpacity(0.2)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _label('YOUR NAME'),
        const SizedBox(height: 10),
        _field(_nameCtrl, 'Enter your name...'),
        const SizedBox(height: 24),

        _label('NUMBER OF DECKS (1–4)'),
        const SizedBox(height: 10),
        Row(
          children: List.generate(4, (i) {
            final n = i + 1;
            final sel = n == _deckCount;
            return Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _deckCount = n),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: sel ? _purple.withOpacity(0.25) : Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: sel ? _purple : Colors.white12),
                  ),
                  child: Column(children: [
                    Text('$n', style: TextStyle(color: sel ? _purple : Colors.white54, fontSize: 20, fontWeight: FontWeight.bold)),
                    Text(n == 1 ? 'deck' : 'decks', style: const TextStyle(color: Colors.white24, fontSize: 9)),
                  ]),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 8),
        Text('${_deckCount * 52} cards in shoe',
            style: const TextStyle(color: Colors.white38, fontSize: 11)),

        const SizedBox(height: 24),
        _label('BETTING MULTIPLE (STEP)'),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          children: [5, 10, 20, 50, 100].map((v) {
            final sel = v == _betMultiple;
            return ChoiceChip(
              label: Text('x$v'),
              selected: sel,
              onSelected: (_) => setState(() => _betMultiple = v),
              selectedColor: _purple.withOpacity(0.3),
              backgroundColor: Colors.white.withOpacity(0.05),
              labelStyle: TextStyle(color: sel ? _purple : Colors.white54, fontWeight: FontWeight.bold),
              side: BorderSide(color: sel ? _purple : Colors.white12),
            );
          }).toList(),
        ),

        const SizedBox(height: 28),
        _primaryButton('Create Room & Get Link', _loading ? null : _hostGame),
      ]),
    );
  }

  Widget _joinForm() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _card.withOpacity(0.9),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _purple.withOpacity(0.2)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _label('ROOM CODE'),
        const SizedBox(height: 10),
        TextField(
          controller: _codeCtrl,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white, fontSize: 24, letterSpacing: 10, fontWeight: FontWeight.bold),
          maxLength: 6,
          keyboardType: TextInputType.number,
          decoration: _inputDec('', '● ● ● ●  ● ●').copyWith(counterText: ''),
        ),
        const SizedBox(height: 16),
        _label('YOUR NAME'),
        const SizedBox(height: 10),
        _field(_nameCtrl, 'Enter your name...'),
        const SizedBox(height: 24),
        if (_previewRoom != null) _buildRoomPreview(),
        const SizedBox(height: 24),
        _primaryButton('Join Room', _loading ? null : _joinGame),
      ]),
    );
  }

  Widget _buildRoomPreview() {
    final r = _previewRoom!;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _purple.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _purple.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('ROOM RULES',
              style: TextStyle(color: _purple, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 2)),
          const SizedBox(height: 12),
          _previewRow('Ante', '${r.anteAmount} Chips'),
          _previewRow('Step', 'x${r.betMultiple}'),
          _previewRow('Decks', '${r.deckCount} (${r.totalShoeSize} cards)'),
        ],
      ),
    );
  }

  Widget _previewRow(String label, String val) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(color: Colors.white38, fontSize: 12)),
            Text(val, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
          ],
        ),
      );

  Widget _label(String t) => Text(t,
      style: const TextStyle(
          color: Color(0xFF9B59B6),
          fontSize: 10,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.5));

  Widget _field(TextEditingController ctrl, String hint) => TextField(
        controller: ctrl,
        style: const TextStyle(color: Colors.white),
        decoration: _inputDec('', hint),
      );

  InputDecoration _inputDec(String label, String hint) => InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: _purple),
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white24),
        filled: true,
        fillColor: Colors.black26,
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Colors.white10)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: _purple)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      );

  Widget _primaryButton(String label, VoidCallback? onTap) => ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: _purple,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 54),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 6,
        ),
        child: _loading
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            : Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      );

  Future<void> _hostGame() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) { _err('Enter your name'); return; }
    setState(() => _loading = true);
    try {
      final result = await ref.read(matkaLobbyServiceProvider).createRoom(
        name: name,
        deckCount: _deckCount,
        anteAmount: _anteAmount,
        betMultiple: _betMultiple,
      );
      await ref.read(matkaSessionProvider.notifier)
          .save(result['roomCode']!, result['playerId']!, name);
      if (mounted) {
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => MatkaLobbyScreen(roomId: result['roomId']!),
        ));
      }
    } catch (e) {
      _err('Failed to create room: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _joinGame() async {
    final name = _nameCtrl.text.trim();
    final code = _codeCtrl.text.trim();
    if (name.isEmpty) { _err('Enter your name'); return; }
    if (code.length != 6) { _err('Enter the 6-digit room code'); return; }
    setState(() => _loading = true);
    try {
      final result = await ref.read(matkaLobbyServiceProvider).joinRoom(code, name);
      if (result == null) { _err('Room not found or full'); return; }
      await ref.read(matkaSessionProvider.notifier)
          .save(result['roomCode']!, result['playerId']!, name);
      if (mounted) {
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => MatkaLobbyScreen(roomId: result['roomId']!),
        ));
      }
    } catch (e) {
      _err('Failed to join: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _err(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.redAccent));
  }

  Widget _rulesSection() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _card.withOpacity(0.7),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _purple.withOpacity(0.15)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [
          Icon(Icons.menu_book_rounded, color: _gold, size: 20),
          SizedBox(width: 10),
          Text('HOW TO PLAY: MATKA',
              style: TextStyle(color: _gold, fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 2)),
        ]),
        const SizedBox(height: 20),
        _rule('THE POT', 'Everyone antes each round. That\'s your shared prize pool.'),
        _rule('THE PILLARS', 'Two cards are dealt face-up. The gap between them is your "spread."'),
        _rule('WIN', 'Bet any amount ≤ pot. If the 3rd card falls strictly between your two pillars, you win that amount from the pot.'),
        _rule('LOSS', 'If the 3rd card is outside your pillars, your bet is added to the pot.'),
        _rule('POST', 'If the 3rd card exactly matches one of your pillars, you pay DOUBLE your bet into the pot.'),
        _rule('PASS', 'If the spread is too tight, pass. New pillars are dealt for the next player.'),
        _rule('RESHUFFLE', 'When the shoe runs out, the host reshuffles (and can optionally add more decks).'),
      ]),
    );
  }

  Widget _rule(String icon, String desc) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: RichText(
          text: TextSpan(
            style: const TextStyle(color: Colors.white60, fontSize: 12, height: 1.5),
            children: [
              TextSpan(text: '$icon  ', style: const TextStyle(fontSize: 14)),
              TextSpan(text: desc),
            ],
          ),
        ),
      );
}
