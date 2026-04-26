import '../../minus/models/card_model.dart';

class TehriRoom {
  final String id;
  final String code;
  final String status;
  final String? hostId;
  final String? dealerId;
  final String? cutterId;
  final int currentBid;
  final String? bidderId;
  final String? trumpSuit;
  final int currentTurnIndex;
  final int roundNumber;
  final int? dealingTeamId;
  final int tehriScore;
  final int gameWinsEvenTeam;   // seats 0+2 win when THEY push opponents to ≥52
  final int gameWinsOddTeam;    // seats 1+3 win when THEY push opponents to ≥52
  final Map<String, dynamic>? lastSelectionCard;
  final Map<String, dynamic>? lastRoundSummary;

  TehriRoom({
    required this.id,
    required this.code,
    required this.status,
    this.hostId,
    this.dealerId,
    this.cutterId,
    this.currentBid = 0,
    this.bidderId,
    this.trumpSuit,
    this.currentTurnIndex = 0,
    this.roundNumber = 1,
    this.dealingTeamId,
    this.tehriScore = 0,
    this.gameWinsEvenTeam = 0,
    this.gameWinsOddTeam = 0,
    this.lastSelectionCard,
    this.lastRoundSummary,
  });

  factory TehriRoom.fromMap(Map<String, dynamic> map) {
    return TehriRoom(
      id: map['id'],
      code: map['code'],
      status: map['status'],
      hostId: map['host_id'],
      dealerId: map['dealer_id'],
      cutterId: map['cutter_id'],
      currentBid: map['current_bid'] ?? 0,
      bidderId: map['bidder_id'],
      trumpSuit: map['trump_suit'],
      currentTurnIndex: map['current_turn_index'] ?? 0,
      roundNumber: map['round_number'] ?? 1,
      dealingTeamId: map['dealing_team_id'],
      tehriScore: map['tehri_score'] ?? 0,
      gameWinsEvenTeam: map['game_wins_even_team'] ?? 0,
      gameWinsOddTeam: map['game_wins_odd_team'] ?? 0,
      lastSelectionCard: map['last_selection_card'] != null 
        ? Map<String, dynamic>.from(map['last_selection_card']) 
        : null,
      lastRoundSummary: map['last_round_summary'] != null
        ? Map<String, dynamic>.from(map['last_round_summary'])
        : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'code': code,
      'status': status,
      'host_id': hostId,
      'dealer_id': dealerId,
      'cutter_id': cutterId,
      'current_bid': currentBid,
      'bidder_id': bidderId,
      'trump_suit': trumpSuit,
      'current_turn_index': currentTurnIndex,
      'round_number': roundNumber,
      'dealing_team_id': dealingTeamId,
      'last_selection_card': lastSelectionCard,
    };
  }
}

class TehriPlayer {
  final String id;
  final String roomId;
  final String name;
  final int seatIndex;
  final int teamIndex;
  final int points;
  final int tricksWon;
  final bool isHost;
  final bool isReady;
  final List<String> cards;

  TehriPlayer({
    required this.id,
    required this.roomId,
    required this.name,
    required this.seatIndex,
    required this.teamIndex,
    this.points = 0,
    this.tricksWon = 0,
    this.isHost = false,
    this.isReady = false,
    this.cards = const [],
  });

  factory TehriPlayer.fromMap(Map<String, dynamic> map, {List<String>? cards}) {
    return TehriPlayer(
      id: map['id'],
      roomId: map['room_id'],
      name: map['name'],
      seatIndex: map['seat_index'] ?? 0,
      teamIndex: map['team_index'] ?? 0,
      points: map['points'] ?? 0,
      tricksWon: map['tricks_won'] ?? 0,
      isHost: map['is_host'] ?? false,
      isReady: map['is_ready'] ?? false,
      cards: cards ?? [],
    );
  }

  TehriPlayer copyWith({
    List<String>? cards,
    int? tricksWon,
    int? points,
    bool? isReady,
  }) {
    return TehriPlayer(
      id: id,
      roomId: roomId,
      name: name,
      seatIndex: seatIndex,
      teamIndex: teamIndex,
      points: points ?? this.points,
      tricksWon: tricksWon ?? this.tricksWon,
      isHost: isHost,
      isReady: isReady ?? this.isReady,
      cards: cards ?? this.cards,
    );
  }
}

class TehriTrick {
  final String id;
  final int trickNumber;
  final String? ledBy;
  final String? leadSuit;
  final List<String> cards;
  final List<String> playerIds;
  final String? winnerId;

  TehriTrick({
    required this.id,
    required this.trickNumber,
    this.ledBy,
    this.leadSuit,
    this.cards = const [],
    this.playerIds = const [],
    this.winnerId,
  });

  factory TehriTrick.fromMap(Map<String, dynamic> map) {
    return TehriTrick(
      id: map['id'],
      trickNumber: map['trick_number'] ?? 0,
      ledBy: map['led_by'],
      leadSuit: map['lead_suit'],
      cards: List<String>.from(map['cards'] ?? []),
      playerIds: List<String>.from(map['player_ids'] ?? []),
      winnerId: map['winner_id'],
    );
  }
}
