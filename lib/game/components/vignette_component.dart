import 'dart:ui' as ui;

import 'package:flame/components.dart';

import '../../utils/constants.dart';

/// 屏幕边缘轻微压暗，让视线集中在鹈鹕与路面上。
///
/// 一次全屏径向渐变，开销与一个普通矩形混合相当。
class VignetteComponent extends PositionComponent {
  VignetteComponent({super.priority})
    : super(
        position: Vector2.zero(),
        size: Vector2(AppConstants.worldWidth, AppConstants.worldHeight),
      );

  late final ui.Paint _paint = ui.Paint()
    ..shader = ui.Gradient.radial(
      ui.Offset(size.x / 2, size.y * 0.46),
      size.x * 0.72,
      const <ui.Color>[
        ui.Color(0x00000000),
        ui.Color(0x14061018),
        ui.Color(0x33040B12),
      ],
      const <double>[0.5, 0.78, 1.0],
    );

  @override
  void render(ui.Canvas canvas) {
    canvas.drawRect(ui.Rect.fromLTWH(0, 0, size.x, size.y), _paint);
  }
}
