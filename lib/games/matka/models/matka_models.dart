// Matka data models — independent of lib/games/minus/

class MatkaRoom {
  final String id;
  final String code;
  /// waiting | starting | dealing | betting | round_result | shuffling | ended
  final String status;
  final String? hostId;
  final int deckCount;
  final int anteAmount;
  final int potAmount;
  final int currentPlayerIndex;
  final List<String> shoe;
  final int shoePtr;
  final String? leftPillar;
  final String? rightPillar;
  final String? middleCard;
  final int? currentBet;
  final int roundNumber;
  final DateTime createdAt;

  const MatkaRoom({
    required this.id,
    required this.code,
    required this.status,
    this.hostId,
    required this.deckCount,
    required this.anteAmount,
    required this.potAmount,
    required this.currentPlayerIndex,
    required this.shoe,
    required this.shoePtr,
    this.leftPillar,
    this.rightPillar,
    this.middleCard,
    this.currentBet,
    required this.roundNumber,
    required this.createdAt,
  });

  int get cardsRemaining => shoe.length - shoePtr;
  int get totalShoeSize => shoe.length;

  factory MatkaRoom.fromMap(Map<String, dynamic> m) => MatkaRoom(
        id: m['id'],
        code: m['code'],
        status: m['status'] ?? 'waiting',
        hostId: m['host_id'],
        deckCount: m['deck_count'] ?? 1,
        anteAmount: m['ante_amount'] ?? 100,
        potAmount: m['pot_amount'] ?? 0,
        currentPlayerIndex: m['current_player_index'] ?? 0,
        shoe: List<String>.from(m['shoe'] ?? []),
        shoePtr: m['shoe_ptr'] ?? 0,
        leftPillar: m['left_pillar'],
        rightPillar: m['right_pillar'],
        middleCard: m['middle_card'],
        currentBet: m['current_bet'],
        roundNumber: m['round_number'] ?? 1,
        createdAt:
            DateTime.tryParse(m['created_at'] ?? '') ?? DateTime.now(),
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'code': code,
        'status': status,
        'host_id': hostId,
        'deck_count': deckCount,
        'ante_amount': anteAmount,
        'pot_amount': potAmount,
        'current_player_index': currentPlayerIndex,
        'shoe': shoe,
        'shoe_ptr': shoePtr,
        'left_pillar': leftPillar,
        'right_pillar': rightPillar,
        'middle_card': middleCard,
        'current_bet': currentBet,
        'round_number': roundNumber,
      };

  MatkaRoom copyWith({
    String? status,
    String? hostId,
    int? deckCount,
    int? anteAmount,
    int? potAmount,
    int? currentPlayerIndex,
    List<String>? shoe,
    int? shoePtr,
    String? leftPillar,
    String? rightPillar,
    String? middleCard,
    int? currentBet,
    int? roundNumber,
    bool clearPillars = false,
    bool clearMiddle = false,
    bool clearBet = false,
  }) =>
      MatkaRoom(
        id: id,
        code: code,
        status: status ?? this.status,
        hostId: hostId ?? this.hostId,
        deckCount: deckCount ?? this.deckCount,
        anteAmount: anteAmount ?? this.anteAmount,
        potAmount: potAmount ?? this.potAmount,
        currentPlayerIndex: currentPlayerIndex ?? this.currentPlayerIndex,
        shoe: shoe ?? this.shoe,
        shoePtr: shoePtr ?? this.shoePtr,
        leftPillar: clearPillars ? null : (leftPillar ?? this.leftPillar),
        rightPillar: clearPillars ? null : (rightPillar ?? this.rightPillar),
        middleCard: clearMiddle ? null : (middleCard ?? this.middleCard),
        currentBet: clearBet ? null : (currentBet ?? this.currentBet),
        roundNumber: roundNumber ?? this.roundNumber,
        createdAt: createdAt,
      );
}

class MatkaPlayer {
  final String id;
  final String roomId;
  final String name;
  final int netChips; // tracks net gain/loss; starts at 0
  final int seatIndex;
  final bool isHost;
  final bool isReady;
  final String? lastAction; // pass | bet | won | lost | posted
  final int? lastBetAmount;
  final DateTime joinedAt;

  const MatkaPlayer({
    required this.id,
    required this.roomId,
    required this.name,
    required this.netChips,
    required this.seatIndex,
    required this.isHost,
    required this.isReady,
    this.lastAction,
    this.lastBetAmount,
    required this.joinedAt,
  });

  factory MatkaPlayer.fromMap(Map<String, dynamic> m) => MatkaPlayer(
        id: m['id'],
        roomId: m['room_id'],
        name: m['name'],
        netChips: m['net_chips'] ?? 0,
        seatIndex: m['seat_index'] ?? 0,
        isHost: m['is_host'] ?? false,
        isReady: m['is_ready'] ?? false,
        lastAction: m['last_action'],
        lastBetAmount: m['last_bet_amount'],
        joinedAt: DateTime.tryParse(m['joined_at'] ?? '') ?? DateTime.now(),
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'room_id': roomId,
        'name': name,
        'net_chips': netChips,
        'seat_index': seatIndex,
        'is_host': isHost,
        'is_ready': isReady,
        'last_action': lastAction,
        'last_bet_amount': lastBetAmount,
      };

  MatkaPlayer copyWith({
    int? netChips,
    bool? isReady,
    String? lastAction,
    int? lastBetAmount,
  }) =>
      MatkaPlayer(
        id: id,
        roomId: roomId,
        name: name,
        netChips: netChips ?? this.netChips,
        seatIndex: seatIndex,
        isHost: isHost,
        isReady: isReady ?? this.isReady,
        lastAction: lastAction ?? this.lastAction,
        lastBetAmount: lastBetAmount ?? this.lastBetAmount,
        joinedAt: joinedAt,
      );
}

class MatkaRound {
  final String id;
  final String roomId;
  final int roundNumber;
  final String playerId;
  final String leftPillar;
  final String rightPillar;
  final String? middleCard;
  final int? betAmount;
  final String? result; // win | loss | post | pass
  final int chipsDelta;
  final DateTime createdAt;

  const MatkaRound({
    required this.id,
    required this.roomId,
    required this.roundNumber,
    required this.playerId,
    required this.leftPillar,
    required this.rightPillar,
    this.middleCard,
    this.betAmount,
    this.result,
    required this.chipsDelta,
    required this.createdAt,
  });

  factory MatkaRound.fromMap(Map<String, dynamic> m) => MatkaRound(
        id: m['id'],
        roomId: m['room_id'],
        roundNumber: m['round_number'],
        playerId: m['player_id'],
        leftPillar: m['left_pillar'],
        rightPillar: m['right_pillar'],
        middleCard: m['middle_card'],
        betAmount: m['bet_amount'],
        result: m['result'],
        chipsDelta: m['chips_delta'] ?? 0,
        createdAt: DateTime.tryParse(m['created_at'] ?? '') ?? DateTime.now(),
      );
}
