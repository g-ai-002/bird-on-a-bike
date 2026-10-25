import 'dart:ui' show Offset;

import '../utils/constants.dart';
import 'iso_projection.dart';

/// 世界坐标约定。
///
/// 玩法直接以世界单位推进（10 单位 = 1 米，也等于原 2D 设计的 10 逻辑像素）：
/// x 指向骑行前进方向、y 向上、z 是路面深度。渲染层用 [IsoProjection]
/// 把世界坐标投到固定机位的 2.5D 画面上，规则与测试仍然只关心世界单位。
class WorldLayout {
  WorldLayout._();

  /// 1 米对应的世界单位。
  static const double unitsPerMeter = IsoProjection.worldUnitsPerMeter;

  /// 骑行者固定所在的 x（画面左侧）。
  static const double riderX = -21;

  /// 骑行者所在的骑行线深度。
  static const double riderZ = 0;

  /// 障碍物、鱼群与道具的生成位置。
  static const double obstacleSpawnX = 47;
  static const double fishSpawnX = 50;
  static const double powerUpSpawnX = 52;

  /// 世界 x 投影到屏幕像素，仅供屏幕空间特效使用。
  static double screenX(double worldX, [double worldZ = 0]) =>
      IsoProjection.project(worldX, 0, worldZ).dx;

  /// 世界高度投影到屏幕像素：地面为 [AppConstants.groundY]。
  static double screenY(double worldY, [double worldZ = 0]) =>
      IsoProjection.project(0, worldY, worldZ).dy;

  static Offset screenPoint(double worldX, double worldY, [double worldZ = 0]) =>
      IsoProjection.project(worldX, worldY, worldZ);
}
