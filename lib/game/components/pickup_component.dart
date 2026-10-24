import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../models/pickup.dart';
import '../../utils/constants.dart';
import '../ride_style.dart';
import 'scene_layer_component.dart';

/// 小鱼与护盾/磁铁道具。
class PickupComponent extends SceneLayerComponent {
  PickupComponent({required super.provider, super.priority});

  final Paint _paint = Paint();
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
    for (final pickup in provider.state.pickups) {
      final bob = math.sin(_elapsed * 3 + pickup.phase) * 5;
      final center = Offset(
        pickup.x,
        AppConstants.groundY - pickup.y + bob,
      );
      switch (pickup.kind) {
        case PickupKind.fish:
          _paintFish(canvas, center, pickup.phase);
          break;
        case PickupKind.shield:
          _paintShield(canvas, center);
          break;
        case PickupKind.magnet:
          _paintMagnet(canvas, center);
          break;
      }
    }
  }

  void _paintFish(Canvas canvas, Offset center, double phase) {
    final pulse = 0.5 + 0.5 * math.sin(_elapsed * 4 + phase);
    _paint.color = RideColors.fish.withValues(alpha: 0.12 + 0.08 * pulse);
    canvas.drawCircle(center, 24 + pulse * 3, _paint);

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(math.sin(_elapsed * 2.4 + phase) * 0.18);

    final body = Paint()..color = RideColors.fish;
    canvas.drawOval(
      Rect.fromCenter(center: Offset.zero, width: 26, height: 15),
      body,
    );
    canvas.drawPath(
      Path()
        ..moveTo(-11, 0)
        ..lineTo(-21, -8)
        ..lineTo(-19, 0)
        ..lineTo(-21, 8)
        ..close(),
      Paint()..color = RideColors.fishDark,
    );
    canvas.drawPath(
      Path()
        ..moveTo(-2, -6)
        ..lineTo(6, -12)
        ..lineTo(5, -4)
        ..close(),
      Paint()..color = RideColors.fishDark.withValues(alpha: 0.8),
    );
    _paint.color = Colors.white;
    canvas.drawCircle(const Offset(7, -2), 3.2, _paint);
    _paint.color = RideColors.eye;
    canvas.drawCircle(const Offset(7.8, -2), 1.5, _paint);
    canvas.drawLine(
      const Offset(0, -4),
      const Offset(0, 4),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.35)
        ..strokeWidth = 1.2,
    );
    canvas.restore();
  }

  void _paintShield(Canvas canvas, Offset center) {
    final pulse = 0.5 + 0.5 * math.sin(_elapsed * 4);
    _paint.color = RideColors.shield.withValues(alpha: 0.16 + 0.06 * pulse);
    canvas.drawCircle(center, 22, _paint);
    _paint
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = RideColors.shield.withValues(alpha: 0.75);
    canvas.drawCircle(center, 20, _paint);
    _paint.style = PaintingStyle.fill;

    canvas.save();
    canvas.translate(center.dx, center.dy);
    final shield = Path()
      ..moveTo(0, -10)
      ..lineTo(9, -6)
      ..lineTo(8, 3)
      ..quadraticBezierTo(4, 9, 0, 11)
      ..quadraticBezierTo(-4, 9, -8, 3)
      ..lineTo(-9, -6)
      ..close();
    canvas.drawPath(shield, Paint()..color = Colors.white);
    canvas.drawPath(
      shield,
      Paint()
        ..color = RideColors.shield
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8,
    );
    canvas.drawCircle(const Offset(0, 0), 2.4, Paint()..color = RideColors.shield);
    canvas.restore();
  }

  void _paintMagnet(Canvas canvas, Offset center) {
    final pulse = 0.5 + 0.5 * math.sin(_elapsed * 4 + 1);
    _paint.color = RideColors.magnet.withValues(alpha: 0.16 + 0.06 * pulse);
    canvas.drawCircle(center, 22, _paint);
    _paint
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = RideColors.magnet.withValues(alpha: 0.75);
    canvas.drawCircle(center, 20, _paint);
    _paint.style = PaintingStyle.fill;

    canvas.save();
    canvas.translate(center.dx, center.dy);
    final u = Path()
      ..moveTo(-7, -9)
      ..lineTo(-7, 2)
      ..arcToPoint(
        const Offset(7, 2),
        radius: const Radius.circular(7),
        clockwise: true,
      )
      ..lineTo(7, -9);
    canvas.drawPath(
      u,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawPath(
      u,
      Paint()
        ..color = RideColors.magnet
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );
    final tip = Paint()..color = const Color(0xFFE05A5A);
    canvas.drawRect(const Rect.fromLTWH(-10, -11, 6, 4), tip);
    canvas.drawRect(const Rect.fromLTWH(4, -11, 6, 4), tip);
    canvas.restore();
  }
}
