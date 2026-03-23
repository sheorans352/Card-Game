enum Suit {
  spades('S'),
  hearts('H'),
  diamonds('D'),
  clubs('C');

  final String code;
  const Suit(this.code);

  static Suit fromCode(String code) {
    return Suit.values.firstWhere((e) => e.code == code);
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

  static CardModel fromId(String id) {
    final value = id.substring(0, id.length - 1);
    final suitCode = id.substring(id.length - 1);
    final suit = Suit.fromCode(suitCode);
    
    int rank;
    switch (value) {
      case 'A': rank = 14; break;
      case 'K': rank = 13; break;
      case 'Q': rank = 12; break;
      case 'J': rank = 11; break;
      default: rank = int.parse(value);
    }

    return CardModel(suit: suit, value: value, rank: rank);
  }

  @override
  String toString() => id;
}
