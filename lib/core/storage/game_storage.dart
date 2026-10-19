import 'package:shared_preferences/shared_preferences.dart';

class GameStorage {
  final SharedPreferences _prefs;

  GameStorage(this._prefs);

  static Future<GameStorage> init() async {
    final prefs = await SharedPreferences.getInstance();
    return GameStorage(prefs);
  }

  // Audio settings
  static const String _keySfx = 'sfx_enabled';
  static const String _keyBgm = 'bgm_enabled';

  bool getSfxEnabled() => _prefs.getBool(_keySfx) ?? true;
  Future<void> setSfxEnabled(bool val) => _prefs.setBool(_keySfx, val);

  bool getBgmEnabled() => _prefs.getBool(_keyBgm) ?? true;
  Future<void> setBgmEnabled(bool val) => _prefs.setBool(_keyBgm, val);

  // Global Stars
  static const String _keyTotalStars = 'total_stars_collected';

  int getTotalStars() => _prefs.getInt(_keyTotalStars) ?? 0;

  Future<void> addStars(int count) async {
    final current = getTotalStars();
    await _prefs.setInt(_keyTotalStars, current + count);
  }

  // Level Progression System
  int getHighestUnlockedLevel(String gameId) {
    return _prefs.getInt('${gameId}_highest_unlocked_level') ?? 1;
  }

  Future<void> unlockLevel(String gameId, int level) async {
    final current = getHighestUnlockedLevel(gameId);
    if (level > current) {
      await _prefs.setInt('${gameId}_highest_unlocked_level', level);
    }
  }

  int getLevelStars(String gameId, int level) {
    return _prefs.getInt('${gameId}_level_${level}_stars') ?? 0;
  }

  int getLevelHighScore(String gameId, int level) {
    return _prefs.getInt('${gameId}_level_${level}_highscore') ?? 0;
  }

  Future<void> saveLevelResult(
    String gameId,
    int level,
    int score,
    int stars,
  ) async {
    final oldHigh = getLevelHighScore(gameId, level);
    if (score > oldHigh) {
      await _prefs.setInt('${gameId}_level_${level}_highscore', score);
    }

    final oldStars = getLevelStars(gameId, level);
    if (stars > oldStars) {
      final newStarsEarned = stars - oldStars;
      await _prefs.setInt('${gameId}_level_${level}_stars', stars);
      if (newStarsEarned > 0) {
        await addStars(newStarsEarned);
      }
    }

    // Unlock next level if finished with at least 1 star
    if (stars > 0) {
      await unlockLevel(gameId, level + 1);
    }
  }

  // Backward compatibility
  int getGameHighScore(String gameId, String difficulty) {
    return _prefs.getInt('${gameId}_${difficulty}_highscore') ?? 0;
  }

  int getGameStars(String gameId, String difficulty) {
    return _prefs.getInt('${gameId}_${difficulty}_stars') ?? 0;
  }

  Future<void> saveGameResult(
    String gameId,
    String difficulty,
    int score,
    int stars,
  ) async {
    final oldHigh = getGameHighScore(gameId, difficulty);
    if (score > oldHigh) {
      await _prefs.setInt('${gameId}_${difficulty}_highscore', score);
    }

    final oldStars = getGameStars(gameId, difficulty);
    if (stars > oldStars) {
      final newStarsEarned = stars - oldStars;
      await _prefs.setInt('${gameId}_${difficulty}_stars', stars);
      if (newStarsEarned > 0) {
        await addStars(newStarsEarned);
      }
    }
  }
}
