import 'package:shared_preferences/shared_preferences.dart';

import '../models/difficulty.dart';
import '../utils/constants.dart';

class StorageService {
  static StorageService? _instance;
  SharedPreferences? _prefs;

  StorageService._();

  /// 仅供测试使用
  StorageService.test();

  static Future<StorageService> get instance async {
    if (_instance != null) return _instance!;
    _instance = StorageService._();
    _instance!._prefs = await SharedPreferences.getInstance();
    return _instance!;
  }

  SharedPreferences get _p {
    final p = _prefs;
    if (p == null) throw StateError('StorageService 尚未初始化');
    return p;
  }

  bool get darkMode => _p.getBool(AppConstants.prefKeyDarkMode) ?? false;

  Future<void> setDarkMode(bool v) async {
    try {
      await _p.setBool(AppConstants.prefKeyDarkMode, v);
    } catch (_) {}
  }

  int get highScore => _p.getInt(AppConstants.prefKeyHighScore) ?? 0;

  Future<void> setHighScore(int v) async {
    try {
      await _p.setInt(AppConstants.prefKeyHighScore, v);
    } catch (_) {}
  }

  double get bestDistance =>
      _p.getDouble(AppConstants.prefKeyBestDistance) ?? 0;

  Future<void> setBestDistance(double v) async {
    try {
      await _p.setDouble(AppConstants.prefKeyBestDistance, v);
    } catch (_) {}
  }

  bool get muted => _p.getBool(AppConstants.prefKeyMuted) ?? false;

  Future<void> setMuted(bool v) async {
    try {
      await _p.setBool(AppConstants.prefKeyMuted, v);
    } catch (_) {}
  }

  Difficulty get difficulty {
    final name = _p.getString(AppConstants.prefKeyDifficulty);
    return Difficulty.values.firstWhere(
      (value) => value.name == name,
      orElse: () => Difficulty.normal,
    );
  }

  Future<void> setDifficulty(Difficulty v) async {
    try {
      await _p.setString(AppConstants.prefKeyDifficulty, v.name);
    } catch (_) {}
  }
}
