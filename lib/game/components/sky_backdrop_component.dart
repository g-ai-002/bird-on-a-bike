import 'dart:math' as math;
import 'dart:ui';

import '../../utils/constants.dart';
import '../iso_projection.dart';
import '../ride_style.dart';
import 'scene_layer_component.dart';

/// 黄昏海岸远景：渐变天空、落日、云、远山与海面。
///
/// 每层按不同系数随骑行距离平移，形成视差滚动；海浪与云还叠加了
/// 与距离无关的缓慢漂移，让暂停时画面也不至于完全静止。
class SkyBackdropComponent extends SceneLayerComponent {
  SkyBackdropComponent({required super.provider, super.priority});

  static const Color _cloud = Color(0xFFFFF4E2);
  static const Color _cloudShade = Color(0xFFF3CDA6);

  static const List<_CloudSeed> _clouds = <_CloudSeed>[
    _CloudSeed(70, 92, 1.05),
    _CloudSeed(250, 66, 0.72),
    _CloudSeed(430, 104, 1.25),
    _CloudSeed(640, 74, 0.82),
    _CloudSeed(860, 96, 1.1),
    _CloudSeed(1010, 62, 0.66),
  ];

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
    final state = provider.state;
    final travel = IsoProjection.travelPixels(state.distance);

