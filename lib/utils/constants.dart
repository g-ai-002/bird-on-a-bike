/// 应用与玩法常量。
class AppConstants {
  AppConstants._();

  static const String appName = '鹈鹕骑单车';
  static const String version = '0.1.0';

  static const String prefKeyDarkMode = 'dark_mode';
  static const String prefKeyHighScore = 'high_score';
  static const String prefKeyBestDistance = 'best_distance';
  static const String prefKeyMuted = 'muted';
  static const String prefKeyDifficulty = 'difficulty';

  /// 游戏世界尺寸（逻辑像素），按 16:9 设计。
  static const double worldWidth = 800;
  static const double worldHeight = 450;

  /// 地面（车轮落点）的纵向位置。
  static const double groundY = 380;

  /// 鹈鹕固定所在的横向位置。
  static const double riderX = 190;

  /// 碰撞盒横向半宽。
  static const double riderHalfWidth = 26;

  /// 速度上限与随距离增长的系数。
  static const double maxSpeed = 660;
  static const double speedRampPerMeter = 0.8;

  /// 连续吃鱼的窗口、最大连击与单条鱼基础分。
  static const double comboWindow = 2.6;
  static const int maxCombo = 5;
  static const int fishBaseScore = 10;

  /// 护盾抵挡后短暂无敌，避免同一障碍重复判定。
  static const double shieldInvulnerable = 1.2;

  /// 磁铁持续时间与吸附范围/速度。
  static const double magnetDuration = 8;
  static const double magnetRange = 210;
  static const double magnetSpeed = 430;

  /// 拾取判定的额外宽容半径。
  static const double pickupForgiveness = 18;

  /// 触屏下滑后保持俯身的时间。
  static const double duckTouchSeconds = 0.6;

  /// HUD 通知最小间隔，Flame 渲染每帧直接读 provider.state。
  static const double notifyInterval = 0.1;

  /// 单次运行最多同时存在的实体数量，防止异常情况下无限增长。
  static const int maxObstacles = 12;
  static const int maxPickups = 40;
}
