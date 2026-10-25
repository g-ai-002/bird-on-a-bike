import 'dart:math' as math;
import 'dart:ui';

import '../../models/obstacle.dart';
import '../../models/pickup.dart';
import '../ride_style.dart';

/// 程序化低多边形道具画法。
///
/// 每个画法都在给定的 [Size] 画布内完成绘制，不依赖外部贴图；
/// 精灵堆叠与等距投影由渲染层负责，这里只关心「这一件东西长什么样」。
class PropArt {
  PropArt._();

  static const Color rockLight = Color(0xFFB6B6B6);
  static const Color woodLight = Color(0xFFD9A066);
  static const Color metal = Color(0xFFB8C2C8);
  static const Color glint = Color(0xFFFFFDF2);

  static Size obstacleSize(ObstacleKind kind) {
    switch (kind) {
      case ObstacleKind.rock:
        return const Size(48, 42);
      case ObstacleKind.crate:
        return const Size(44, 56);
      case ObstacleKind.log:
        return const Size(64, 38);
      case ObstacleKind.banner:
        return const Size(68, 108);
    }
  }

  static Size pickupSize(PickupKind kind) {
    switch (kind) {
      case PickupKind.fish:
        return const Size(32, 22);
      case PickupKind.shield:
        return const Size(32, 36);
      case PickupKind.magnet:
        return const Size(32, 34);
    }
  }

  static void paintObstacle(
    Canvas canvas,
    Size size,
    ObstacleKind kind, {
    int variant = 0,
  }) {
    switch (kind) {
      case ObstacleKind.rock:
        _paintRock(canvas, size, light: variant.isOdd);
      case ObstacleKind.crate:
        _paintCrate(canvas, size);
      case ObstacleKind.log:
        _paintLog(canvas, size);
      case ObstacleKind.banner:
        _paintBanner(canvas, size);
    }
  }

  static void paintPickup(Canvas canvas, Size size, PickupKind kind) {
    switch (kind) {
      case PickupKind.fish:
        _paintFish(canvas, size);
      case PickupKind.shield:
        _paintShield(canvas, size);
      case PickupKind.magnet:
        _paintMagnet(canvas, size);
    }
  }

  /// 海岸草丛：几片斜向上生长的叶子。
  static void paintGrassTuft(Canvas canvas, Size size, {Color? color}) {
    final w = size.width;
    final h = size.height;
    final paint = Paint()
      ..color = color ?? const Color(0xFF7A9A5A)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = math.max(1.4, w * 0.09);
    for (var i = 0; i < 5; i++) {
      final t = i / 4;
      final tipX = w * (0.16 + t * 0.68);
      final lean = (t - 0.5) * w * 0.26;
      canvas.drawPath(
        Path()
          ..moveTo(w * 0.5, h)
          ..quadraticBezierTo(
            w * 0.5 + lean * 0.5,
            h * 0.55,
            tipX + lean,
            h * (0.06 + t * 0.18),
          ),
        paint,
      );
    }
  }

  /// 海滩碎石。
  static void paintStone(Canvas canvas, Size size, {bool light = false}) {
    final w = size.width;
    final h = size.height;
    final path = Path()
      ..moveTo(w * 0.08, h * 0.92)
      ..lineTo(w * 0.02, h * 0.46)
      ..lineTo(w * 0.34, h * 0.12)
      ..lineTo(w * 0.78, h * 0.18)
      ..lineTo(w * 0.98, h * 0.6)
      ..lineTo(w * 0.82, h * 0.96)
      ..close();
    canvas.drawPath(
      path,
      Paint()..color = light ? rockLight : RideColors.rockDark,
    );
    canvas.drawPath(
      Path()
        ..moveTo(w * 0.34, h * 0.12)
        ..lineTo(w * 0.78, h * 0.18)
        ..lineTo(w * 0.6, h * 0.52)
        ..lineTo(w * 0.2, h * 0.44)
        ..close(),
      Paint()..color = rockLight.withValues(alpha: 0.55),
    );
  }

  // ---------------------------------------------------------------------------
  // 障碍
  // ---------------------------------------------------------------------------

  static void _paintRock(Canvas canvas, Size size, {bool light = false}) {
    final w = size.width;
    final h = size.height;
    final base = Path()
      ..moveTo(w * 0.06, h * 0.96)
      ..lineTo(w * 0.0, h * 0.58)
      ..lineTo(w * 0.16, h * 0.22)
      ..lineTo(w * 0.46, h * 0.04)
      ..lineTo(w * 0.78, h * 0.16)
      ..lineTo(w * 0.97, h * 0.5)
      ..lineTo(w * 0.88, h * 0.86)
      ..lineTo(w * 0.66, h * 0.98)
      ..close();
    canvas.drawPath(
      base,
      Paint()..color = light ? rockLight : RideColors.rock,
    );

    canvas.drawPath(
      Path()
        ..moveTo(w * 0.16, h * 0.22)
        ..lineTo(w * 0.46, h * 0.04)
        ..lineTo(w * 0.5, h * 0.48)
        ..lineTo(w * 0.22, h * 0.6)
        ..close(),
      Paint()..color = rockLight.withValues(alpha: 0.7),
    );
    canvas.drawPath(
      Path()
        ..moveTo(w * 0.5, h * 0.48)
        ..lineTo(w * 0.78, h * 0.16)
        ..lineTo(w * 0.97, h * 0.5)
        ..lineTo(w * 0.66, h * 0.98)
        ..lineTo(w * 0.46, h * 0.72)
        ..close(),
      Paint()..color = RideColors.rockDark.withValues(alpha: 0.85),
    );
    canvas.drawPath(
      Path()
        ..moveTo(w * 0.06, h * 0.96)
        ..lineTo(w * 0.0, h * 0.58)
        ..lineTo(w * 0.22, h * 0.6)
        ..lineTo(w * 0.46, h * 0.72)
        ..lineTo(w * 0.66, h * 0.98)
        ..close(),
      Paint()..color = RideColors.rockDark.withValues(alpha: 0.45),
    );
  }

