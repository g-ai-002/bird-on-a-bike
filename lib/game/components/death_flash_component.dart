import 'package:flutter/material.dart';

import 'scene_layer_component.dart';

/// 撞击时的红色闪屏。
class DeathFlashComponent extends SceneLayerComponent {
  DeathFlashComponent({required super.provider, super.priority});

  static const Color _flashColor = Color(0xFFFF5A4D);

  final Paint _paint = Paint();
  double opacity = 0;

  @override
  void render(Canvas canvas) {
    if (opacity <= 0) return;
    _paint.color =
        _flashColor.withValues(alpha: opacity.clamp(0.0, 1.0).toDouble());
    canvas.drawRect(
      Rect.fromLTWH(0, 0, width, height),
      _paint,
    );
  }
}
