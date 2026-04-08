// Matka's own card model — fully independent of lib/games/minus/
// Do NOT import from lib/games/minus/ here or anywhere in lib/games/matka/

enum MatkaCardSuit {
  spades('S', '♠', false),
  hearts('H', '♥', true),
  diamonds('D', '♦', true),
  clubs('C', '♣', false);

  final String code;
  final String symbol;
  final bool isRed;
  const MatkaCardSuit(this.code, this.symbol, this.isRed);

  static MatkaCardSuit fromCode(String code) => MatkaCardSuit.values.firstWhere(
        (s) => s.code == code.trim().toUpperCase(),
        orElse: () => MatkaCardSuit.spades,
      );
}

/// A single playing card in the Matka game.
/// Ace is HIGH (rank 14).  Ranks: 2–14.
class MatkaCard {
  final MatkaCardSuit suit;
  final String value; // '2'–'10', 'J', 'Q', 'K', 'A'
  final int rank; // 2–14

  const MatkaCard({
    required this.suit,
    required this.value,
    required this.rank,
  });

  String get id => '$value${suit.code}';
  bool get isRed => suit.isRed;
  String get suitSymbol => suit.symbol;

  static int rankFromValue(String v) {
    switch (v.trim().toUpperCase()) {
      case 'A':
        return 14;
      case 'K':
        return 13;
      case 'Q':
        return 12;
      case 'J':
        return 11;
      default:
        return int.tryParse(v.trim()) ?? 2;
    }
  }

  static MatkaCard fromId(String id) {
    final clean = id.trim().toUpperCase();
    final suitCode = clean[clean.length - 1];
    final value = clean.substring(0, clean.length - 1);
    return MatkaCard(
      suit: MatkaCardSuit.fromCode(suitCode),
      value: value,
      rank: rankFromValue(value),
    );
  }

  /// Build a full shoe of [deckCount] standard 52-card decks.
  static List<String> buildShoe(int deckCount) {
    const suits = ['S', 'H', 'D', 'C'];
    const values = ['2', '3', '4', '5', '6', '7', '8', '9', '10', 'J', 'Q', 'K', 'A'];
    final cards = <String>[];
    for (var d = 0; d < deckCount; d++) {
      for (final s in suits) {
        for (final v in values) {
          cards.add('$v$s');
        }
      }
    }
    return cards;
  }

  static List<String> shuffled(List<String> cards) {
    final list = List<String>.from(cards);
    list.shuffle();
    return list;
  }

  /// Number of strictly in-between values given two pillars.
  static int spread(MatkaCard p1, MatkaCard p2) {
    final lo = p1.rank < p2.rank ? p1.rank : p2.rank;
    final hi = p1.rank > p2.rank ? p1.rank : p2.rank;
    final s = hi - lo - 1;
    return s < 0 ? 0 : s;
  }

  /// Evaluate the middle card against the two (sorted) pillars.
  static MatkaResult evaluate(MatkaCard p1, MatkaCard p2, MatkaCard middle) {
    final lo = p1.rank < p2.rank ? p1.rank : p2.rank;
    final hi = p1.rank > p2.rank ? p1.rank : p2.rank;
    if (middle.rank == lo || middle.rank == hi) return MatkaResult.post;
    if (middle.rank > lo && middle.rank < hi) return MatkaResult.win;
    return MatkaResult.loss;
  }

  @override
  String toString() => id;
}

enum MatkaResult { win, loss, post, pass }