  static void _paintCrate(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final body = Rect.fromLTWH(w * 0.05, h * 0.06, w * 0.9, h * 0.92);
    final radius = Radius.circular(w * 0.07);
    canvas.drawRRect(
      RRect.fromRectAndRadius(body, radius),
      Paint()..color = RideColors.crate,
    );
    canvas.drawRect(
      Rect.fromLTWH(body.left, body.top, body.width, h * 0.16),
      Paint()..color = woodLight.withValues(alpha: 0.85),
    );

    final plank = Paint()
      ..color = RideColors.crateDark.withValues(alpha: 0.65)
      ..strokeWidth = math.max(1.4, w * 0.045);
    for (var i = 1; i <= 2; i++) {
      final y = body.top + body.height * i / 3;
      canvas.drawLine(Offset(body.left, y), Offset(body.right, y), plank);
    }
    canvas.drawLine(
      Offset(body.left + w * 0.08, body.bottom - h * 0.1),
      Offset(body.right - w * 0.08, body.top + h * 0.22),
      plank,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(body, radius),
      Paint()
        ..color = RideColors.crateDark
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.6, w * 0.06),
    );

    final nail = Paint()..color = metal;
    for (final p in <Offset>[
      Offset(body.left + w * 0.12, body.top + h * 0.12),
      Offset(body.right - w * 0.12, body.top + h * 0.12),
      Offset(body.left + w * 0.12, body.bottom - h * 0.1),
      Offset(body.right - w * 0.12, body.bottom - h * 0.1),
    ]) {
      canvas.drawCircle(p, math.max(1.2, w * 0.035), nail);
    }
  }

  static void _paintLog(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final body = Rect.fromLTWH(w * 0.03, h * 0.2, w * 0.9, h * 0.62);
    canvas.drawRRect(
      RRect.fromRectAndRadius(body, Radius.circular(h * 0.31)),
      Paint()..color = RideColors.log,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          body.left + w * 0.04,
          body.top + h * 0.08,
          body.width * 0.82,
          h * 0.18,
        ),
        Radius.circular(h * 0.09),
      ),
      Paint()..color = woodLight.withValues(alpha: 0.6),
    );

    final end = Rect.fromLTWH(
      body.right - w * 0.18,
      body.top,
      w * 0.2,
      body.height,
    );
    canvas.drawOval(end, Paint()..color = const Color(0xFF6B4526));
    canvas.drawOval(
      Rect.fromCenter(
        center: end.center,
        width: end.width * 0.62,
        height: end.height * 0.62,
      ),
      Paint()..color = woodLight,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: end.center,
        width: end.width * 0.3,
        height: end.height * 0.3,
      ),
      Paint()..color = const Color(0xFF8E6239),
    );

    final grain = Paint()
      ..color = const Color(0xFF6B4526).withValues(alpha: 0.5)
      ..strokeWidth = math.max(1.0, h * 0.05)
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 2; i++) {
      final y = body.top + body.height * (0.45 + i * 0.22);
      canvas.drawLine(
        Offset(body.left + w * 0.12, y),
        Offset(body.left + w * 0.5, y + h * 0.02),
        grain,
      );
    }
  }

  static void _paintBanner(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final pole = Paint()..color = RideColors.bannerPole;
    final poleW = math.max(3.0, w * 0.055);
    canvas.drawRect(Rect.fromLTWH(w * 0.08, h * 0.02, poleW, h * 0.96), pole);
    canvas.drawRect(
      Rect.fromLTWH(w * 0.9 - poleW, h * 0.02, poleW, h * 0.96),
      pole,
    );
    canvas.drawCircle(
      Offset(w * 0.08 + poleW / 2, h * 0.03),
      poleW * 0.8,
      Paint()..color = woodLight,
    );
    canvas.drawCircle(
      Offset(w * 0.9 - poleW / 2, h * 0.03),
      poleW * 0.8,
      Paint()..color = woodLight,
    );

    final cloth = Rect.fromLTWH(w * 0.1, h * 0.03, w * 0.8, h * 0.34);
    canvas.drawRRect(
      RRect.fromRectAndRadius(cloth, Radius.circular(h * 0.02)),
      Paint()..color = RideColors.banner,
    );
    canvas.drawRect(
      Rect.fromLTWH(cloth.left, cloth.top, cloth.width, h * 0.05),
      Paint()..color = const Color(0xFFFFD9A0).withValues(alpha: 0.9),
    );

    final mark = Paint()
      ..color = const Color(0xFFFFF6E8).withValues(alpha: 0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.6, h * 0.02)
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 3; i++) {
      final x = cloth.left + cloth.width * (0.24 + i * 0.24);
      canvas.drawPath(
        Path()
          ..moveTo(x - cloth.width * 0.06, cloth.top + cloth.height * 0.62)
          ..lineTo(x, cloth.top + cloth.height * 0.4)
          ..lineTo(x + cloth.width * 0.06, cloth.top + cloth.height * 0.62),
        mark,
      );
    }
  }

  // ---------------------------------------------------------------------------
  // 拾取物
  // ---------------------------------------------------------------------------

  static void _paintFish(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final body = Rect.fromLTWH(w * 0.16, h * 0.16, w * 0.58, h * 0.68);
    canvas.drawPath(
      Path()
        ..moveTo(w * 0.72, h * 0.5)
        ..lineTo(w * 0.98, h * 0.2)
        ..lineTo(w * 0.94, h * 0.5)
        ..lineTo(w * 0.98, h * 0.8)
        ..close(),
      Paint()..color = RideColors.fishDark,
    );
    canvas.drawOval(body, Paint()..color = RideColors.fish);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w * 0.45, h * 0.62),
        width: w * 0.34,
        height: h * 0.26,
      ),
      Paint()..color = RideColors.fishDark.withValues(alpha: 0.35),
    );
    canvas.drawPath(
      Path()
        ..moveTo(w * 0.46, h * 0.2)
        ..lineTo(w * 0.58, h * 0.02)
        ..lineTo(w * 0.64, h * 0.24)
        ..close(),
      Paint()..color = RideColors.fishDark,
    );
    canvas.drawCircle(
      Offset(w * 0.27, h * 0.4),
      math.max(1.2, h * 0.09),
      Paint()..color = RideColors.eye,
    );
    canvas.drawCircle(
      Offset(w * 0.25, h * 0.37),
      math.max(0.7, h * 0.035),
      Paint()..color = glint,
    );
  }

  static void _paintShield(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final body = Path()
      ..moveTo(w * 0.5, h * 0.04)
      ..lineTo(w * 0.95, h * 0.2)
      ..lineTo(w * 0.86, h * 0.66)
      ..quadraticBezierTo(w * 0.6, h * 0.94, w * 0.5, h * 0.97)
      ..quadraticBezierTo(w * 0.4, h * 0.94, w * 0.14, h * 0.66)
      ..lineTo(w * 0.05, h * 0.2)
      ..close();
    canvas.drawPath(body, Paint()..color = RideColors.shield);
    canvas.drawPath(
      body,
      Paint()
        ..color = const Color(0xFFFFFFFF).withValues(alpha: 0.75)
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.6, w * 0.06),
    );
    final mark = Paint()
      ..color = const Color(0xFF0E5F6B).withValues(alpha: 0.7)
      ..strokeWidth = math.max(1.6, w * 0.06)
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(w * 0.5, h * 0.26),
      Offset(w * 0.5, h * 0.78),
      mark,
    );
    canvas.drawLine(
      Offset(w * 0.28, h * 0.44),
      Offset(w * 0.72, h * 0.44),
      mark,
    );
  }

  static void _paintMagnet(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final body = Path()
      ..moveTo(w * 0.14, h * 0.06)
      ..lineTo(w * 0.14, h * 0.52)
      ..quadraticBezierTo(w * 0.16, h * 0.88, w * 0.5, h * 0.9)
      ..quadraticBezierTo(w * 0.84, h * 0.88, w * 0.86, h * 0.52)
      ..lineTo(w * 0.86, h * 0.06)
      ..lineTo(w * 0.66, h * 0.06)
      ..lineTo(w * 0.66, h * 0.5)
      ..quadraticBezierTo(w * 0.64, h * 0.7, w * 0.5, h * 0.7)
      ..quadraticBezierTo(w * 0.36, h * 0.7, w * 0.34, h * 0.5)
      ..lineTo(w * 0.34, h * 0.06)
      ..close();
    canvas.drawPath(body, Paint()..color = RideColors.magnet);
    final tip = Paint()..color = metal;
    canvas.drawRect(Rect.fromLTWH(w * 0.14, h * 0.06, w * 0.2, h * 0.16), tip);
    canvas.drawRect(Rect.fromLTWH(w * 0.66, h * 0.06, w * 0.2, h * 0.16), tip);
    canvas.drawPath(
      Path()
        ..moveTo(w * 0.2, h * 0.16)
        ..lineTo(w * 0.2, h * 0.5)
        ..quadraticBezierTo(w * 0.22, h * 0.74, w * 0.5, h * 0.78),
      Paint()
        ..color = const Color(0xFFFFFFFF).withValues(alpha: 0.45)
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.4, w * 0.05)
        ..strokeCap = StrokeCap.round,
    );
  }
}
