import 'package:flutter/material.dart';

import '../../utils/constants.dart';
import '../ride_style.dart';
import '../world_layout.dart';
import 'scene_layer_component.dart';

/// 高速骑行时掠过画面的速度线。
class SpeedLinesComponent extends SceneLayerComponent {
  SpeedLinesComponent({required super.provider, super.priority});

  final Paint _paint = Paint()
    ..color = RideColors.pelican.withValues(alpha: 0.18)
    ..strokeWidth = 2
    ..strokeCap = StrokeCap.round;

  double _elapsed = 0;

  @override
  void update(double dt) {
    super.update(dt);
    if (provider.isPlaying) {
      _elapsed += dt;
    }
  }

  @override
  void render(Canvas canvas) {
    final speed = provider.state.speed;
    if (speed < 40) return;
    final strength = ((speed - 40) / (AppConstants.maxSpeed - 40))
        .clamp(0.0, 1.0)
        .toDouble();
    _paint.color = Colors.white.withValues(alpha: 0.06 + 0.16 * strength);

    for (var i = 0; i < 12; i++) {
      final y = 40 + (i * 53) % 320;
      final travel =
          (i * 131 + _elapsed * speed * WorldLayout.unitsPerMeter * 1.8) % 1000;
      final x = AppConstants.worldWidth + 100 - travel;
      final length = 26 + (i % 4) * 9.0;
      canvas.drawLine(
        Offset(x, y.toDouble()),
        Offset(x - length, y.toDouble()),
        _paint,
      );
    }
  }
}
