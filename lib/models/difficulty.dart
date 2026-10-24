/// 骑行难度：影响初速度与障碍密度。
enum Difficulty { easy, normal, hard }

extension DifficultyInfo on Difficulty {
  String get label {
    switch (this) {
      case Difficulty.easy:
        return '悠闲';
      case Difficulty.normal:
        return '标准';
      case Difficulty.hard:
        return '狂飙';
    }
  }

  String get description {
    switch (this) {
      case Difficulty.easy:
        return '车速慢一些，障碍更稀疏';
      case Difficulty.normal:
        return '海风正好，节奏适中';
      case Difficulty.hard:
        return '一路狂蹬，障碍接踵而来';
    }
  }

  double get baseSpeed {
    switch (this) {
      case Difficulty.easy:
        return 230;
      case Difficulty.normal:
        return 275;
      case Difficulty.hard:
        return 320;
    }
  }

  /// 障碍间隔倍率，越大越稀疏。
  double get spawnScale {
    switch (this) {
      case Difficulty.easy:
        return 1.22;
      case Difficulty.normal:
        return 1.0;
      case Difficulty.hard:
        return 0.84;
    }
  }
}
