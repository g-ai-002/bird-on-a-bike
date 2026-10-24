import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../models/game_state.dart';
import '../../utils/constants.dart';
import '../painting/pelican_art.dart';
import 'scene_layer_component.dart';

/// 鹈鹕与自行车本体。
class RiderComponent extends SceneLayerComponent {
  RiderComponent({required super.provider, super.priority});

  final Paint _shadowPaint = Paint()
    ..color = Colors.black.withValues(alpha: 0.18);

  double _wheelAngle = 0;
  double _wingPhase = 0;

  @override
  void update(double dt) {
    super.update(dt);
    final state = provider.state;
    if (state.isPlaying) {
      _wheelAngle += state.speed * dt / 26;
      _wingPhase += dt * (state.rider.airborne ? 13.0 : 5.5);
    }
  }

  @override
  void render(Canvas canvas) {
    final state = provider.state;
    final height = state.rider.height;

    final shadowWidth = 84.0 - height * 0.22;
    if (shadowWidth > 16) {
      canvas.drawOval(
        Rect.fromCenter(
          center: const Offset(
            AppConstants.riderX,
            AppConstants.groundY + 4,
          ),
          width: shadowWidth,
          height: 10,
        ),
        _shadowPaint,
      );
    }

    final left = AppConstants.riderX - kRiderArtSize.width / 2;
    final top = AppConstants.groundY - height - kRiderArtSize.height;
    final look = RideLook(
      wheelAngle: _wheelAngle,
      wingPhase: _wingPhase,
      ducking: state.rider.ducking,
      airborne: state.rider.airborne,
      shield: state.hasShield,
      magnet: state.magnetActive,
    );

    canvas.save();
    canvas.translate(left, top);
    if (state.status == GameStatus.over) {
      canvas.translate(kRiderArtSize.width / 2, kRiderArtSize.height);
      canvas.rotate(-0.12);
      canvas.translate(-kRiderArtSize.width / 2, -kRiderArtSize.height);
    }
    paintPelicanRider(canvas, kRiderArtSize, look);
    canvas.restore();

    if (state.status == GameStatus.over) {
      _paintDizzy(canvas, top);
    }
  }

  void _paintDizzy(Canvas canvas, double top) {
    final paint = Paint()
      ..color = RideColorsWhite.dizzy
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    final center = Offset(
      AppConstants.riderX + 20,
      top + 12,
    );
    for (var i = 0; i < 3; i++) {
      final angle = _wheelAngle + i * math.pi * 2 / 3;
      final start = center + Offset(math.cos(angle), math.sin(angle)) * 10;
      final end = start + Offset(math.cos(angle + 0.7), math.sin(angle + 0.7)) * 7;
      canvas.drawLine(start, end, paint);
    }
  }
}

/// 局部颜色常量，避免为一个小效果再引入整套调色板。
class RideColorsWhite {
  RideColorsWhite._();
  static const dizzy = Color(0xFFFFF2B2);
}
