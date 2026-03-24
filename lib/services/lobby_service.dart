class LobbyService {
  Future<Map<String, String>> createRoom(String hostName) async {
    return {
      'roomCode': 'MOCK12',
      'playerId': 'p1',
    };
  }

  Future<Map<String, String>?> joinRoom(String code, String playerName) async {
    return {
      'playerId': 'p2',
    };
  }

  Future<void> startGame(String roomId) async {}
}
