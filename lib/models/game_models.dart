class Room {
  final String id;
  final String code;
  final String status;
  final String? trumpSuit;
  final bool trumpLocked;
  final int dealerIndex;
  final int turnIndex;
  final String? currentPhase;
  final List<String> shuffledDeck;
  final int? deckCutValue;

  Room({
    required this.id,
    required this.code,
    required this.status,
    this.trumpSuit,
    this.trumpLocked = false,
    this.dealerIndex = 0,
    this.turnIndex = 0,
    this.currentPhase,
    this.shuffledDeck = const [],
    this.deckCutValue,
  });

  factory Room.fromMap(Map<String, dynamic> map) {
    return Room(
      id: map['id'],
      code: map['code'],
      status: map['status'],
      trumpSuit: map['trump_suit'],
      trumpLocked: map['trump_locked'] ?? false,
      dealerIndex: map['dealer_index'] ?? 0,
      turnIndex: map['turn_index'] ?? 0,
      currentPhase: map['current_phase'],
      shuffledDeck: List<String>.from(map['shuffled_deck'] ?? []),
      deckCutValue: map['deck_cut_value'],
    );
  }
}

class Player {
  final String id;
  final String roomId;
  final String name;
  final bool isHost;
  final int? bid;
  final int tricksWon;
  final int totalScore;

  Player({
    required this.id,
    required this.roomId,
    required this.name,
    required this.isHost,
    this.bid,
    this.tricksWon = 0,
    this.totalScore = 0,
  });

  factory Player.fromMap(Map<String, dynamic> map) {
    return Player(
      id: map['id'],
      roomId: map['room_id'],
      name: map['name'],
      isHost: map['is_host'] ?? false,
      bid: map['bid'],
      tricksWon: map['tricks_won'] ?? 0,
      totalScore: map['total_score'] ?? 0,
    );
  }
}
