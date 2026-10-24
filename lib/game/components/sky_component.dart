import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../utils/constants.dart';
import '../ride_style.dart';
import 'scene_layer_component.dart';

/// 黄昏天空、太阳、云、远山与海面。
class SkyComponent extends SceneLayerComponent {
  SkyComponent({required super.provider, super.priority});

  static const _clouds = <_Cloud>[
    _Cloud(90, 78, 1.0),
    _Cloud(320, 126, 0.78),
    _Cloud(540, 62, 1.15),
    _Cloud(720, 152, 0.68),
    _Cloud(880, 104, 0.9),
  ];

  final Paint _paint = Paint();
  double _elapsed = 0;

  @override
  void update(double dt) {
    super.update(dt);
    _elapsed += dt;
  }

  @override
  void render(Canvas canvas) {
    final distancePx = provider.state.distance * 10;

    _paint
      ..shader = ui.Gradient.linear(
        Offset.zero,
        const Offset(0, 330),
        const [
          RideColors.skyTop,
          RideColors.skyMid,
          RideColors.skyLow,
        ],
        const [0, 0.56, 1],
      )
      ..color = Colors.white;
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, AppConstants.worldWidth, 330),
      _paint,
    );
    _paint.shader = null;

    _paintSun(canvas);
    _paintClouds(canvas, distancePx);
    _paintGulls(canvas);
    _paintHills(canvas, distancePx);
    _paintSea(canvas, distancePx);
  }

  void _paintSun(Canvas canvas) {
    const center = Offset(642, 104);
    _paint
      ..shader = ui.Gradient.radial(
        center,
        96,
        [
          RideColors.sun.withValues(alpha: 0.55),
          RideColors.sun.withValues(alpha: 0),
        ],
      );
    canvas.drawCircle(center, 96, _paint);
    _paint.shader = null;
    _paint.color = RideColors.sun;
    canvas.drawCircle(center, 38, _paint);
    _paint.color = RideColors.sun.withValues(alpha: 0.8);
    canvas.drawCircle(center, 52, _paint..style = PaintingStyle.stroke);
    _paint
      ..style = PaintingStyle.fill
      ..color = Colors.white;
  }

  void _paintClouds(Canvas canvas, double distancePx) {
    final scroll = distancePx * 0.06;
    _paint.color = Colors.white.withValues(alpha: 0.55);
    for (final cloud in _clouds) {
      final raw = (cloud.x - scroll) % 1100;
      final x = (raw < -150 ? raw + 1100 : raw) - 100;
      _drawCloud(canvas, Offset(x, cloud.y), cloud.scale);
    }
    _paint.color = RideColors.sun.withValues(alpha: 0.35);
    for (var i = 0; i < 3; i++) {
      final x = ((i * 310 - scroll * 0.6) % 1000) + 60;
      _drawCloud(canvas, Offset(x, 150.0 + i * 24), 0.5);
    }
    _paint.color = Colors.white;
  }

  void _drawCloud(Canvas canvas, Offset center, double scale) {
    canvas.drawCircle(center, 18 * scale, _paint);
    canvas.drawCircle(
      center + Offset(22 * scale, 2 * scale),
      24 * scale,
      _paint,
    );
    canvas.drawCircle(
      center + Offset(-24 * scale, 5 * scale),
      15 * scale,
      _paint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: center + Offset(0, 14 * scale),
          width: 76 * scale,
          height: 20 * scale,
        ),
        Radius.circular(10 * scale),
      ),
      _paint,
    );
  }

  void _paintGulls(Canvas canvas) {
    final paint = Paint()
      ..color = const Color(0xFF3F4E4E).withValues(alpha: 0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 3; i++) {
      final x = 190.0 + i * 76 + math.sin(_elapsed * 0.8 + i) * 6;
      final y = 112.0 + i * 14 + math.cos(_elapsed * 1.1 + i) * 4;
      final wing = 5.0 + i;
      canvas.drawPath(
        Path()
          ..moveTo(x - wing * 2, y)
          ..quadraticBezierTo(x - wing, y - wing, x, y)
          ..quadraticBezierTo(x + wing, y - wing, x + wing * 2, y),
        paint,
      );
    }
  }

  void _paintHills(Canvas canvas, double distancePx) {
    final farScroll = (distancePx * 0.18) % 280;
    final far = Paint()..color = RideColors.hillFar.withValues(alpha: 0.7);
    for (var i = -1; i <= 4; i++) {
      final x = i * 280 - farScroll;
      canvas.drawPath(
        Path()
          ..moveTo(x, 306)
          ..quadraticBezierTo(x + 62, 246, x + 132, 306)
          ..close(),
        far,
      );
    }

    final nearScroll = (distancePx * 0.32) % 240;
    final near = Paint()..color = RideColors.hillNear.withValues(alpha: 0.85);
    for (var i = -1; i <= 5; i++) {
      final x = i * 240 - nearScroll;
      canvas.drawPath(
        Path()
          ..moveTo(x, 318)
          ..quadraticBezierTo(x + 54, 272, x + 118, 318)
          ..quadraticBezierTo(x + 76, 300, x + 40, 318)
          ..close(),
        near,
      );
    }
  }

  void _paintSea(Canvas canvas, double distancePx) {
    const top = 306.0;
    final rect = Rect.fromLTWH(
      0,
      top,
      AppConstants.worldWidth,
      AppConstants.groundY - top,
    );
    final seaPaint = Paint()
      ..shader = ui.Gradient.linear(
        const Offset(0, top),
        const Offset(0, AppConstants.groundY),
        const [RideColors.sea, RideColors.seaDeep],
      );
    canvas.drawRect(rect, seaPaint);

    final wave = Paint()
      ..color = Colors.white.withValues(alpha: 0.22)
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;
    for (var row = 0; row < 6; row++) {
      final y = top + 12 + row * 11.0;
      final shift = (distancePx * (0.5 + row * 0.06) + row * 47) % 150;
      for (var x = -shift; x < AppConstants.worldWidth; x += 150) {
        canvas.drawLine(
          Offset(x, y),
          Offset(x + 34 + row * 3, y),
          wave,
        );
      }
    }

    final sunPath = Paint()
      ..color = RideColors.sun.withValues(alpha: 0.35)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 4; i++) {
      final y = top + 10 + i * 13.0;
      final w = 46.0 - i * 8;
      canvas.drawLine(Offset(642 - w / 2, y), Offset(642 + w / 2, y), sunPath);
    }
  }
}

class _Cloud {
  final double x;
  final double y;
  final double scale;

  const _Cloud(this.x, this.y, this.scale);
}
