import 'dart:math' as math;
import 'dart:ui';

import '../iso_projection.dart';
import '../ride_style.dart';
import 'scene_layer_component.dart';

/// 海面生活细节：远处渔夫划船，近岸时而有鱼跃出水面。
///
/// 只读取骑行距离做极慢的视差漂移，每帧仅绘制少量 Path，
/// 叠在远景海面之上、路面之下。
class SeaLifeComponent extends SceneLayerComponent {
  SeaLifeComponent({required super.provider, super.priority});

  /// 跃出水面的鱼：各自的周期、相位、横向位置与体型。
  static const List<_FishJumpSeed> _jumpSeeds = <_FishJumpSeed>[
    _FishJumpSeed(period: 6.4, phase: 0.12, x: 128, size: 10),
    _FishJumpSeed(period: 8.7, phase: 0.48, x: 386, size: 8),
    _FishJumpSeed(period: 11.3, phase: 0.76, x: 612, size: 12),
  ];

  /// 跃出水面占一个周期的比例，其余时间潜在水下。
  static const double _jumpPortion = 0.22;

  final Paint _hullPaint = Paint()..color = const Color(0xFF5A3B25);
  final Paint _hullRimPaint = Paint()
    ..color = const Color(0xFF95683E)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2;
  final Paint _benchPaint = Paint()
    ..color = const Color(0xFF7A5230)
    ..strokeWidth = 2;
  final Paint _figurePaint = Paint()..color = const Color(0xFF2C3A3E);
  final Paint _hatPaint = Paint()..color = const Color(0xFFD2A85F);
  final Paint _armPaint = Paint()
    ..color = const Color(0xFF2C3A3E)
    ..strokeWidth = 2
    ..strokeCap = StrokeCap.round;
  final Paint _oarPaint = Paint()
    ..color = const Color(0xFF6B4A2E)
    ..strokeWidth = 1.6
    ..strokeCap = StrokeCap.round;
  final Paint _ripplePaint = Paint()
    ..color = const Color(0xFFFFFFFF).withValues(alpha: 0.24)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.1;
  final Paint _fishPaint = Paint()..color = RideColors.fish;
  final Paint _fishShadePaint = Paint()..color = RideColors.fishDark;
  final Paint _splashPaint = Paint()
    ..color = const Color(0xFFFFFFFF).withValues(alpha: 0.5)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.2;

  double _elapsed = 0;

  @override
  void update(double dt) {
    super.update(dt);
    if (provider.isPlaying) _elapsed += dt;
  }

  @override
  void render(Canvas canvas) {
    final travel = IsoProjection.travelPixels(provider.state.distance);
    _paintBoat(canvas, travel);
    for (final seed in _jumpSeeds) {
      _paintJump(canvas, seed);
    }
  }

  void _paintBoat(Canvas canvas, double travel) {
    final baseX =
        width * 0.66 + math.sin(travel * 0.00035 + _elapsed * 0.05) * 12;
    final baseY = IsoProjection.seaEdgeY - 36 + math.sin(_elapsed * 1.3) * 1.6;

    canvas.save();
    canvas.translate(baseX, baseY);
    canvas.rotate(math.sin(_elapsed * 0.9) * 0.025);

    // 船体、船舷与坐板
    final hull = Path()
      ..moveTo(-30, -7)
      ..lineTo(30, -7)
      ..quadraticBezierTo(24, 9, 0, 10)
      ..quadraticBezierTo(-24, 9, -30, -7)
      ..close();
    canvas.drawPath(hull, _hullPaint);
    canvas.drawLine(const Offset(-30, -7), const Offset(30, -7), _hullRimPaint);
    canvas.drawLine(const Offset(-9, -7), const Offset(9, -7), _benchPaint);

    // 渔夫：身体、头、斗笠与手臂
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(0, -16), width: 12, height: 15),
      _figurePaint,
    );
    canvas.drawCircle(const Offset(0, -27), 4.4, _figurePaint);
    canvas.drawPath(
      Path()
        ..moveTo(-9, -29)
        ..lineTo(9, -29)
        ..lineTo(0, -36)
        ..close(),
      _hatPaint,
    );

    // 船桨随划水节奏摆动，桨叶落在船体下方水面上
    final row = math.sin(_elapsed * 2.2);
    final bladeY = 12 + row * 2;
    for (final side in <double>[-1, 1]) {
      final hand = Offset(side * 3, -20);
      final blade = Offset(side * 26, bladeY);
      canvas.drawLine(hand, blade, _oarPaint);
      canvas.drawLine(blade, blade + Offset(side * 4, 1.4), _oarPaint);
      canvas.drawLine(
        Offset(side, -21),
        Offset(side * 5 + row * 2, -14),
        _armPaint,
      );
    }

    // 船底水纹
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(0, 10), width: 74, height: 8),
      _ripplePaint,
    );
    canvas.restore();
  }

  void _paintJump(Canvas canvas, _FishJumpSeed seed) {
    final cycle = (_elapsed / seed.period + seed.phase) % 1.0;
    final water = Offset(
      seed.x + math.sin(_elapsed * 0.18 + seed.phase * 6) * 9,
      IsoProjection.seaEdgeY - 10,
    );

    if (cycle >= _jumpPortion) {
      final after = (cycle - _jumpPortion) / 0.09;
      if (after < 1) {
        _paintSplash(canvas, water, 1 - after);
      }
      return;
    }

    final t = cycle / _jumpPortion;
    final span = 38.0 + seed.size * 1.6;
    final height = 18.0 + seed.size * 0.9;
    final center = Offset(
      water.dx + (t - 0.5) * span,
      water.dy - math.sin(t * math.pi) * height,
    );
    final slope = -math.cos(t * math.pi) * math.pi * height;
    final angle = math.atan2(slope, span);

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(angle);
    final scale = seed.size / 10;
    canvas.scale(scale);
    canvas.drawOval(
      Rect.fromCenter(center: Offset.zero, width: 15, height: 6),
      _fishPaint,
    );
    canvas.drawPath(
      Path()
        ..moveTo(-7, 0)
        ..lineTo(-13, -4.5)
        ..lineTo(-13, 4.5)
        ..close(),
      _fishShadePaint,
    );
    canvas.drawCircle(const Offset(4.8, -1), 0.9, _fishShadePaint);
    canvas.restore();

    final nearSurface = math.min(t, 1 - t);
    if (nearSurface < 0.3) {
      _paintSplash(canvas, water, 1 - nearSurface / 0.3);
    }
  }

  void _paintSplash(Canvas canvas, Offset water, double strength) {
    _splashPaint.color = const Color(
      0xFFFFFFFF,
    ).withValues(alpha: 0.5 * strength);
    canvas.drawOval(
      Rect.fromCenter(
        center: water,
        width: 18 + 10 * (1 - strength),
        height: 4.2,
      ),
      _splashPaint,
    );
    canvas.drawArc(
      Rect.fromCenter(
        center: water + const Offset(0, -1),
        width: 26,
        height: 12,
      ),
      math.pi * 0.15,
      math.pi * 0.7,
      false,
      _splashPaint,
    );
  }
}

class _FishJumpSeed {
  const _FishJumpSeed({
    required this.period,
    required this.phase,
    required this.x,
    required this.size,
  });

  final double period;
  final double phase;
  final double x;
  final double size;
}
