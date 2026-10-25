import 'dart:ui';

import '../iso_projection.dart';
import '../rendering/scenery_sprites.dart';
import 'scene_layer_component.dart';

/// 贴近镜头的近景剪影：底边草丛与碎石。
///
/// 比路面滚得更快（1.18 倍），用最暗的色块压住画面下沿，
/// 让中景的等距路面产生纵深。草叶与碎石复用 [ScenerySprites] 的位图缓存；
/// 只遍历当前可见区内的下标，缩放越大省下的绘制越多。
class ShoreForegroundComponent extends SceneLayerComponent {
  ShoreForegroundComponent({required super.provider, super.priority});

  static const Color _ink = Color(0xFF16262B);
  static const Color _inkSoft = Color(0xFF1E3138);
  static const double _parallax = 1.18;

  final Paint _bandPaint = Paint()..color = _ink.withValues(alpha: 0.55);

  @override
  void render(Canvas canvas) {
    final travel =
        IsoProjection.travelPixels(provider.state.distance) * _parallax;
    final unitScroll = travel / IsoProjection.pxPerUnit;

    canvas.drawRect(
      Rect.fromLTWH(0, height - 12, width, 12),
      _bandPaint,
    );

    const gap = 2.4;
    final (grassFirst, grassLast) = _tileRange(
      gap: gap,
      unitScroll: unitScroll,
      halfWidthPx: 13,
    );
    for (var index = grassFirst; index <= grassLast; index++) {
      final worldX = index * gap - unitScroll;
      final screenX =
          IsoProjection.project(worldX, 0, IsoProjection.roadNearZ).dx;
      final tuftHeight = 16.0 + (index % 4) * 6.5;
      final tuftWidth = tuftHeight * 0.7;
      if (!isVisibleAt(Offset(screenX, 0), tuftWidth / 2 + 2)) {
        continue;
      }
      ScenerySprites.drawGrass(
        canvas,
        Offset(screenX, height + 4),
        Size(tuftWidth, tuftHeight),
        index.isEven ? _ink : _inkSoft,
      );
    }

    const stoneGap = 8.3;
    final (stoneFirst, stoneLast) = _tileRange(
      gap: stoneGap,
      unitScroll: unitScroll,
      halfWidthPx: 15,
    );
    for (var index = stoneFirst; index <= stoneLast; index++) {
      if (index % 3 != 0) continue;
      final worldX = index * stoneGap - unitScroll;
      final screenX =
          IsoProjection.project(worldX, 0, IsoProjection.roadNearZ).dx;
      final size = 14.0 + (index % 3) * 6;
      if (!isVisibleAt(Offset(screenX, 0), size / 2)) {
        continue;
      }
      ScenerySprites.drawStone(
        canvas,
        Offset(screenX, height + 6),
        Size(size, size * 0.6),
      );
    }
  }

  /// 该深度上需要遍历的 index 区间：由可见世界范围反算并前后各多留一格，
  /// 使剪影在完全进入画面前就已准备好，只有整块移出画面才停止绘制。
  (int, int) _tileRange({
    required double gap,
    required double unitScroll,
    required double halfWidthPx,
  }) {
    final (left, right) = visibleWorldXRange(IsoProjection.roadNearZ);
    final margin = halfWidthPx / IsoProjection.pxPerUnit;
    return (
      (((left - margin) + unitScroll) / gap).floor() - 1,
      (((right + margin) + unitScroll) / gap).ceil() + 1,
    );
  }
}
