import 'dart:math' as math;
import 'dart:ui';

import '../iso_projection.dart';
import '../ride_style.dart';
import 'scene_layer_component.dart';

/// 海面远景：远处时而有鱼跃出水面。
///
/// 只随时间做轻微横向漂移，每帧仅绘制少量 Path，
/// 叠在远景海面之上、路面之下。
class SeaLifeComponent extends SceneLayerComponent {
  SeaLifeComponent({required super.provider, super.priority});

  /// 跃出水面的鱼：各自的周期、相位、横向位置与体型。
  static const List<_FishJumpSeed> _jumpSeeds = <_FishJumpSeed>[
    _FishJumpSeed(period: 6.4, phase: 0.12, x: 128, size: 8),
    _FishJumpSeed(period: 8.7, phase: 0.48, x: 386, size: 7),
    _FishJumpSeed(period: 11.3, phase: 0.76, x: 612, size: 9),
  ];

  /// 跃出水面占一个周期的比例，其余时间潜在水下。
  static const double _jumpPortion = 0.22;

  /// 跃鱼所在的水面：靠近海天交界，明显远离近岸沙滩。
  static double get _waterlineY => IsoProjection.seaEdgeY - 66;

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
    for (final seed in _jumpSeeds) {
      _paintJump(canvas, seed);
    }
  }

  void _paintJump(Canvas canvas, _FishJumpSeed seed) {
    final cycle = (_elapsed / seed.period + seed.phase) % 1.0;
    final water = Offset(
      seed.x + math.sin(_elapsed * 0.18 + seed.phase * 6) * 9,
      _waterlineY,
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
