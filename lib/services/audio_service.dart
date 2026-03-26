import 'package:audioplayers/audioplayers.dart';
import 'package:vibration/vibration.dart';
import 'package:flutter/foundation.dart';

class AudioService {
  static final AudioService _instance = AudioService._internal();
  factory AudioService() => _instance;
  AudioService._internal();

  final AudioPlayer _sfxPlayer = AudioPlayer();
  final AudioPlayer _bgmPlayer = AudioPlayer();

  // Mapping of common sounds
  static const String cardDeal = 'sounds/card_deal.mp3';
  static const String cardPlay = 'sounds/card_play.mp3';
  static const String trickWin = 'sounds/trick_win.mp3';
  static const String invalidMove = 'sounds/invalid_move.mp3';
  static const String biddingTick = 'sounds/bidding_tick.mp3';

  Future<void> initialize() async {
    // Pre-cache sounds if needed (audioplayers 6.0 handles this better automatically)
    _sfxPlayer.setReleaseMode(ReleaseMode.stop);
  }

  Future<void> playSfx(String assetPath) async {
    try {
      await _sfxPlayer.stop();
      await _sfxPlayer.play(AssetSource(assetPath));
    } catch (e) {
      debugPrint('Error playing SFX: $e');
    }
  }

  Future<void> playCardDeal() => playSfx(cardDeal);
  Future<void> playCardPlay() => playSfx(cardPlay);
  Future<void> playTrickWin() => playSfx(trickWin);
  Future<void> playBiddingTick() => playSfx(biddingTick);

  Future<void> playInvalidMove() async {
    await playSfx(invalidMove);
    if (await Vibration.hasVibrator() ?? false) {
      Vibration.vibrate(duration: 200, amplitude: 128);
    }
  }

  Future<void> playShuffle() async {
    await playSfx('sounds/shuffle.mp3');
  }

  void dispose() {
    _sfxPlayer.dispose();
    _bgmPlayer.dispose();
  }
}

final gameAudio = AudioService();
