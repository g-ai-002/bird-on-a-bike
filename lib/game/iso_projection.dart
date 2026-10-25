import 'dart:ui';

import '../utils/constants.dart';

/// 固定机位 2.5D 斜视投影（等距地面 + 侧视角色）。
///
/// 世界坐标仍是 [WorldLayout] 约定的 x 前进 / y 向上 / z 路面深度：
/// 前进方向保持水平，路面深度方向按 30° 左右的斜率向上抬升，
/// 于是同一条路在不同深度上会呈现「近低远高、近左远右」的等距排布。
/// 投影只影响画面，碰撞与计分依旧直接使用世界单位。
class IsoProjection {
  IsoProjection._();

  /// 1 个世界单位对应的屏幕像素。
  static const double pxPerUnit = 10;

  /// 每单位路面深度带来的横向偏移（像素）。
  static const double depthSlantX = 22;

  /// 每单位路面深度带来的纵向抬升（像素）。
  static const double depthSlantY = 13;

  /// 1 米对应的世界单位，与玩法层保持一致。
  static const double worldUnitsPerMeter = 10;

  /// 海天交界线。
  static const double horizonY = 150;

  /// 路面在深度方向的两条边。
  static const double roadFarZ = 7.5;
  static const double roadNearZ = -7.5;

  /// 单向单车道的沥青带半宽；沥青外到路面边界留作沙石路肩。
  static const double laneHalfZ = 4.6;

  /// 车道边线所在的深度。
  static const double laneEdgeZ = 4.0;

  /// 路面之外的海岸沙带宽度与海水的近端深度。
  static const double shoreWidth = 1.5;
  static const double seaEdgeZ = roadFarZ + shoreWidth;

  /// 世界坐标 -> 屏幕坐标。
  static Offset project(double x, double y, double z) => Offset(
    AppConstants.worldWidth / 2 + x * pxPerUnit + z * depthSlantX,
    AppConstants.groundY - y * pxPerUnit - z * depthSlantY,
  );

  /// 路面远端（海侧）的屏幕纵坐标。
  static double get roadFarY =>
      AppConstants.groundY - roadFarZ * depthSlantY;

  /// 路面近端（镜头侧）的屏幕纵坐标。
  static double get roadNearY =>
      AppConstants.groundY - roadNearZ * depthSlantY;

  /// 海水近端（海岸沙带外沿）的屏幕纵坐标。
  static double get seaEdgeY =>
      AppConstants.groundY - seaEdgeZ * depthSlantY;

  /// 已骑行米数换算成屏幕滚动像素。
  static double travelPixels(double meters) =>
      meters * worldUnitsPerMeter * pxPerUnit;

  /// 画布横坐标反算回某个深度上的世界 x。
  static double worldXAtScreenX(double screenX, double z) =>
      (screenX - AppConstants.worldWidth / 2 - z * depthSlantX) / pxPerUnit;

  /// 地面精灵（以底边中点为锚点）是否还有一部分落在画布内。
  ///
  /// 沿路植被与碎石用它替代手写的 `worldX` 阈值：只有整个包围盒都移出
  /// 画面才停止绘制，与障碍物的回收规则保持一致。
  static bool isGroundSpriteVisible(Offset ground, double halfWidthPx) =>
      ground.dx + halfWidthPx > 0 &&
      ground.dx - halfWidthPx < AppConstants.worldWidth;

  /// 绘制顺序：远的先画，近的后画。
  static double depthOrder(double z) => -z;
}
