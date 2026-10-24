import 'package:bird_on_a_bike/models/difficulty.dart';
import 'package:bird_on_a_bike/services/storage_service.dart';

/// 测试用的内存存储，避免依赖 SharedPreferences。
class FakeStorageService extends StorageService {
  final Map<String, dynamic> _store = {};

  FakeStorageService() : super.test();

  static FakeStorageService create() => FakeStorageService();

  @override
  bool get darkMode => _store['dark_mode'] as bool? ?? false;

  @override
  Future<void> setDarkMode(bool v) async {
    _store['dark_mode'] = v;
  }

  @override
  int get highScore => _store['high_score'] as int? ?? 0;

  @override
  Future<void> setHighScore(int v) async {
    _store['high_score'] = v;
  }

  @override
  double get bestDistance => _store['best_distance'] as double? ?? 0.0;

  @override
  Future<void> setBestDistance(double v) async {
    _store['best_distance'] = v;
  }

  @override
  bool get muted => _store['muted'] as bool? ?? false;

  @override
  Future<void> setMuted(bool v) async {
    _store['muted'] = v;
  }

  Difficulty _difficulty = Difficulty.normal;

  @override
  Difficulty get difficulty => _difficulty;

  @override
  Future<void> setDifficulty(Difficulty v) async {
    _difficulty = v;
  }
}
