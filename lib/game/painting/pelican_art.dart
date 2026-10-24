import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../ride_style.dart';

/// 一帧骑行动作所需的姿态参数。
class RideLook {
  final double wheelAngle;
  final double wingPhase;
  final bool ducking;
  final bool airborne;
  final bool shield;
  final bool magnet;

  const RideLook({
    this.wheelAngle = 0,
    this.wingPhase = 0,
    this.ducking = false,
    this.airborne = false,
    this.shield = false,
    this.magnet = false,
  });
}

/// 逻辑画布尺寸（宽 × 高），车轮底部对齐画布底边。
const Size kRiderArtSize = Size(170, 130);

/// 在 [size] 内绘制鹈鹕与自行车，底部居中对齐。
void paintPelicanRider(Canvas canvas, Size size, RideLook look) {
  final scale = math.min(
    size.width / kRiderArtSize.width,
    size.height / kRiderArtSize.height,
  );
  final dx = (size.width - kRiderArtSize.width * scale) / 2;
  final dy = size.height - kRiderArtSize.height * scale;

  canvas.save();
  canvas.translate(dx, dy);
  canvas.scale(scale);

  _paintSpeedMarks(canvas, look);
  _paintBike(canvas, look);
  _paintPelican(canvas, look);
  if (look.shield) _paintShield(canvas, look);
  if (look.magnet) _paintMagnet(canvas, look);

  canvas.restore();
}

void _paintSpeedMarks(Canvas canvas, RideLook look) {
  if (!look.airborne) return;
  final paint = Paint()
    ..color = Colors.white.withValues(alpha: 0.55)
    ..strokeWidth = 2
    ..strokeCap = StrokeCap.round;
  for (var i = 0; i < 3; i++) {
    final y = 82.0 + i * 12;
    final length = 16.0 - i * 3;
    canvas.drawLine(Offset(6, y), Offset(6 + length, y), paint);
  }
}

void _paintWheel(Canvas canvas, Offset center, double angle) {
  final tyre = Paint()
    ..color = RideColors.tyre
    ..style = PaintingStyle.stroke
    ..strokeWidth = 5.5;
  final rim = Paint()
    ..color = RideColors.pelican
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2.4;
  final spoke = Paint()
    ..color = RideColors.pelican.withValues(alpha: 0.8)
    ..strokeWidth = 1.2
    ..strokeCap = StrokeCap.round;
  final hub = Paint()..color = RideColors.frame;

  canvas.drawCircle(center, 26, tyre);
  canvas.drawCircle(center, 20, rim);
  for (var i = 0; i < 5; i++) {
    final a = angle + i * math.pi * 2 / 5;
    canvas.drawLine(
      center,
      center + Offset(math.cos(a), math.sin(a)) * 19,
      spoke,
    );
  }
  canvas.drawCircle(center, 4.5, hub);
}

