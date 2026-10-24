import 'package:flutter/foundation.dart';

import '../models/difficulty.dart';
import '../services/audio_service.dart';
import '../services/storage_service.dart';

class SettingsProvider extends ChangeNotifier {
  final StorageService _storage;

  SettingsProvider(this._storage) {
    _darkMode = _storage.darkMode;
    _difficulty = _storage.difficulty;
    _muted = _storage.muted;
    AudioService().setMuted(_muted);
  }

  late bool _darkMode;
  late Difficulty _difficulty;
  late bool _muted;

  bool get darkMode => _darkMode;
  Difficulty get difficulty => _difficulty;
  bool get muted => _muted;

  String get difficultyLabel => _difficulty.label;

  Future<void> toggleDarkMode(bool value) async {
    if (_darkMode == value) return;
    _darkMode = value;
    await _storage.setDarkMode(value);
    notifyListeners();
  }

  Future<void> setDifficulty(Difficulty value) async {
    if (_difficulty == value) return;
    _difficulty = value;
    await _storage.setDifficulty(value);
    notifyListeners();
  }

  Future<void> setMuted(bool value) async {
    if (_muted == value) return;
    _muted = value;
    AudioService().setMuted(value);
    await _storage.setMuted(value);
    notifyListeners();
  }
}
