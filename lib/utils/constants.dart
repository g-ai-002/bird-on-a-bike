/// 应用常量与 2.5D 世界玩法参数。
///
/// 玩法长度统一用世界单位：10 单位 = 1 米，与画面逻辑像素 10:1 对应，
/// 因此速度、重力等数值在视觉上手感与此前一致。
class AppConstants {
  AppConstants._();

  static const String appName = '鹈鹕骑单车';
  static const String version = '0.6.0';

  static const String prefKeyDarkMode = 'dark_mode';
  static const String prefKeyHighScore = 'high_score';
  static const String prefKeyBestDistance = 'best_distance';
  static const String prefKeyMuted = 'muted';
  static const String prefKeyDifficulty = 'difficulty';

  /// 3D 场景的逻辑画幅（16:9），也是 Flame 世界与输入层的尺寸。
  static const double worldWidth = 800;
  static const double worldHeight = 450;

  /// 地面在屏幕上的纵向位置，用于把世界坐标投影到特效层。
  static const double groundY = 380;

  /// 骑车人的 3D 碰撞盒半宽（x）与半深（z）。
  static const double riderHalfWidth = 2.6;
  static const double riderHalfDepth = 0.9;

  /// 速度上限与随距离增长的系数（世界单位 / 秒）。
  static const double maxSpeed = 66;
  static const double speedRampPerMeter = 0.08;

  /// 连续吃鱼的窗口、最大连击与单条鱼基础分。
  static const double comboWindow = 2.6;
  static const int maxCombo = 5;
  static const int fishBaseScore = 10;

  /// 护盾抵挡后短暂无敌，避免同一障碍重复判定。
  static const double shieldInvulnerable = 1.2;

  /// 磁铁持续时间与吸附范围/速度。
  static const double magnetDuration = 8;
  static const double magnetRange = 21;
  static const double magnetSpeed = 43;

  /// 拾取判定的额外宽容半径（补偿深度错位带来的距离损耗）。
  static const double pickupForgiveness = 2.2;

  /// 触屏下滑后保持俯身的时间。
  static const double duckTouchSeconds = 0.6;

  /// HUD 通知最小间隔，Flame 渲染每帧直接读 provider.state。
  static const double notifyInterval = 0.1;

  /// 障碍与拾取物在骑行线两侧的深度摆位幅度。
  static const double depthSpread = 1.2;

  /// 越过骑行者之后的回收线：留到精灵完全离开画面再回收，
  /// 避免障碍在镜头内突然消失。
  static const double cullX = -48;

  /// 单次运行最多同时存在的实体数量，防止异常情况下无限增长。
  static const int maxObstacles = 12;
  static const int maxPickups = 40;
}