void _paintBike(Canvas canvas, RideLook look) {
  const rear = Offset(50, 104);
  const front = Offset(128, 104);
  const crank = Offset(84, 104);
  const seat = Offset(72, 66);
  const head = Offset(112, 68);
  const handle = Offset(127, 55);

  _paintWheel(canvas, rear, look.wheelAngle);
  _paintWheel(canvas, front, look.wheelAngle);

  final chain = Paint()
    ..color = RideColors.tyre.withValues(alpha: 0.6)
    ..strokeWidth = 2;
  canvas.drawLine(
    rear + const Offset(0, 5),
    crank + const Offset(0, 5),
    chain,
  );
  canvas.drawLine(
    rear + const Offset(0, -5),
    crank + const Offset(0, -5),
    chain,
  );

  final frame = Paint()
    ..color = RideColors.frame
    ..style = PaintingStyle.stroke
    ..strokeWidth = 5
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  final framePath = Path()
    ..moveTo(rear.dx, rear.dy)
    ..lineTo(seat.dx, seat.dy)
    ..lineTo(head.dx, head.dy)
    ..lineTo(front.dx, front.dy)
    ..moveTo(crank.dx, crank.dy)
    ..lineTo(seat.dx, seat.dy)
    ..moveTo(crank.dx, crank.dy)
    ..lineTo(head.dx, head.dy)
    ..moveTo(rear.dx, rear.dy)
    ..lineTo(crank.dx, crank.dy);
  canvas.drawPath(framePath, frame);

  final handlePaint = Paint()
    ..color = RideColors.frameDark
    ..style = PaintingStyle.stroke
    ..strokeWidth = 4
    ..strokeCap = StrokeCap.round;
  canvas.drawPath(
    Path()
      ..moveTo(head.dx, head.dy)
      ..lineTo(handle.dx - 4, handle.dy)
      ..lineTo(handle.dx + 3, handle.dy),
    handlePaint,
  );

  final saddle = Paint()
    ..color = RideColors.tyre
    ..strokeWidth = 6
    ..strokeCap = StrokeCap.round;
  canvas.drawLine(const Offset(63, 64), const Offset(80, 63), saddle);

  // 车头小篮子与露出的鱼尾
  final basket = Paint()
    ..color = RideColors.crate
    ..style = PaintingStyle.fill;
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      const Rect.fromLTWH(116, 62, 22, 16),
      const Radius.circular(3),
    ),
    basket,
  );
  final basketLine = Paint()
    ..color = RideColors.crateDark
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.2;
  for (var i = 1; i < 3; i++) {
    canvas.drawLine(
      Offset(116 + i * 7.0, 63),
      Offset(116 + i * 7.0, 77),
      basketLine,
    );
  }
  final fishTail = Paint()..color = RideColors.fish;
  canvas.drawPath(
    Path()
      ..moveTo(130, 62)
      ..lineTo(138, 54)
      ..lineTo(140, 61)
      ..lineTo(136, 63)
      ..close(),
    fishTail,
  );

  _paintCrank(canvas, crank, look.wheelAngle);
}

void _paintCrank(Canvas canvas, Offset crank, double angle) {
  final arm = Paint()
    ..color = RideColors.tyre
    ..strokeWidth = 3
    ..strokeCap = StrokeCap.round;
  final pedal = Paint()..color = RideColors.frameDark;

  final a = Offset(math.cos(angle), math.sin(angle)) * 13;
  final b = Offset(-a.dx, -a.dy);

  canvas.drawLine(crank, crank + a, arm);
  canvas.drawLine(crank, crank + b, arm);
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromCenter(center: crank + a, width: 9, height: 4),
      const Radius.circular(2),
    ),
    pedal,
  );
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromCenter(center: crank + b, width: 9, height: 4),
      const Radius.circular(2),
    ),
    pedal,
  );
  canvas.drawCircle(crank, 5, Paint()..color = RideColors.frame);
}

void _paintPelican(Canvas canvas, RideLook look) {
  final ducking = look.ducking;
  final bodyCenter = ducking ? const Offset(98, 90) : const Offset(88, 55);
  final bodyRadius = ducking ? const Size(29, 15) : const Size(27, 21);
  final headCenter = ducking ? const Offset(124, 74) : const Offset(111, 31);
  final headRadius = ducking ? 10.0 : 12.0;
  final beakBase = ducking ? const Offset(132, 70) : const Offset(119, 28);
  final beakTip = ducking ? const Offset(158, 77) : const Offset(147, 35);
  final hip = ducking ? const Offset(92, 84) : const Offset(86, 68);

  _paintLegs(canvas, hip, look);
  _paintTail(canvas, bodyCenter, ducking);

  final body = Paint()..color = RideColors.pelican;
  canvas.drawOval(
    Rect.fromCenter(
      center: bodyCenter,
      width: bodyRadius.width * 2,
      height: bodyRadius.height * 2,
    ),
    body,
  );

  final shade = Paint()..color = RideColors.pelicanShade;
  canvas.drawOval(
    Rect.fromCenter(
      center: bodyCenter + Offset(0, bodyRadius.height * 0.45),
      width: bodyRadius.width * 1.5,
      height: bodyRadius.height * 0.7,
    ),
    shade,
  );

  _paintWing(canvas, look, bodyCenter, ducking);
  _paintNeck(canvas, look, bodyCenter, headCenter, ducking);

  final head = Paint()..color = RideColors.pelican;
  canvas.drawCircle(headCenter, headRadius, head);

  _paintBeak(canvas, beakBase, beakTip, ducking);

  final eye = Paint()..color = RideColors.eye;
  final glint = Paint()..color = Colors.white;
  final eyeCenter = headCenter + (ducking ? const Offset(2, -3) : const Offset(2, -3));
  canvas.drawCircle(eyeCenter, 2.4, eye);
  canvas.drawCircle(eyeCenter + const Offset(0.8, -0.8), 0.9, glint);

  final crest = Paint()
    ..color = RideColors.pelican
    ..strokeWidth = 2.4
    ..strokeCap = StrokeCap.round;
  canvas.drawLine(
    headCenter + Offset(-2, -headRadius + 1),
    headCenter + Offset(-6, -headRadius - 5),
    crest,
  );

  _paintScarf(canvas, look, headCenter, ducking);
}

