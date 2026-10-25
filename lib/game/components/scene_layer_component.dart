import 'dart:ui';

import 'package:flame/components.dart';

import '../../providers/game_provider.dart';
import '../../utils/constants.dart';
import '../iso_projection.dart';

/// 覆盖整个游戏世界的图层基类。
///
/// 画布按 cover 缩放后，实际可见的世界范围只有画幅的一部分：1080p 窗口下
/// 可见宽度约为 [AppConstants.worldWidth] 的 42%。这里的 [visibleWorldRect]
/// 把相机当前取景换算回世界坐标，供各图层剔除画面外的装饰。
abstract class SceneLayerComponent extends PositionComponent {
  SceneLayerComponent({
    required this.provider,
    int? priority,
  }) : super(
          position: Vector2.zero(),
          size: Vector2(AppConstants.worldWidth, AppConstants.worldHeight),
          priority: priority,
        );

  final GameProvider provider;

  /// 相机当前可见的世界矩形，额外留出 24 单位余量覆盖撞击抖动。
  Rect get visibleWorldRect {
    final game = findGame();
    if (game == null) {
      return const Rect.fromLTWH(
        0,
        0,
        AppConstants.worldWidth,
        AppConstants.worldHeight,
      );
    }
    return game.camera.visibleWorldRect.inflate(24);
  }

  /// 某个路面深度上可见的世界 x 区间。
  ///
  /// 等距投影会把远处的 x 整体右移，按深度换算后才能得到准确的区间。
  (double, double) visibleWorldXRange(double z) {
    final rect = visibleWorldRect;
    final offset = AppConstants.worldWidth / 2 + z * IsoProjection.depthSlantX;
    return (
      (rect.left - offset) / IsoProjection.pxPerUnit,
      (rect.right - offset) / IsoProjection.pxPerUnit,
    );
  }

  /// 以底边中点为锚点的地面精灵是否还有一部分落在可见区内。
  bool isVisibleAt(Offset ground, double halfWidthPx) {
    final rect = visibleWorldRect;
    return ground.dx + halfWidthPx > rect.left &&
        ground.dx - halfWidthPx < rect.right;
  }
}