    _paintSky(canvas);
    _paintSun(canvas);
    _paintClouds(canvas, travel);
    _paintRidges(canvas, travel);
    _paintLighthouse(canvas);
    _paintSea(canvas);
    _paintWaveGlints(canvas, travel);
  }

  void _paintSky(Canvas canvas) {
    final rect = Rect.fromLTWH(0, 0, width, IsoProjection.horizonY + 8);
    canvas.drawRect(
      rect,
      Paint()
        ..shader = Gradient.linear(
          Offset.zero,
          const Offset(0, IsoProjection.horizonY + 8),
          <Color>[
            RideColors.skyTop,
            RideColors.skyMid,
            RideColors.skyLow,
          ],
          <double>[0, 0.58, 1],
        ),
    );
    canvas.drawRect(
      Rect.fromLTWH(0, IsoProjection.horizonY - 26, width, 26),
      Paint()
        ..shader = Gradient.linear(
          const Offset(0, IsoProjection.horizonY - 26),
          const Offset(0, IsoProjection.horizonY),
          <Color>[
            RideColors.skyMid.withValues(alpha: 0),
            RideColors.skyMid.withValues(alpha: 0.55),
          ],
        ),
    );
  }

  void _paintSun(Canvas canvas) {
    final center = Offset(width * 0.78, IsoProjection.horizonY - 14);
    canvas.drawCircle(
      center,
      132,
      Paint()
        ..shader = Gradient.radial(center, 132, <Color>[
          RideColors.sun.withValues(alpha: 0.5),
          RideColors.sun.withValues(alpha: 0.16),
          RideColors.sun.withValues(alpha: 0),
        ], <double>[0, 0.42, 1]),
    );
    canvas.drawCircle(
      center,
      43,
      Paint()
        ..shader = Gradient.radial(center, 43, <Color>[
          const Color(0xFFFFFDF2),
          RideColors.sun,
          RideColors.skyMid.withValues(alpha: 0.9),
        ], <double>[0, 0.62, 1]),
    );
  }

  void _paintClouds(Canvas canvas, double travel) {
    const wrap = AppConstants.worldWidth + 320.0;
    final drift = travel * 0.08 + _elapsed * 3.5;
    for (final seed in _clouds) {
      final x = (seed.x - drift) % wrap - 160;
      _paintCloud(
        canvas,
        Offset(x, seed.y + math.sin(_elapsed * 0.35 + seed.x) * 2),
        seed.scale,
      );
    }
  }

  void _paintCloud(Canvas canvas, Offset center, double scale) {
    final body = Paint()..color = _cloud.withValues(alpha: 0.78);
    final shade = Paint()..color = _cloudShade.withValues(alpha: 0.32);
    const puffs = <(double, double, double)>[
      (-40, 2, 15),
      (-18, -8, 21),
      (6, -2, 25),
      (30, 4, 18),
      (48, 8, 12),
    ];
    for (final puff in puffs) {
      canvas.drawCircle(
        center + Offset(puff.$1 * scale, puff.$2 * scale),
        puff.$3 * scale,
        body,
      );
    }
    canvas.drawOval(
      Rect.fromCenter(
        center: center + Offset(2 * scale, 10 * scale),
        width: 96 * scale,
        height: 16 * scale,
      ),
      shade,
    );
  }

  void _paintRidges(Canvas canvas, double travel) {
    _paintRidge(
      canvas,
      travel: travel,
      speed: 0.16,
      baseY: IsoProjection.horizonY + 4,
      period: 300,
      peak: 54,
      phase: 1.2,
      color: RideColors.hillFar.withValues(alpha: 0.55),
    );
    _paintRidge(
      canvas,
      travel: travel,
      speed: 0.28,
      baseY: IsoProjection.horizonY + 8,
      period: 214,
      peak: 36,
      phase: 3.4,
      color: RideColors.hillNear.withValues(alpha: 0.72),
    );
  }

  void _paintRidge(
    Canvas canvas, {
    required double travel,
    required double speed,
    required double baseY,
    required double period,
    required double peak,
    required double phase,
    required Color color,
  }) {
    final offset = (travel * speed) % period;
    final path = Path()..moveTo(-period, baseY);
    var i = -1;
    while (i * period - offset < width + period) {
      final x = i * period - offset;
      final h = peak * (0.5 + 0.5 * math.sin(i * 1.7 + phase).abs());
      path
        ..lineTo(x, baseY)
        ..quadraticBezierTo(x + period * 0.5, baseY - h * 1.7, x + period, baseY);
      i++;
    }
    path
      ..lineTo(width + period, baseY)
      ..lineTo(width + period, height)
      ..lineTo(-period, height)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  void _paintLighthouse(Canvas canvas) {
    const x = 664.0;
    const base = IsoProjection.horizonY + 6;
    final tower = Path()
      ..moveTo(x - 9, base)
      ..lineTo(x - 5, base - 54)
      ..lineTo(x + 5, base - 54)
      ..lineTo(x + 9, base)
      ..close();
    canvas.drawPath(
      tower,
      Paint()..color = const Color(0xFFF6EFE3).withValues(alpha: 0.85),
    );
    final stripe = Paint()..color = RideColors.banner.withValues(alpha: 0.7);
    canvas.drawRect(const Rect.fromLTWH(x - 8, base - 26, 16, 7), stripe);
    canvas.drawRect(const Rect.fromLTWH(x - 7, base - 42, 14, 5), stripe);
    canvas.drawRect(
      const Rect.fromLTWH(x - 8, base - 58, 16, 4),
      Paint()..color = RideColors.hillNear,
    );
    canvas.drawRect(
      const Rect.fromLTWH(x - 4, base - 63, 8, 6),
      Paint()..color = const Color(0xFFF6EFE3),
    );
    canvas.drawCircle(
      const Offset(x, base - 60),
      3.4,
      Paint()..color = RideColors.sun,
    );
    canvas.drawPath(
      Path()
        ..moveTo(x + 4, base - 62)
        ..lineTo(x + 58, base - 74)
        ..lineTo(x + 58, base - 48)
        ..close(),
      Paint()..color = RideColors.sun.withValues(alpha: 0.12),
    );
  }

  void _paintSea(Canvas canvas) {
    const top = IsoProjection.horizonY;
    final bottom = IsoProjection.seaEdgeY;
    canvas.drawRect(
      Rect.fromLTWH(0, top, width, bottom - top),
      Paint()
        ..shader = Gradient.linear(
          const Offset(0, top),
          Offset(0, bottom),
          <Color>[
            RideColors.seaDeep,
            RideColors.sea,
            const Color(0xFF4E9AA0),
          ],
          <double>[0, 0.62, 1],
        ),
    );
    for (var i = 0; i < 4; i++) {
      final y = top + (bottom - top) * (0.22 + i * 0.19);
      canvas.drawRect(
        Rect.fromLTWH(0, y, width, 1.6),
        Paint()..color = const Color(0xFFFFFFFF).withValues(alpha: 0.06),
      );
    }
  }

  void _paintWaveGlints(Canvas canvas, double travel) {
    const top = IsoProjection.horizonY + 6;
    final bottom = IsoProjection.seaEdgeY - 6;
    const rows = 8;
    for (var row = 0; row < rows; row++) {
      final t = (row + 1) / (rows + 1);
      final y = top + (bottom - top) * t;
      final span = 9.0 + t * 22;
      final gap = 88.0 + t * 74;
      final offset =
          (travel * (0.16 + t * 0.34) + _elapsed * (4 + t * 9)) % gap;
      final paint = Paint()
        ..color = const Color(0xFFFFFFFF).withValues(alpha: 0.1 + t * 0.12)
        ..strokeWidth = 1.2 + t * 1.1
        ..strokeCap = StrokeCap.round;
      for (var i = -1; i * gap - offset < width + gap; i++) {
        final x = i * gap - offset;
        canvas.drawLine(Offset(x, y), Offset(x + span, y), paint);
      }
    }

    final reflection = Paint()
      ..color = RideColors.sun.withValues(alpha: 0.3)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    final centerX = width * 0.78;
    for (var i = 0; i < 7; i++) {
      final y = top + 6 + i * 12;
      final w = 12.0 + i * 7 + math.sin(_elapsed * 1.4 + i) * 3;
      canvas.drawLine(Offset(centerX - w / 2, y), Offset(centerX + w / 2, y), reflection);
    }
  }
}

class _CloudSeed {
  const _CloudSeed(this.x, this.y, this.scale);

  final double x;
  final double y;
  final double scale;
}