void _paintTail(Canvas canvas, Offset bodyCenter, bool ducking) {
  final paint = Paint()..color = RideColors.pelicanShade;
  final baseY = ducking ? bodyCenter.dy - 3 : bodyCenter.dy - 2;
  canvas.drawPath(
    Path()
      ..moveTo(bodyCenter.dx - 20, baseY)
      ..lineTo(bodyCenter.dx - 38, baseY - 6)
      ..lineTo(bodyCenter.dx - 34, baseY + 4)
      ..lineTo(bodyCenter.dx - 40, baseY + 9)
      ..lineTo(bodyCenter.dx - 18, baseY + 10)
      ..close(),
    paint,
  );
}

void _paintWing(
  Canvas canvas,
  RideLook look,
  Offset bodyCenter,
  bool ducking,
) {
  final flap = math.sin(look.wingPhase) * (look.airborne ? 0.5 : 0.22);
  final root = ducking
      ? Offset(bodyCenter.dx + 2, bodyCenter.dy - 5)
      : Offset(bodyCenter.dx + 1, bodyCenter.dy - 8);

  canvas.save();
  canvas.translate(root.dx, root.dy);
  canvas.rotate(flap - (ducking ? 0.1 : 0));

  final wing = Path()
    ..moveTo(0, 0)
    ..quadraticBezierTo(-20, -14, -36, -2)
    ..quadraticBezierTo(-24, 12, 0, 7)
    ..close();
  canvas.drawPath(wing, Paint()..color = RideColors.pelican);
  canvas.drawPath(
    wing,
    Paint()
      ..color = RideColors.pelicanShade
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4,
  );

  final feather = Paint()
    ..color = RideColors.pelicanShade
    ..strokeWidth = 1.2
    ..strokeCap = StrokeCap.round;
  for (var i = 1; i <= 3; i++) {
    canvas.drawLine(
      Offset(-9.0 * i, -1),
      Offset(-9.0 * i - 4, 4),
      feather,
    );
  }
  canvas.restore();
}

void _paintNeck(
  Canvas canvas,
  RideLook look,
  Offset bodyCenter,
  Offset headCenter,
  bool ducking,
) {
  final neck = Paint()
    ..color = RideColors.pelican
    ..style = PaintingStyle.stroke
    ..strokeWidth = ducking ? 11.0 : 12.0
    ..strokeCap = StrokeCap.round;
  final start = ducking
      ? Offset(bodyCenter.dx + 12, bodyCenter.dy - 8)
      : Offset(bodyCenter.dx + 8, bodyCenter.dy - 10);
  final end = headCenter + Offset(-headRadiusOffset(ducking), 4);

  canvas.drawPath(
    Path()
      ..moveTo(start.dx, start.dy)
      ..quadraticBezierTo(
        (start.dx + end.dx) / 2 + (ducking ? 5.0 : 7.0),
        (start.dy + end.dy) / 2 + (ducking ? 2.0 : 1.0),
        end.dx,
        end.dy,
      ),
    neck,
  );
}

double headRadiusOffset(bool ducking) => ducking ? 6.0 : 8.0;

void _paintBeak(
  Canvas canvas,
  Offset base,
  Offset tip,
  bool ducking,
) {
  final upper = Paint()..color = RideColors.beak;
  final pouch = Paint()..color = RideColors.pouch;

  final upperPath = Path()
    ..moveTo(base.dx, base.dy - 3)
    ..quadraticBezierTo(
      base.dx + (tip.dx - base.dx) * 0.55,
      tip.dy - (ducking ? 3 : 2),
      tip.dx,
      tip.dy,
    )
    ..lineTo(base.dx + 1, base.dy + 4)
    ..close();
  canvas.drawPath(upperPath, upper);

  final pouchPath = Path()
    ..moveTo(base.dx + 1, base.dy + 2)
    ..quadraticBezierTo(
      base.dx + (tip.dx - base.dx) * 0.5,
      base.dy + (ducking ? 13 : 11),
      tip.dx - 3,
      tip.dy + 1,
    )
    ..lineTo(base.dx + 2, base.dy + 4)
    ..close();
  canvas.drawPath(pouchPath, pouch);

  final line = Paint()
    ..color = RideColors.beak.withValues(alpha: 0.75)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.2;
  canvas.drawLine(
    base + const Offset(1, -2),
    Offset(tip.dx - 1, tip.dy - 1),
    line,
  );
}

