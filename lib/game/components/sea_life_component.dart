import 'dart:math' as math;
import 'dart:ui';

import '../iso_projection.dart';
import '../ride_style.dart';
import 'scene_layer_component.dart';

/// 海面远景：远处时而有鱼跃出水面。
///
/// 跃出与入水的位置各溅起一次浪花，只随时间做轻微横向漂移，
/// 每帧仅绘制少量 Path，叠在远景海面之上、路面之下。
class SeaLifeComponent extends SceneLayerComponent {
  SeaLifeComponent({required super.provider, super.priority});

  /// 跃出水面的鱼：各自的周期、相位、横向位置与体型。
  static const List<_FishJumpSeed> _jumpSeeds = <_FishJumpSeed>[
    _FishJumpSeed(period: 6.4, phase: 0.12, x: 128, size: 8),
    _FishJumpSeed(period: 8.7, phase: 0.48, x: 386, size: 7),
    _FishJumpSeed(period: 11.3, phase: 0.76, x: 612, size: 9),
  ];

  /// 跃鱼所在的水面：靠近海天交界，明显远离近岸沙滩。
  static double get _waterlineY => IsoProjection.seaEdgeY - 66;

  final Paint _fishPaint = Paint()..color = RideColors.fish;
  final Paint _fishShadePaint = Paint()..color = RideColors.fishDark;
  final Paint _splashPaint = Paint()
    ..color = const Color(0xFFFFFFFF).withValues(alpha: 0.5)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.2;
  final Paint _ripplePaint = Paint()
    ..color = const Color(0xFFFFFFFF).withValues(alpha: 0.4)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.4;

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
    final span = 38.0 + seed.size * 1.6;
    // 跃出点在水面左端，落入点在水面右端。
    final takeOff = Offset(water.dx - span / 2, water.dy);
    final landing = Offset(water.dx + span / 2, water.dy);

    final splash = SeaJumpSplash.at(cycle: cycle, period: seed.period);

    if (cycle >= SeaJumpSplash.jumpPortion) {
      // 鱼已经入水，画面只剩落水浪花与向外扩散的波纹。
      if (splash.landingStrength > 0) {
        _paintSplash(canvas, landing, splash.landingStrength);
      }
      _paintRipples(canvas, landing, splash.rippleProgress);
      return;
    }

    final t = cycle / SeaJumpSplash.jumpPortion;
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

    // 跃出瞬间在起跳点溅一次水花；落水浪花必须等鱼真正入水后才出现。
    if (splash.takeOffStrength > 0) {
      _paintSplash(canvas, takeOff, splash.takeOffStrength);
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

  /// 入水瞬间从落点向外扩散的波纹：两圈错开出现，边扩散边淡出。
  void _paintRipples(Canvas canvas, Offset landing, List<double> progresses) {
    for (final progress in progresses) {
      if (progress <= 0 || progress >= 1) continue;
      final fade = 1 - progress;
      _ripplePaint
        ..color = const Color(0xFFFFFFFF).withValues(alpha: 0.4 * fade)
        ..strokeWidth = 1.6 - 0.8 * progress;
      canvas.drawOval(
        Rect.fromCenter(
          center: landing + const Offset(0, -1),
          width: 12 + 40 * progress,
          height: 3.4 + 8 * progress,
        ),
        _ripplePaint,
      );
    }
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

/// 跃鱼溅水的时序：跃出瞬间只出水花，落水浪花与波纹都在鱼真正入水后开始。
///
/// 纯逻辑、便于单测：输入周期内的位置 [cycle] 与周期长度 [period]，
/// 输出各处水花强度与波纹进度（未裁剪，绘制时只取 0 < p < 1）。
class SeaJumpSplash {
  const SeaJumpSplash._({
    required this.takeOffStrength,
    required this.landingStrength,
    required this.rippleProgress,
  });

  /// 跃出水面占一个周期的比例，其余时间潜在水下。
  static const double jumpPortion = 0.22;

  /// 跃出水花持续多久，按跃出阶段的比例计。
  static const double takeOffSplashPortion = 0.3;

  /// 落水浪花持续时长（秒），从入水那一刻开始计时。
  static const double splashSeconds = 0.55;

  /// 入水波纹的圈数、单圈时长与相邻两圈的间隔（秒）。
  static const int rippleCount = 2;
  static const double rippleSeconds = 0.85;
  static const double rippleStagger = 0.22;

  factory SeaJumpSplash.at({
    required double cycle,
    required double period,
  }) {
    final airborne = cycle < jumpPortion;
    final t = airborne ? cycle / jumpPortion : 1.0;
    final sinceLanding = airborne ? 0.0 : (cycle - jumpPortion) * period;
    return SeaJumpSplash._(
      takeOffStrength: airborne && t < takeOffSplashPortion
          ? 1 - t / takeOffSplashPortion
          : 0,
      landingStrength: airborne
          ? 0
          : (sinceLanding < splashSeconds
                ? 1 - sinceLanding / splashSeconds
                : 0),
      rippleProgress: <double>[
        if (!airborne)
          for (var i = 0; i < rippleCount; i++)
            (sinceLanding - rippleStagger * i) / rippleSeconds,
      ],
    );
  }

  /// 跃出瞬间的水花强度；0 表示这一帧不画。
  final double takeOffStrength;

  /// 入水瞬间起的水花强度，鱼还在空中时恒为 0。
  final double landingStrength;

  /// 波纹扩散进度：0 表示刚入水，1 表示散尽。
  final List<double> rippleProgress;
}
