abstract class LobbyService {
  Future<Map<String, String>> createRoom(String hostName);
  Future<Map<String, String>?> joinRoom(String code, String playerName);
  Future<void> startGame(String roomId);
}

class SupabaseLobbyService extends LobbyService {
  @override
  Future<Map<String, String>> createRoom(String hostName) async => throw UnimplementedError();
  @override
  Future<Map<String, String>?> joinRoom(String code, String playerName) async => throw UnimplementedError();
  @override
  Future<void> startGame(String roomId) async => throw UnimplementedError();
}
