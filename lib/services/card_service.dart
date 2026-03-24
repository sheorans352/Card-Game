import '../models/card_model.dart';

abstract class CardService {
  List<CardModel> generateDeck();
  Future<void> shuffleDeck(String roomId);
  Future<void> cutDeck(String roomId, int cutPoint);
  Future<void> dealInitialFive(String roomId, List<String> playerIds);
  Future<void> dealRemainingEight(String roomId, List<String> playerIds);
  Future<void> placeBid(String roomId, String playerId, int bid, {String? suit});
  Future<void> playCard(String roomId, String playerId, String cardValue);
  Future<bool> validateMove(String roomId, String playerId, String cardValue, List<Map<String, dynamic>> currentTrick, List<String> playerHand, String? trumpSuit);
}

class SupabaseCardService extends CardService {
  @override
  List<CardModel> generateDeck() => throw UnimplementedError();
  @override
  Future<void> shuffleDeck(String roomId) async => throw UnimplementedError();
  @override
  Future<void> cutDeck(String roomId, int cutPoint) async => throw UnimplementedError();
  @override
  Future<void> dealInitialFive(String roomId, List<String> playerIds) async => throw UnimplementedError();
  @override
  Future<void> dealRemainingEight(String roomId, List<String> playerIds) async => throw UnimplementedError();
  @override
  Future<void> placeBid(String roomId, String playerId, int bid, {String? suit}) async => throw UnimplementedError();
  @override
  Future<void> playCard(String roomId, String playerId, String cardValue) async => throw UnimplementedError();
  @override
  Future<bool> validateMove(String roomId, String playerId, String cardValue, List<Map<String, dynamic>> currentTrick, List<String> playerHand, String? trumpSuit) async => throw UnimplementedError();
}
