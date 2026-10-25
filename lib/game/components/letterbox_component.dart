import 'dart:ui';

import '../../utils/constants.dart';
import '../ride_style.dart';
import 'scene_layer_component.dart';

/// 世界上下需要补齐的留白区域；没有留白时对应项为 null。
///
/// [visible] 是相机当前的世界取景矩形。上沿超出世界顶部时补一块天空色，
/// 下沿超出世界底部时补一块近景墨色；坐标向外多留 [extent] 以覆盖任意比例。
(Rect?, Rect?) letterboxBands(
  Rect visible, {
  required double worldWidth,
  required double worldHeight,
  double extent = 2400,
}) {
  Rect? top;
  Rect? bottom;
  if (visible.top < 0) {
    top = Rect.fromLTRB(-extent, -extent, worldWidth + extent, 0);
  }
  if (visible.bottom > worldHeight) {
    bottom = Rect.fromLTRB(
      -extent,
      worldHeight,
      worldWidth + extent,
      worldHeight + extent,
    );
  }
  return (top, bottom);
}

/// 画布比 16:9 更高时（折叠屏展开、近方形窗口）世界上下留白的补白层。
///
/// 水平方向始终铺满世界宽度，多出来的高度交给这里：上沿用天空顶色、下沿用
/// 近景墨色，让留白看起来是天空与前景的延伸，而不是黑边或 Flutter 背景色。
class LetterboxComponent extends SceneLayerComponent {
  LetterboxComponent({required super.provider, super.priority});

  static const Color _bottom = Color(0xFF16262B);

  final Paint _topPaint = Paint()..color = RideColors.skyTop;
  final Paint _bottomPaint = Paint()..color = _bottom;

  @override
  void render(Canvas canvas) {
    final (top, bottom) = letterboxBands(
      _exactVisibleRect,
      worldWidth: AppConstants.worldWidth,
      worldHeight: AppConstants.worldHeight,
    );
    if (top != null) {
      canvas.drawRect(top, _topPaint);
    }
    if (bottom != null) {
      canvas.drawRect(bottom, _bottomPaint);
    }
  }

  /// 不带剔除余量的实际取景：没有留白时不绘制。
  Rect get _exactVisibleRect {
    final game = findGame();
    if (game == null) {
      return const Rect.fromLTWH(
        0,
        0,
        AppConstants.worldWidth,
        AppConstants.worldHeight,
      );
    }
    return game.camera.visibleWorldRect;
  }
}
