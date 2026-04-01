enum Suit {
  spades('S'),
  hearts('H'),
  diamonds('D'),
  clubs('C');

  final String code;
  const Suit(this.code);

  static Suit fromCode(String code) {
    final cleanCode = code.trim().toUpperCase();
    return Suit.values.firstWhere(
      (e) => e.code == cleanCode,
      orElse: () => Suit.spades,
    );
  }
}

class CardModel {
  final Suit suit;
  final String value; // 'A', 'K', 'Q', 'J', '10', '9', ... '2'
  final int rank;    // 2-14 (A=14)

  CardModel({
    required this.suit,
    required this.value,
    required this.rank,
  });

  String get id => '$value${suit.code}';

  static String getSuit(String cardId) {
    final clean = cardId.trim().toUpperCase();
    if (clean.isEmpty) return 'S';
    return clean.substring(clean.length - 1);
  }

  static int getRankValue(String cardId) {
    final clean = cardId.trim().toUpperCase();
    if (clean.isEmpty) return 0;
    
    // Extract the rank portion (everything but the last character)
    final rankStr = clean.substring(0, clean.length - 1);
    
    switch (rankStr) {
      case 'A': return 14;
      case 'K': return 13;
      case 'Q': return 12;
      case 'J': return 11;
      case '10': return 10;
      default: return int.tryParse(rankStr) ?? 0;
    }
  }

  static CardModel fromId(String id) {
    final suitCode = getSuit(id);
    final value = id.trim().toUpperCase().substring(0, id.trim().length - 1);
    final rank = getRankValue(id);
    
    return CardModel(
      suit: Suit.fromCode(suitCode),
      value: value,
      rank: rank,
    );
  }

  static String getSuitEmoji(String code) {
    switch (code.trim().toUpperCase()) {
      case 'S': return '♠';
      case 'H': return '♥';
      case 'D': return '♦';
      case 'C': return '♣';
      default: return '♠';
    }
  }

  static String getSuitName(String code) {
    switch (code.trim().toUpperCase()) {
      case 'S': return 'Spades';
      case 'H': return 'Hearts';
      case 'D': return 'Diamonds';
      case 'C': return 'Clubs';
      default: return 'Spades';
    }
  }

  @override
  String toString() => id;
}
