import '../models/card_model.dart';

class CardService {
  List<CardModel> generateDeck() {
    final List<CardModel> deck = [];
    for (final suit in Suit.values) {
      for (int r = 2; r <= 14; r++) {
        String val;
        if (r == 14) val = 'A';
        else if (r == 13) val = 'K';
        else if (r == 12) val = 'Q';
        else if (r == 11) val = 'J';
        else val = r.toString();
        deck.add(CardModel(suit: suit, value: val, rank: r));
      }
    }
    return deck..shuffle();
  }

  Future<void> shuffleDeck(String roomId) async {
    print("Mock: Shuffle Deck");
  }

  Future<void> cutDeck(String roomId, int cutPoint) async {
    print("Mock: Cut Deck at $cutPoint");
  }

  Future<void> dealInitialFive(String roomId, List<String> playerIds) async {
    print("Mock: Deal Initial 5");
  }

  Future<void> dealRemainingEight(String roomId, List<String> playerIds) async {
    print("Mock: Deal Remaining 8");
  }

  Future<void> placeBid(String roomId, String playerId, int bid, {String? suit}) async {
    print("Mock: Bid $bid, Suit $suit");
  }

  Future<void> playCard(String roomId, String playerId, String cardValue) async {
    print("Mock: Play Card $cardValue");
  }

  Future<bool> validateMove(String roomId, String playerId, String cardValue, List<Map<String, dynamic>> currentTrick, List<String> playerHand, String? trumpSuit) async {
    return true;
  }
}
