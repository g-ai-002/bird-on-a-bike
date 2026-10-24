import 'package:flutter/material.dart';

import '../../models/obstacle.dart';
import '../../utils/constants.dart';
import '../ride_style.dart';
import 'scene_layer_component.dart';

/// 地面障碍与悬空横幅。
class ObstacleComponent extends SceneLayerComponent {
  ObstacleComponent({required super.provider, super.priority});

  final Paint _paint = Paint();

  @override
  void render(Canvas canvas) {
    for (final obstacle in provider.state.obstacles) {
      switch (obstacle.kind) {
        case ObstacleKind.rock:
          _paintRock(canvas, obstacle);
          break;
        case ObstacleKind.crate:
          _paintCrate(canvas, obstacle);
          break;
        case ObstacleKind.log:
          _paintLog(canvas, obstacle);
          break;
        case ObstacleKind.banner:
          _paintBanner(canvas, obstacle);
          break;
      }
    }
  }

  void _paintRock(Canvas canvas, Obstacle obstacle) {
    final x = obstacle.x;
    const baseline = AppConstants.groundY;
    final w = obstacle.kind.width;
    final h = obstacle.kind.height;
    final path = Path()
      ..moveTo(x, baseline)
      ..lineTo(x + w * 0.12, baseline - h * 0.55)
      ..lineTo(x + w * 0.34, baseline - h * 0.9)
      ..lineTo(x + w * 0.62, baseline - h)
      ..lineTo(x + w * 0.86, baseline - h * 0.62)
      ..lineTo(x + w, baseline)
      ..close();
    canvas.drawPath(path, Paint()..color = RideColors.rock);
    canvas.drawPath(
      Path()
        ..moveTo(x + w * 0.34, baseline - h * 0.9)
        ..lineTo(x + w * 0.62, baseline - h)
        ..lineTo(x + w * 0.7, baseline - h * 0.55)
        ..lineTo(x + w * 0.46, baseline - h * 0.5)
        ..close(),
      Paint()..color = RideColors.rockDark,
    );
    _paint.color = Colors.white.withValues(alpha: 0.18);
    canvas.drawCircle(Offset(x + w * 0.3, baseline - h * 0.7), 4, _paint);
  }

  void _paintCrate(Canvas canvas, Obstacle obstacle) {
    final rect = Rect.fromLTWH(
      obstacle.x,
      AppConstants.groundY - obstacle.kind.height,
      obstacle.kind.width,
      obstacle.kind.height,
    );
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(4));
    canvas.drawRRect(rrect, Paint()..color = RideColors.crate);

    final line = Paint()
      ..color = RideColors.crateDark
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5;
    canvas.drawRRect(rrect, line);
    canvas.drawLine(rect.topLeft, rect.bottomRight, line);
    canvas.drawLine(rect.topRight, rect.bottomLeft, line);
    canvas.drawLine(
      Offset(rect.left + 5, rect.top + 5),
      Offset(rect.right - 5, rect.top + 5),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.18)
        ..strokeWidth = 2,
    );
  }

  void _paintLog(Canvas canvas, Obstacle obstacle) {
    final rect = Rect.fromLTWH(
      obstacle.x,
      AppConstants.groundY - obstacle.kind.height,
      obstacle.kind.width,
      obstacle.kind.height,
    );
    final rrect = RRect.fromRectAndRadius(
      rect,
      Radius.circular(obstacle.kind.height / 2),
    );
    canvas.drawRRect(rrect, Paint()..color = RideColors.log);
    final ring = Paint()
      ..color = RideColors.crateDark
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(rect.right - 10, rect.center.dy),
        width: 16,
        height: rect.height - 8,
      ),
      ring,
    );
    _paint.color = Colors.white.withValues(alpha: 0.18);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(rect.left + 8, rect.top + 6, rect.width - 30, 4),
        const Radius.circular(2),
      ),
      _paint,
    );
  }

  void _paintBanner(Canvas canvas, Obstacle obstacle) {
    final x = obstacle.x;
    final w = obstacle.kind.width;
    final thickness = obstacle.kind.thickness;
    final top = AppConstants.groundY - obstacle.kind.clearance - thickness;

    final rope = Paint()
      ..color = RideColors.bannerPole.withValues(alpha: 0.65)
      ..strokeWidth = 1.5;
    canvas.drawLine(Offset(x + w / 2, 0), Offset(x + w / 2, top), rope);
    canvas.drawLine(
      Offset(x + 4, top - 8),
      Offset(x + 4, top),
      rope,
    );
    canvas.drawLine(
      Offset(x + w - 4, top - 8),
      Offset(x + w - 4, top),
      rope,
    );

    final rect = Rect.fromLTWH(x, top, w, thickness);
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        rect,
        topLeft: const Radius.circular(4),
        topRight: const Radius.circular(4),
        bottomLeft: const Radius.circular(2),
        bottomRight: const Radius.circular(2),
      ),
      Paint()..color = RideColors.banner,
    );

    final stripe = Paint()..color = Colors.white.withValues(alpha: 0.7);
    for (var i = 0; i < 3; i++) {
      canvas.drawRect(
        Rect.fromLTWH(x + 8 + i * 20, top + 8, 10, thickness - 16),
        stripe,
      );
    }

    final scallop = Paint()..color = RideColors.banner;
    for (var i = 0; i < 4; i++) {
      final cx = x + 8 + i * 16.0;
      canvas.drawPath(
        Path()
          ..moveTo(cx, top + thickness)
          ..lineTo(cx + 8, top + thickness + 9)
          ..lineTo(cx + 16, top + thickness)
          ..close(),
        scallop,
      );
    }

    _paint.color = RideColors.bannerPole;
    canvas.drawCircle(Offset(x + 4, top + 2), 2.5, _paint);
    canvas.drawCircle(Offset(x + w - 4, top + 2), 2.5, _paint);
  }
}
