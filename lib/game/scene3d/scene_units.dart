import '../../models/obstacle.dart';
import '../../models/pickup.dart';
import '../../utils/constants.dart';

/// 2D 玩法坐标与 3D 世界坐标之间的换算。
///
/// 规则层仍以 800×450 的逻辑像素推进；3D 场景把 10 像素折算成 1 个世界单位，
/// 原点取在画面中心的地面高度：x 向右、y 向上、z 指向镜头远端。
class SceneUnits {
  SceneUnits._();

  static const double pixelsPerUnit = 10;

  /// 骑行者所在的横向位置（世界单位）。
  static const double riderX =
      (AppConstants.riderX - AppConstants.worldWidth / 2) / pixelsPerUnit;

  /// 屏幕像素 x 换算到世界坐标 x。
  static double x(double screenX) =>
      (screenX - AppConstants.worldWidth / 2) / pixelsPerUnit;

  /// 纵向像素长度换算到世界单位（向上为正）。
  static double height(double pixels) => pixels / pixelsPerUnit;

  /// 障碍中心的世界坐标 x。
  static double obstacleCenterX(Obstacle obstacle) =>
      x(obstacle.x + obstacle.kind.width / 2);

  static double obstacleWidth(ObstacleKind kind) => height(kind.width);

  static double obstacleHeight(ObstacleKind kind) => height(kind.height);

  /// 悬空横幅下沿距地面的高度。
  static double bannerClearance(ObstacleKind kind) => height(kind.clearance);

  /// 拾取物的世界坐标 x。
  static double pickupX(Pickup pickup) => x(pickup.x);

  /// 拾取物中心距地面的高度。
  static double pickupHeight(Pickup pickup) => height(pickup.y);
}
