// Matka game table screen — the heart of the betting action
// Independent of lib/games/minus/

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/matka_provider.dart';
import '../models/matka_models.dart';
import '../models/card_model.dart';
import '../widgets/playing_card_widget.dart';
import '../widgets/pot_display.dart';
import '../widgets/player_seat.dart';

class MatkaGameTableScreen extends ConsumerStatefulWidget {
  final String roomId;
  const MatkaGameTableScreen({super.key, required this.roomId});

  @override
  ConsumerState<MatkaGameTableScreen> createState() => _MatkaGameTableScreenState();
}

class _MatkaGameTableScreenState extends ConsumerState<MatkaGameTableScreen> with SingleTickerProviderStateMixin {
  final _betCtrl = TextEditingController();
  late AnimationController _revealCtrl;
  bool _isAnimating = false;
  int? _selectedMultipleOverride;
  String? _lastEvent;
  bool _showEvent = false;

  static const _bg = Color(0xFF100820);
  static const _purple = Color(0xFF9B59B6);
  static const _gold = Color(0xFFFFD700);
  static const _cardDark = Color(0xFF1A0D2B);

  @override
  void initState() {
    super.initState();
    _revealCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
  }

  @override
  void dispose() {
    _betCtrl.dispose();
    _revealCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final roomAsync = ref.watch(matkaRoomByIdProvider(widget.roomId));
    final playersAsync = ref.watch(matkaPlayersProvider(widget.roomId));
    final isMyTurn = ref.watch(isMyMatkaTurnProvider(widget.roomId));
    final localId = ref.watch(matkaPlayerIdProvider);

    return Scaffold(
      backgroundColor: _bg,
      body: roomAsync.when(
        data: (room) {
          if (room == null) return const Center(child: Text('Room closed', style: TextStyle(color: Colors.white)));
          
          if (room.status == 'ended') {
            Future.microtask(() => Navigator.of(context).popUntil((route) => route.isFirst));
          }

          // Update last event based on room changes
          if (room.middleCard != null && !_showEvent) {
             final prevPIndex = (room.currentPlayerIndex > 0) ? (room.currentPlayerIndex - 1) : (playersAsync.value?.length ?? 1) - 1;
             final pName = (playersAsync.value != null && playersAsync.value!.isNotEmpty) 
                ? playersAsync.value![prevPIndex % playersAsync.value!.length].name 
                : 'Someone';
             _triggerEvent('$pName bet ${room.currentBet}!');
          }

          return playersAsync.when(
            data: (players) {
              final me = players.firstWhere((p) => p.id == localId, orElse: () => players.first);
              final activePlayer = players[room.currentPlayerIndex % players.length];

              return Container(
                decoration: const BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.center,
                    radius: 1.5,
                    colors: [Color(0xFF2D1B4E), _bg],
                  ),
                ),
                child: SafeArea(
                  child: Stack(
                    children: [
                      Column(
                        children: [
                          _buildTopBar(room),
                          const SizedBox(height: 16),
                          _buildPlayersRow(players, room.currentPlayerIndex, localId),
                          const Spacer(),
                          _buildTable(room, activePlayer, isMyTurn),
                          const Spacer(),
                          if (room.status == 'shuffling')
                            _buildShufflingView(room, me.isHost, players)
                          else if (isMyTurn && room.status == 'betting')
                            _buildBettingControls(room, me, players)
                          else if (room.status == 'round_result')
                            _buildResultOverlay(room, activePlayer)
                          else
                            _buildWaitingIndicator(activePlayer),
                          const SizedBox(height: 24),
                        ],
                      ),
                      if (_showEvent) _buildNotificationBanner(),
                    ],
                  ),
                ),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator(color: _purple)),
            error: (e, s) => Center(child: Text('Error: $e')),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator(color: _purple)),
        error: (e, s) => Center(child: Text('Error: $e')),
      ),
    );
  }

