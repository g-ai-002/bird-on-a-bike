import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../game/painting/pelican_art.dart';

/// 主页用的鹈鹕海边骑行插画。
class PelicanBadge extends StatelessWidget {
  const PelicanBadge({super.key, this.size = const Size(300, 196)});

  final Size size;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: size,
      painter: _PelicanBadgePainter(),
    );
  }
}

class _PelicanBadgePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final radius = Radius.circular(size.height * 0.1);
    canvas.save();
    canvas.clipRRect(RRect.fromRectAndRadius(rect, radius));

    final sky = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0xFF2E5E8C),
          Color(0xFFFFA45B),
          Color(0xFFFFD9A0),
        ],
        stops: [0, 0.6, 1],
      ).createShader(rect);
    canvas.drawRect(rect, sky);

    final sunCenter = Offset(size.width * 0.78, size.height * 0.3);
    final glow = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFFFFF0C2).withValues(alpha: 0.6),
          const Color(0xFFFFF0C2).withValues(alpha: 0),
        ],
      ).createShader(Rect.fromCircle(center: sunCenter, radius: 70));
    canvas.drawCircle(sunCenter, 70, glow);
    canvas.drawCircle(
      sunCenter,
      size.height * 0.16,
      Paint()..color = const Color(0xFFFFF0C2),
    );

    final seaTop = size.height * 0.64;
    canvas.drawRect(
      Rect.fromLTWH(0, seaTop, size.width, size.height - seaTop),
      Paint()..color = const Color(0xFF2C7A86),
    );
    final wave = Paint()
      ..color = Colors.white.withValues(alpha: 0.22)
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;
    for (var row = 0; row < 3; row++) {
      final y = seaTop + 8 + row * 9.0;
      for (var x = 8.0 + row * 20; x < size.width; x += 74) {
        canvas.drawLine(Offset(x, y), Offset(x + 26, y), wave);
      }
    }

    final hill = Paint()..color = const Color(0xFF586E6C);
    canvas.drawPath(
      Path()
        ..moveTo(0, seaTop)
        ..quadraticBezierTo(
          size.width * 0.18,
          seaTop - size.height * 0.18,
          size.width * 0.42,
          seaTop,
        )
        ..quadraticBezierTo(
          size.width * 0.66,
          seaTop - size.height * 0.12,
          size.width * 0.9,
          seaTop,
        )
        ..lineTo(size.width, seaTop)
        ..lineTo(0, seaTop)
        ..close(),
      hill,
    );

    final roadTop = size.height * 0.84;
    canvas.drawRect(
      Rect.fromLTWH(0, roadTop, size.width, size.height - roadTop),
      Paint()..color = const Color(0xFF3B3B3B),
    );
    final dash = Paint()
      ..color = const Color(0xFFF2E4C9).withValues(alpha: 0.75)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    for (var x = 10.0; x < size.width; x += 46) {
      canvas.drawLine(Offset(x, roadTop + 12), Offset(x + 20, roadTop + 12), dash);
    }

    final artSize = Size(size.width * 0.72, size.height * 0.78);
    canvas.save();
    canvas.translate(size.width * 0.14, size.height * 0.12);
    paintPelicanRider(
      canvas,
      artSize,
      const RideLook(
        wheelAngle: 0.9,
        wingPhase: 1.1,
      ),
    );
    canvas.restore();

    final sparkle = Paint()
      ..color = Colors.white.withValues(alpha: 0.75)
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 3; i++) {
      final angle = 0.6 + i * math.pi * 2 / 3;
      final center = Offset(size.width * 0.2, size.height * 0.24);
      final p = center + Offset(math.cos(angle), math.sin(angle)) * 16;
      canvas.drawLine(p + const Offset(-2, 0), p + const Offset(2, 0), sparkle);
      canvas.drawLine(p + const Offset(0, -2), p + const Offset(0, 2), sparkle);
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
