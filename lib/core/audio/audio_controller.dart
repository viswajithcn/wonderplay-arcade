import 'dart:io' show Platform;
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import '../storage/game_storage.dart';

class AudioController extends ChangeNotifier {
  static final AudioController _instance = AudioController._internal();
  factory AudioController() => _instance;
  AudioController._internal();

  final AudioPlayer _sfxPlayer = AudioPlayer();
  final AudioPlayer _popPlayer = AudioPlayer();
  final AudioPlayer _bgmPlayer = AudioPlayer();

  final Map<String, Uint8List> _soundBytesCache = {};

  bool _sfxEnabled = true;
  bool _bgmEnabled = true;
  bool _isBgmPlaying = false;

  bool get _isTesting =>
      !kIsWeb && Platform.environment.containsKey('FLUTTER_TEST');

  bool get sfxEnabled => _sfxEnabled;
  bool get bgmEnabled => _bgmEnabled;
  bool get isMuted => !_sfxEnabled && !_bgmEnabled;

  Future<void> init(GameStorage storage) async {
    _sfxEnabled = storage.getSfxEnabled();
    _bgmEnabled = storage.getBgmEnabled();

    _bgmPlayer.setReleaseMode(ReleaseMode.loop);
    _bgmPlayer.setVolume(0.35);

    // Preload audio into memory to eliminate web IO issues and latency
    const soundAssets = [
      'assets/audio/pop.wav',
      'assets/audio/correct.wav',
      'assets/audio/wrong.wav',
      'assets/audio/celebrate.wav',
      'assets/audio/click.wav',
      'assets/audio/bgm.wav',
    ];

    for (final path in soundAssets) {
      try {
        final byteData = await rootBundle.load(path);
        _soundBytesCache[path] = byteData.buffer.asUint8List();
      } catch (e) {
        debugPrint('Preloading sound error for $path: $e');
      }
    }
  }

  Future<void> startBgm() async {
    if (!_bgmEnabled || _isBgmPlaying || _isTesting) return;
    try {
      final bgmBytes = _soundBytesCache['assets/audio/bgm.wav'];
      if (bgmBytes != null) {
        await _bgmPlayer.setReleaseMode(ReleaseMode.loop);
        await _bgmPlayer.play(
          BytesSource(bgmBytes, mimeType: 'audio/wav'),
          volume: 0.35,
        );
        _isBgmPlaying = true;
      }
    } catch (e) {
      debugPrint('BGM playback start error: $e');
    }
  }

  Future<void> stopBgm() async {
    if (_isTesting) {
      _isBgmPlaying = false;
      return;
    }
    try {
      await _bgmPlayer.stop();
      _isBgmPlaying = false;
    } catch (e) {
      debugPrint('BGM stop error: $e');
    }
  }

  void toggleMasterMute(GameStorage storage) {
    if (!isMuted) {
      // Mute everything
      _sfxEnabled = false;
      _bgmEnabled = false;
      storage.setSfxEnabled(false);
      storage.setBgmEnabled(false);
      stopBgm();
    } else {
      // Unmute everything
      _sfxEnabled = true;
      _bgmEnabled = true;
      storage.setSfxEnabled(true);
      storage.setBgmEnabled(true);
      startBgm();
    }
    notifyListeners();
  }

  void setSfxEnabled(bool val, GameStorage storage) {
    _sfxEnabled = val;
    storage.setSfxEnabled(val);
    notifyListeners();
  }

  void setBgmEnabled(bool val, GameStorage storage) {
    _bgmEnabled = val;
    storage.setBgmEnabled(val);
    if (_bgmEnabled) {
      startBgm();
    } else {
      stopBgm();
    }
    notifyListeners();
  }

  void toggleSfx(GameStorage storage) {
    setSfxEnabled(!_sfxEnabled, storage);
  }

  void toggleBgm(GameStorage storage) {
    setBgmEnabled(!_bgmEnabled, storage);
  }

  Future<void> playPop() async {
    if (!_sfxEnabled || _isTesting) return;
    try {
      final cachedBytes = _soundBytesCache['assets/audio/pop.wav'];
      if (cachedBytes != null) {
        await _popPlayer.stop();
        await _popPlayer.play(
          BytesSource(cachedBytes, mimeType: 'audio/wav'),
          volume: 1.0,
        );
      } else {
        await _popPlayer.stop();
        await _popPlayer.play(AssetSource('audio/pop.wav'), volume: 1.0);
      }
    } catch (e) {
      debugPrint('Pop audio playback error: $e');
    }
  }

  Future<void> playCorrect() async {
    await _playSfx('assets/audio/correct.wav');
  }

  Future<void> playWrong() async {
    await _playSfx('assets/audio/wrong.wav');
  }

  Future<void> playCelebrate() async {
    await _playSfx('assets/audio/celebrate.wav');
  }

  Future<void> playClick() async {
    await _playSfx('assets/audio/click.wav');
    // Ensure BGM starts after user interaction ONLY if enabled by user
    if (_bgmEnabled && !_isBgmPlaying) {
      startBgm();
    }
  }

  Future<void> _playSfx(String assetPath) async {
    if (!_sfxEnabled || _isTesting) return;
    try {
      final cachedBytes = _soundBytesCache[assetPath];
      if (cachedBytes != null) {
        await _sfxPlayer.stop();
        await _sfxPlayer.play(
          BytesSource(cachedBytes, mimeType: 'audio/wav'),
          volume: 1.0,
        );
      } else {
        final source = AssetSource(assetPath.replaceFirst('assets/', ''));
        await _sfxPlayer.stop();
        await _sfxPlayer.play(source, volume: 1.0);
      }
    } catch (e) {
      debugPrint('Audio playback error for $assetPath: $e');
    }
  }

  @override
  void dispose() {
    _sfxPlayer.dispose();
    _popPlayer.dispose();
    _bgmPlayer.dispose();
    super.dispose();
  }
}