  Widget _buildTopBar(MatkaRoom room) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('ROUND ${room.roundNumber}', style: const TextStyle(color: _gold, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 2)),
              Text('${room.cardsRemaining} cards in shoe', style: const TextStyle(color: Colors.white24, fontSize: 10)),
            ],
          ),
          MatkaPotDisplay(potAmount: room.potAmount, anteAmount: room.anteAmount),
          IconButton(
            onPressed: () => _showQuitConfirm(context),
            icon: const Icon(Icons.exit_to_app_rounded, color: Colors.white24),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayersRow(List<MatkaPlayer> players, int currentIndex, String? localId) {
    return SizedBox(
      height: 90,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        itemCount: players.length,
        itemBuilder: (context, index) {
          final p = players[index];
          return MatkaPlayerSeat(
            player: p,
            isActive: index == (currentIndex % players.length),
            isLocalPlayer: p.id == localId,
          );
        },
      ),
    );
  }

  Widget _buildTable(MatkaRoom room, MatkaPlayer activePlayer, bool isMyTurn) {
    final p1 = room.leftPillar != null ? MatkaCard.fromId(room.leftPillar!) : null;
    final p2 = room.rightPillar != null ? MatkaCard.fromId(room.rightPillar!) : null;
    final spread = (p1 != null && p2 != null) ? MatkaCard.spread(p1, p2) : 0;

    return Column(
      children: [
        // Removed Spread count display as requested
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Left Pillar
            MatkaPlayingCard(cardId: room.leftPillar, width: 85, height: 120, elevated: true),
            const SizedBox(width: 24),
            // Middle Card with Reveal Animation
            SizedBox(
              width: 90,
              height: 125,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 600),
                transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: FadeTransition(opacity: anim, child: child)),
                child: (room.status == 'round_result' || room.middleCard != null)
                  ? MatkaPlayingCard(key: ValueKey(room.middleCard), cardId: room.middleCard, width: 90, height: 125, elevated: true)
                  : _buildMiddlePlaceholder(isMyTurn),
              ),
            ),
            const SizedBox(width: 24),
            // Right Pillar
            MatkaPlayingCard(cardId: room.rightPillar, width: 85, height: 120, elevated: true),
          ],
        ),
      ],
    );
  }

  Widget _buildMiddlePlaceholder(bool isMyTurn) {
    return Container(
      width: 90,
      height: 125,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.02),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isMyTurn ? _gold.withOpacity(0.2) : Colors.white.withOpacity(0.05), style: BorderStyle.solid),
      ),
      child: Center(
        child: Opacity(
          opacity: 0.1,
          child: Icon(Icons.help_outline_rounded, size: 40, color: isMyTurn ? _gold : Colors.white),
        ),
      ),
    );
  }

  Widget _buildBettingControls(MatkaRoom room, MatkaPlayer me, List<MatkaPlayer> players) {
    return Container(
      padding: const EdgeInsets.all(24),
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: _cardDark.withOpacity(0.9),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _gold.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          const Text('IT\'S YOUR TURN!', style: TextStyle(color: _gold, fontWeight: FontWeight.w900, fontSize: 14, letterSpacing: 2)),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _betCtrl,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.attach_money_rounded, color: _gold),
                    hintText: 'BET...',
                    hintStyle: const TextStyle(color: Colors.white10),
                    filled: true,
                    fillColor: Colors.black26,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _buildAddSubButton(Icons.remove_rounded, () => _adjustBet(-( _selectedMultipleOverride ?? room.betMultiple ))),
              _buildAddSubButton(Icons.add_rounded, () => _adjustBet( _selectedMultipleOverride ?? room.betMultiple )),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () => _betCtrl.text = room.potAmount.toString(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _gold,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  minimumSize: const Size(60, 48),
                ),
                child: const Text('POT', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildMultipleSelector(room),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _isAnimating ? null : () => _onBet(room, me, players),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _purple,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(0, 56),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('PLACE BET', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton(
                  onPressed: _isAnimating ? null : () => _onPass(room, me, players),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white60,
                    minimumSize: const Size(0, 56),
                    side: const BorderSide(color: Colors.white24),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('PASS'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildResultOverlay(MatkaRoom room, MatkaPlayer activePlayer) {
    if (room.middleCard == null) return const SizedBox.shrink();
    
    final p1 = MatkaCard.fromId(room.leftPillar!);
    final p2 = MatkaCard.fromId(room.rightPillar!);
    final middle = MatkaCard.fromId(room.middleCard!);
    final res = MatkaCard.evaluate(p1, p2, middle);

    String text;
    Color color;
    IconData icon;

    switch (res) {
      case MatkaResult.win:
        text = 'WIN! +${room.currentBet}';
        color = const Color(0xFF2ECC71);
        icon = Icons.emoji_events_rounded;
        break;
      case MatkaResult.loss:
        text = 'LOSE! -${room.currentBet}';
        color = const Color(0xFFE74C3C);
        icon = Icons.cancel_rounded;
        break;
      case MatkaResult.post:
        text = 'POSTED! -${(room.currentBet ?? 0) * 2}';
        color = const Color(0xFFE67E22);
        icon = Icons.warning_rounded;
        break;
      case MatkaResult.pass:
        text = 'PASSED';
        color = Colors.white54;
        icon = Icons.skip_next_rounded;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: color.withOpacity(0.5), width: 2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(width: 12),
          Text(
            text,
            style: TextStyle(color: color, fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: 1),
          ),
        ],
      ),
    );
  }

  Widget _buildWaitingIndicator(MatkaPlayer activePlayer) {
    return Column(
      children: [
        const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(color: _purple, strokeWidth: 2),
        ),
        const SizedBox(height: 16),
        Text(
          'WAITING FOR ${activePlayer.name.toUpperCase()}...',
          style: const TextStyle(color: Colors.white24, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 2),
        ),
      ],
    );
  }

  Widget _buildShufflingView(MatkaRoom room, bool isHost, List<MatkaPlayer> players) {
    bool isEmpty = room.leftPillar == null && room.rightPillar == null; // Simple heuristic for initial shuffle or empty shoe

    return Center(
      child: Container(
        padding: const EdgeInsets.all(24),
        margin: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: _cardDark,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: _purple.withOpacity(0.5)),
        ),
        child: Column(
          children: [
            const SizedBox(
              width: 40, height: 40,
              child: CircularProgressIndicator(color: _purple, strokeWidth: 3),
            ),
            const SizedBox(height: 24),
            Text(
              isEmpty ? 'PREPARING FIRST DEAL...' : 'SHOE EMPTY - RESHUFFLING...',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 2),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text('CARDS ARE BEING RANDOMIZED', style: TextStyle(color: Colors.white38, fontSize: 10, letterSpacing: 1)),
            
            if (isHost && !isEmpty) ...[
              const SizedBox(height: 24),
              const Text('Add more decks to continue:', style: TextStyle(color: _purple, fontSize: 10, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Row(
                children: [1, 2, 3, 4].map((d) => Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: ElevatedButton(
                      onPressed: () => ref.read(matkaGameServiceProvider).reshuffleShoe(room, newDeckCount: d),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: d == room.deckCount ? _purple : Colors.white.withOpacity(0.05),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: Text('$d', style: const TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                )).toList(),
              ),
            ] else if (isHost && isEmpty) ...[
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () => ref.read(matkaGameServiceProvider).dealPillars(room, players),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _purple,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('DEAL CARDS', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMultipleSelector(MatkaRoom room) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [5, 10, 20, 50, 100].map((m) {
          final isSelected = (_selectedMultipleOverride ?? room.betMultiple) == m;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: ChoiceChip(
              label: Text('x$m'),
              selected: isSelected,
              onSelected: (val) {
                if (val) setState(() => _selectedMultipleOverride = m);
              },
              selectedColor: _gold.withOpacity(0.2),
              backgroundColor: Colors.white.withOpacity(0.05),
              labelStyle: TextStyle(
                color: isSelected ? _gold : Colors.white38,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
              side: BorderSide(color: isSelected ? _gold : Colors.white10),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildAddSubButton(IconData icon, VoidCallback onTap) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white10),
      ),
      child: IconButton(
        icon: Icon(icon, color: _gold, size: 20),
        onPressed: onTap,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
      ),
    );
  }

  void _adjustBet(int delta) {
    final current = int.tryParse(_betCtrl.text) ?? 0;
    final newValue = (current + delta).clamp(0, 999999);
    _betCtrl.text = newValue.toString();
  }

  void _onBet(MatkaRoom room, MatkaPlayer me, List<MatkaPlayer> players) async {
    final amount = int.tryParse(_betCtrl.text) ?? 0;
    if (amount <= 0) {
      _showError('Enter a valid amount');
      return;
    }
    if (amount > room.potAmount) {
      _showError('Cannot bet more than the pot (${room.potAmount})');
      return;
    }

    setState(() {
      _isAnimating = true;
      _triggerEvent('YOU PLACED A BET OF $amount!');
    });
    
    _betCtrl.clear();
    await ref.read(matkaGameServiceProvider).placeBet(room, me, players, amount);
    setState(() => _isAnimating = false);
  }

  void _triggerEvent(String msg) {
    setState(() {
      _lastEvent = msg;
      _showEvent = true;
    });
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted) setState(() => _showEvent = false);
    });
  }

  Widget _buildNotificationBanner() {
    return Positioned(
      top: 10, left: 20, right: 20,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 300),
        opacity: _showEvent ? 1 : 0,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: _gold,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [BoxShadow(color: Colors.black45, blurRadius: 10)],
          ),
          child: Row(
            children: [
              const Icon(Icons.flash_on_rounded, color: Colors.black, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(_lastEvent ?? '', style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 13)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _onPass(MatkaRoom room, MatkaPlayer me, List<MatkaPlayer> players) async {
    setState(() => _isAnimating = true);
    await ref.read(matkaGameServiceProvider).passTurn(room, me, players);
    setState(() => _isAnimating = false);
  }

  void _showError(String m) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m), backgroundColor: Colors.redAccent));
  }

  void _showQuitConfirm(BuildContext context) {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: _cardDark,
        title: const Text('QUIT GAME?', style: TextStyle(color: Colors.white)),
        content: const Text('Do you really want to leave the game?', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('NO', style: TextStyle(color: Colors.white24))),
          TextButton(
            onPressed: () {
              Navigator.pop(c);
              ref.read(matkaSessionProvider.notifier).clear();
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
            child: const Text('YES, QUIT', style: TextStyle(color: _gold, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
