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

/// 曲柄中心与踏板旋转半径。
const Offset _crankCenter = Offset(84, 104);
const double _crankRadius = 13;

/// 把画布变换到 [kRiderArtSize] 的本地坐标系（底部居中对齐）。
///
/// 组件在加载时用同一次变换烘焙静态层，运行时只需调用一次本函数；
/// 后续各 `paintRider*` 画法都假设画布已处于该坐标系。
void applyRiderArtTransform(Canvas canvas, Size size) {
  final scale = math.min(
    size.width / kRiderArtSize.width,
    size.height / kRiderArtSize.height,
  );
  canvas.translate(
    (size.width - kRiderArtSize.width * scale) / 2,
    size.height - kRiderArtSize.height * scale,
  );
  canvas.scale(scale);
}

/// 一帧完整的鹈鹕与自行车：按前后遮挡关系逐层绘制。
///
/// 渲染组件会把静态层换成加载时烘焙好的 [Picture]，这里保留完整流程，
/// 供测试与单帧离屏渲染使用。
void paintPelicanRider(Canvas canvas, Size size, RideLook look) {
  canvas.save();
  applyRiderArtTransform(canvas, size);
  paintRiderSpeedMarks(canvas, look);
  paintRiderWheels(canvas, look);
  paintRiderBikeStatic(canvas);
  paintRiderCranks(canvas, look);
  paintRiderLegs(canvas, look);
  paintRiderBodyStatic(canvas, ducking: look.ducking);
  paintRiderWing(canvas, look);
  paintRiderScarf(canvas, look);
  paintRiderPedals(canvas, look);
  paintRiderEffects(canvas, look);
  canvas.restore();
}

// ---------------------------------------------------------------------------
// 分层画法：静态层可烘焙成 Picture，动态层每帧重绘
// ---------------------------------------------------------------------------

/// 空中的速度线，只在腾空时出现。
void paintRiderSpeedMarks(Canvas canvas, RideLook look) {
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

/// 两个车轮：随车轮角度转动，画在车架之下。
void paintRiderWheels(Canvas canvas, RideLook look) {
  _paintWheel(canvas, _rearWheel, look.wheelAngle);
  _paintWheel(canvas, _frontWheel, look.wheelAngle);
}

/// 车身静态层：链条、车架、手柄、坐垫、车筐与露出的鱼尾。
///
/// 与姿态、车轮角度都无关，因此可在加载时烘焙一次。
void paintRiderBikeStatic(Canvas canvas) {
  final chain = Paint()
    ..color = RideColors.tyre.withValues(alpha: 0.6)
    ..strokeWidth = 2;
  canvas.drawLine(
    _rearWheel + const Offset(0, 5),
    _crankCenter + const Offset(0, 5),
    chain,
  );
  canvas.drawLine(
    _rearWheel + const Offset(0, -5),
    _crankCenter + const Offset(0, -5),
    chain,
  );

  final frame = Paint()
    ..color = RideColors.frame
    ..style = PaintingStyle.stroke
    ..strokeWidth = 5
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  final framePath = Path()
    ..moveTo(_rearWheel.dx, _rearWheel.dy)
    ..lineTo(_seat.dx, _seat.dy)
    ..lineTo(_headTube.dx, _headTube.dy)
    ..lineTo(_frontWheel.dx, _frontWheel.dy)
    ..moveTo(_crankCenter.dx, _crankCenter.dy)
    ..lineTo(_seat.dx, _seat.dy)
    ..moveTo(_crankCenter.dx, _crankCenter.dy)
    ..lineTo(_headTube.dx, _headTube.dy)
    ..moveTo(_rearWheel.dx, _rearWheel.dy)
    ..lineTo(_crankCenter.dx, _crankCenter.dy);
  canvas.drawPath(framePath, frame);

  final handlePaint = Paint()
    ..color = RideColors.frameDark
    ..style = PaintingStyle.stroke
    ..strokeWidth = 4
    ..strokeCap = StrokeCap.round;
  canvas.drawPath(
    Path()
      ..moveTo(_headTube.dx, _headTube.dy)
      ..lineTo(_handle.dx - 4, _handle.dy)
      ..lineTo(_handle.dx + 3, _handle.dy),
    handlePaint,
  );

  final saddle = Paint()
    ..color = RideColors.tyre
    ..strokeWidth = 6
    ..strokeCap = StrokeCap.round;
  canvas.drawLine(const Offset(63, 64), const Offset(80, 63), saddle);

  // 车头小篮子与露出的鱼尾
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      const Rect.fromLTWH(116, 62, 22, 16),
      const Radius.circular(3),
    ),
    Paint()
      ..color = RideColors.crate
      ..style = PaintingStyle.fill,
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
  canvas.drawPath(
    Path()
      ..moveTo(130, 62)
      ..lineTo(138, 54)
      ..lineTo(140, 61)
      ..lineTo(136, 63)
      ..close(),
    Paint()..color = RideColors.fish,
  );
}

/// 牙盘与曲柄臂，夹在车身与腿之间。
void paintRiderCranks(Canvas canvas, RideLook look) {
  _paintCrankArms(canvas, _crankCenter, look.wheelAngle);
}

