class Room {
  final String id;
  final String code;
  final String status;
  final String hostId;
  final String? trumpSuit;
  final bool trumpLocked;
  final int dealerIndex;
  final int turnIndex;
  final String? currentPhase;
  final List<String> shuffledDeck;
  final int? deckCutValue;
  final int currentRound;
  final int highestBid;
  final String? highestBidderId;
  final int passCount;

  Room({
    required this.id,
    required this.code,
    required this.status,
    required this.hostId,
    this.trumpSuit,
    this.trumpLocked = false,
    this.dealerIndex = 0,
    this.turnIndex = 0,
    this.currentPhase,
    this.shuffledDeck = const [],
    this.deckCutValue,
    this.currentRound = 1,
    this.highestBid = 0,
    this.highestBidderId,
    this.passCount = 0,
  });

  factory Room.fromMap(Map<String, dynamic> map) {
    return Room(
      id: map['id'],
      code: map['code'],
      status: map['status'],
      hostId: map['host_id'] ?? '',
      trumpSuit: map['trump_suit'],
      trumpLocked: map['trump_locked'] ?? false,
      dealerIndex: map['dealer_index'] ?? 0,
      turnIndex: map['turn_index'] ?? 0,
      currentPhase: map['current_phase'],
      shuffledDeck: List<String>.from(map['shuffled_deck'] ?? []),
      deckCutValue: map['deck_cut_value'],
      currentRound: map['current_round'] ?? 1,
      highestBid: map['highest_bid'] ?? 0,
      highestBidderId: map['highest_bidder_id'],
      passCount: map['pass_count'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'code': code,
      'status': status,
      'host_id': hostId,
      'trump_suit': trumpSuit,
      'trump_locked': trumpLocked,
      'dealer_index': dealerIndex,
      'turn_index': turnIndex,
      'current_phase': currentPhase,
      'shuffled_deck': shuffledDeck,
      'deck_cut_value': deckCutValue,
      'current_round': currentRound,
      'highest_bid': highestBid,
      'highest_bidder_id': highestBidderId,
      'pass_count': passCount,
    };
  }

  factory Room.fromJson(Map<String, dynamic> json) => Room.fromMap(json);
  Map<String, dynamic> toJson() => toMap();

  Room copyWith({
    String? id,
    String? code,
    String? status,
    String? hostId,
    String? trumpSuit,
    bool? trumpLocked,
    int? dealerIndex,
    int? turnIndex,
    String? currentPhase,
    List<String>? shuffledDeck,
    int? deckCutValue,
    int? currentRound,
    int? highestBid,
    String? highestBidderId,
    int? passCount,
  }) {
    return Room(
      id: id ?? this.id,
      code: code ?? this.code,
      status: status ?? this.status,
      hostId: hostId ?? this.hostId,
      trumpSuit: trumpSuit ?? this.trumpSuit,
      trumpLocked: trumpLocked ?? this.trumpLocked,
      dealerIndex: dealerIndex ?? this.dealerIndex,
      turnIndex: turnIndex ?? this.turnIndex,
      currentPhase: currentPhase ?? this.currentPhase,
      shuffledDeck: shuffledDeck ?? this.shuffledDeck,
      deckCutValue: deckCutValue ?? this.deckCutValue,
      currentRound: currentRound ?? this.currentRound,
      highestBid: highestBid ?? this.highestBid,
      highestBidderId: highestBidderId ?? this.highestBidderId,
      passCount: passCount ?? this.passCount,
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

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'room_id': roomId,
      'name': name,
      'is_host': isHost,
      'bid': bid,
      'tricks_won': tricksWon,
      'total_score': totalScore,
    };
  }

  factory Player.fromJson(Map<String, dynamic> json) => Player.fromMap(json);
  Map<String, dynamic> toJson() => toMap();

  Player copyWith({
    String? id,
    String? roomId,
    String? name,
    bool? isHost,
    int? bid,
    int? tricksWon,
    int? totalScore,
  }) {
    return Player(
      id: id ?? this.id,
      roomId: roomId ?? this.roomId,
      name: name ?? this.name,
      isHost: isHost ?? this.isHost,
      bid: bid ?? this.bid,
      tricksWon: tricksWon ?? this.tricksWon,
      totalScore: totalScore ?? this.totalScore,
    );
  }
}