void _paintLegs(Canvas canvas, Offset hip, RideLook look) {
  final angle = look.wheelAngle;
  final crank = look.ducking ? const Offset(92, 104) : const Offset(84, 104);
  final a = Offset(math.cos(angle), math.sin(angle)) * 13;
  final pedals = [crank + a, crank - a];

  final farLeg = Paint()
    ..color = RideColors.leg.withValues(alpha: 0.65)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 3.6
    ..strokeCap = StrokeCap.round;
  final nearLeg = Paint()
    ..color = RideColors.leg
    ..style = PaintingStyle.stroke
    ..strokeWidth = 4.4
    ..strokeCap = StrokeCap.round;

  for (var i = 0; i < pedals.length; i++) {
    final pedal = pedals[i];
    final knee = Offset(
      (hip.dx + pedal.dx) / 2 + 5,
      (hip.dy + pedal.dy) / 2 + 2,
    );
    final path = Path()
      ..moveTo(hip.dx, hip.dy)
      ..quadraticBezierTo(knee.dx, knee.dy, pedal.dx, pedal.dy - 2);
    canvas.drawPath(path, i == 0 ? farLeg : nearLeg);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: pedal, width: 8, height: 3),
        const Radius.circular(1.5),
      ),
      Paint()..color = RideColors.leg,
    );
  }
}

void _paintScarf(
  Canvas canvas,
  RideLook look,
  Offset headCenter,
  bool ducking,
) {
  final wave = math.sin(look.wingPhase * 1.6) * 3;
  final start = headCenter + Offset(-4, ducking ? 7.0 : 9.0);
  final scarf = Paint()
    ..color = RideColors.scarf
    ..style = PaintingStyle.fill;

  final path = Path()
    ..moveTo(start.dx, start.dy - 3)
    ..quadraticBezierTo(
      start.dx - 12,
      start.dy + wave,
      start.dx - 26,
      start.dy - 2 + wave,
    )
    ..lineTo(start.dx - 24, start.dy + 4 + wave)
    ..quadraticBezierTo(
      start.dx - 12,
      start.dy + 7,
      start.dx,
      start.dy + 3,
    )
    ..close();
  canvas.drawPath(path, scarf);
  canvas.drawCircle(start, 3.2, scarf);
}

void _paintShield(Canvas canvas, RideLook look) {
  final center = look.ducking ? const Offset(98, 76) : const Offset(92, 64);
  final glow = Paint()..color = RideColors.shield.withValues(alpha: 0.09);
  final ring = Paint()
    ..color = RideColors.shield.withValues(alpha: 0.7)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2.4;
  canvas.drawCircle(center, 64, glow);
  canvas.drawCircle(center, 64, ring);

  final sparkle = Paint()
    ..color = Colors.white.withValues(alpha: 0.8)
    ..strokeWidth = 1.6;
  for (var i = 0; i < 3; i++) {
    final a = look.wheelAngle * 0.4 + i * math.pi * 2 / 3;
    final p = center + Offset(math.cos(a), math.sin(a)) * 61;
    canvas.drawLine(p + const Offset(-2, 0), p + const Offset(2, 0), sparkle);
    canvas.drawLine(p + const Offset(0, -2), p + const Offset(0, 2), sparkle);
  }
}

void _paintMagnet(Canvas canvas, RideLook look) {
  final paint = Paint()
    ..color = RideColors.magnet.withValues(alpha: 0.55)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2;
  const center = Offset(84, 82);
  for (var i = 0; i < 2; i++) {
    final radius = 54.0 + i * 10 + math.sin(look.wingPhase * 2) * 2;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      math.pi * 0.15,
      math.pi * 0.7,
      false,
      paint,
    );
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      math.pi * 1.15,
      math.pi * 0.7,
      false,
      paint,
    );
  }
}