/// 鹈鹕静态层：尾、身体、脖子、头、喙与眼睛。
///
/// 只与站姿/俯身两种姿态有关，因此每种姿态烘焙一张。
void paintRiderBodyStatic(Canvas canvas, {required bool ducking}) {
  final bodyCenter = _bodyCenterFor(ducking);
  final bodyRadius = _bodyRadiusFor(ducking);
  final headCenter = _headCenterFor(ducking);
  final headRadius = _headRadiusFor(ducking);

  _paintTail(canvas, bodyCenter, ducking);

  canvas.drawOval(
    Rect.fromCenter(
      center: bodyCenter,
      width: bodyRadius.width * 2,
      height: bodyRadius.height * 2,
    ),
    Paint()..color = RideColors.pelican,
  );

  canvas.drawOval(
    Rect.fromCenter(
      center: bodyCenter + Offset(0, bodyRadius.height * 0.45),
      width: bodyRadius.width * 1.5,
      height: bodyRadius.height * 0.7,
    ),
    Paint()..color = RideColors.pelicanShade,
  );

  _paintNeck(canvas, bodyCenter, headCenter, ducking);

  canvas.drawCircle(
    headCenter,
    headRadius,
    Paint()..color = RideColors.pelican,
  );

  _paintBeak(canvas, _beakBaseFor(ducking), _beakTipFor(ducking), ducking);

  final eyeCenter = headCenter + const Offset(4.5, -3.2);
  canvas.drawCircle(eyeCenter, 2.6, Paint()..color = RideColors.eye);
  canvas.drawCircle(
    eyeCenter + const Offset(1.0, -1.0),
    0.9,
    Paint()..color = Colors.white,
  );

  canvas.drawLine(
    headCenter + Offset(-2, -headRadius + 1),
    headCenter + Offset(-6, -headRadius - 5),
    Paint()
      ..color = RideColors.pelican
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round,
  );
}

/// 扇动的翅膀，画在身体之上。
void paintRiderWing(Canvas canvas, RideLook look) {
  _paintWing(canvas, look, _bodyCenterFor(look.ducking), look.ducking);
}

/// 围巾与飘尾，随扇翅相位轻微摆动。
void paintRiderScarf(Canvas canvas, RideLook look) {
  _paintScarf(canvas, look, _headCenterFor(look.ducking), look.ducking);
}

/// 双腿：蹼足跟随踏板位置踩踏。
void paintRiderLegs(Canvas canvas, RideLook look) {
  _paintLegs(canvas, _hipFor(look.ducking), look);
}

/// 踏板画在腿之上，避免被蹼足盖住。
void paintRiderPedals(Canvas canvas, RideLook look) {
  _paintPedals(canvas, look);
}

/// 护盾与磁铁光环。
void paintRiderEffects(Canvas canvas, RideLook look) {
  if (look.shield) _paintShield(canvas, look);
  if (look.magnet) _paintMagnet(canvas, look);
}

void _paintWheel(Canvas canvas, Offset center, double angle) {
  // 胎体用固定内外半径的实心圆环，避免描边在整体缩放后出现粗细不匀。
  final tyre = Path()
    ..fillType = PathFillType.evenOdd
    ..addOval(Rect.fromCircle(center: center, radius: 26))
    ..addOval(Rect.fromCircle(center: center, radius: 20));
  canvas.drawPath(tyre, Paint()..color = RideColors.tyre);

  final rim = Paint()
    ..color = RideColors.pelican
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2.2;
  canvas.drawCircle(center, 19.4, rim);

  final spoke = Paint()
    ..color = RideColors.pelican.withValues(alpha: 0.8)
    ..strokeWidth = 1.2
    ..strokeCap = StrokeCap.round;
  for (var i = 0; i < 5; i++) {
    final a = angle + i * math.pi * 2 / 5;
    canvas.drawLine(
      center,
      center + Offset(math.cos(a), math.sin(a)) * 18.4,
      spoke,
    );
  }
  canvas.drawCircle(center, 4.5, Paint()..color = RideColors.frame);
}

/// 车架上的固定锚点：后轮、前轮、坐垫、头管与车把。
const Offset _rearWheel = Offset(50, 104);
const Offset _frontWheel = Offset(128, 104);
const Offset _seat = Offset(72, 66);
const Offset _headTube = Offset(112, 68);
const Offset _handle = Offset(127, 55);

/// 站立与俯身两套姿态锚点，静态层与动态层共用。
Offset _bodyCenterFor(bool ducking) =>
    ducking ? const Offset(98, 90) : const Offset(88, 55);

Size _bodyRadiusFor(bool ducking) =>
    ducking ? const Size(29, 15) : const Size(27, 21);

Offset _headCenterFor(bool ducking) =>
    ducking ? const Offset(124, 74) : const Offset(111, 31);

double _headRadiusFor(bool ducking) => ducking ? 10.0 : 12.0;

Offset _beakBaseFor(bool ducking) =>
    ducking ? const Offset(129, 67) : const Offset(117, 26);

Offset _beakTipFor(bool ducking) =>
    ducking ? const Offset(166, 81) : const Offset(158, 37);

Offset _hipFor(bool ducking) =>
    ducking ? const Offset(92, 84) : const Offset(86, 68);

/// 牙盘与两根曲柄臂：画在车身层，随后被腿和踏板覆盖出前后关系。
void _paintCrankArms(Canvas canvas, Offset crank, double angle) {
  final a = Offset(math.cos(angle), math.sin(angle)) * _crankRadius;
  final b = Offset(-a.dx, -a.dy);

  final arm = Paint()
    ..color = RideColors.frameDark
    ..style = PaintingStyle.stroke
    ..strokeWidth = 3.2
    ..strokeCap = StrokeCap.round;
  canvas.drawLine(crank, crank + a, arm);
  canvas.drawLine(crank, crank + b, arm);

  canvas.drawCircle(crank, 8, Paint()..color = RideColors.tyre);
  canvas.drawCircle(
    crank,
    8,
    Paint()
      ..color = RideColors.pelican.withValues(alpha: 0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1,
  );
  canvas.drawCircle(crank, 4.4, Paint()..color = RideColors.frameDark);
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
  final span = tip.dx - base.dx;
  final depth = ducking ? 24.0 : 21.0;

  final upperPath = Path()
    ..moveTo(base.dx, base.dy - 4)
    ..quadraticBezierTo(
      base.dx + span * 0.45,
      tip.dy - (ducking ? 7 : 6),
      tip.dx,
      tip.dy,
    )
    ..lineTo(tip.dx - 2, tip.dy + 3)
    ..quadraticBezierTo(
      base.dx + span * 0.5,
      base.dy + 4,
      base.dx + 1,
      base.dy + 5,
    )
    ..close();
  canvas.drawPath(upperPath, upper);

  // 夸张的下颌喉囊：从嘴角一路垂到接近车轮的高度。
  final pouchPath = Path()
    ..moveTo(base.dx + 2, base.dy + 3)
    ..quadraticBezierTo(
      base.dx + span * 0.45,
      base.dy + depth,
      tip.dx - 4,
      tip.dy + 3,
    )
    ..lineTo(tip.dx - 2, tip.dy + 1)
    ..lineTo(base.dx + 3, base.dy + 5)
    ..close();
  canvas.drawPath(pouchPath, pouch);

  final line = Paint()
    ..color = const Color(0xFFD97A1E)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.6
    ..strokeCap = StrokeCap.round;
  canvas.drawPath(
    Path()
      ..moveTo(base.dx + 2, base.dy + 1)
      ..quadraticBezierTo(
        base.dx + span * 0.55,
        tip.dy + (ducking ? 2 : 1),
        tip.dx - 1,
        tip.dy + 1,
      ),
    line,
  );
  canvas.drawCircle(
    Offset(base.dx + span * 0.16, base.dy - 1),
    1.3,
    Paint()..color = const Color(0xFFD97A1E).withValues(alpha: 0.55),
  );
}

void _paintLegs(Canvas canvas, Offset hip, RideLook look) {
  final a =
      Offset(math.cos(look.wheelAngle), math.sin(look.wheelAngle)) *
      _crankRadius;
  final pedalPositions = <Offset>[_crankCenter + a, _crankCenter - a];

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

  for (var i = 0; i < pedalPositions.length; i++) {
    // 蹼足落在踏板上方一点，踏板随后画在最上层，两者都能看清。
    final foot = pedalPositions[i] + const Offset(0, -4);
    final knee = Offset(
      (hip.dx + foot.dx) / 2 + 5,
      (hip.dy + foot.dy) / 2 + 2,
    );
    final path = Path()
      ..moveTo(hip.dx, hip.dy)
      ..quadraticBezierTo(knee.dx, knee.dy, foot.dx - 1, foot.dy);
    canvas.drawPath(path, i == 0 ? farLeg : nearLeg);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: foot, width: 9, height: 3.4),
        const Radius.circular(1.6),
      ),
      Paint()
        ..color = i == 0
            ? RideColors.leg.withValues(alpha: 0.75)
            : RideColors.leg,
    );
  }
}

/// 踏板单独画在腿之上，避免被蹼足盖住；深色踏板面加高光便于辨认。
void _paintPedals(Canvas canvas, RideLook look) {
  final a =
      Offset(math.cos(look.wheelAngle), math.sin(look.wheelAngle)) *
      _crankRadius;
  final pedalPositions = <Offset>[_crankCenter + a, _crankCenter - a];

  final body = Paint()..color = RideColors.frameDark;
  final face = Paint()
    ..color = RideColors.roadLine.withValues(alpha: 0.85)
    ..strokeWidth = 1.3
    ..strokeCap = StrokeCap.round;
  final spindle = Paint()..color = RideColors.tyre;

  for (final pedal in pedalPositions) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: pedal, width: 18, height: 6.2),
        const Radius.circular(2.4),
      ),
      body,
    );
    canvas.drawLine(
      pedal + const Offset(-6.5, -2.1),
      pedal + const Offset(6.5, -2.1),
      face,
    );
    canvas.drawCircle(pedal, 1.4, spindle);
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
