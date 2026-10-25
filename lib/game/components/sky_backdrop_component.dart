import 'dart:math' as math;
import 'dart:ui';
import 'dart:ui' as ui;

import '../../utils/constants.dart';
import '../iso_projection.dart';
import '../ride_style.dart';
import 'scene_layer_component.dart';

/// 黄昏海岸远景：渐变天空、落日、云、远山与海面。
///
/// 每层按不同系数随骑行距离平移，形成视差滚动。天空、落日、灯塔与海面
/// 是静态画面，首次渲染时烘焙成 [Picture] 复用；海浪只更新位置与预置的
/// Paint，避免每帧重建渐变色。
class SkyBackdropComponent extends SceneLayerComponent {
  SkyBackdropComponent({required super.provider, super.priority});

  static const Color _cloud = Color(0xFFFFF4E2);
  static const Color _cloudShadeColor = Color(0xFFF3CDA6);
  static const Color _sunCore = Color(0xFFFFFFFF);
  static const Color _sunEdge = Color(0xFFFFB15C);

  static const List<_CloudSeed> _clouds = <_CloudSeed>[
    _CloudSeed(70, 92, 1.05),
    _CloudSeed(250, 66, 0.72),
    _CloudSeed(430, 104, 1.25),
    _CloudSeed(640, 74, 0.82),
    _CloudSeed(860, 96, 1.1),
    _CloudSeed(1010, 62, 0.66),
  ];

  final Paint _cloudBody = Paint()..color = _cloud.withValues(alpha: 0.8);
  final Paint _cloudShade = Paint()
    ..color = _cloudShadeColor.withValues(alpha: 0.35);
  final Paint _ridgeFar = Paint()
    ..color = RideColors.hillFar.withValues(alpha: 0.55);
  final Paint _ridgeNear = Paint()
    ..color = RideColors.hillNear.withValues(alpha: 0.72);
  final Paint _reflectionPaint = Paint()
    ..color = RideColors.sun.withValues(alpha: 0.5)
    ..strokeWidth = 2.4
    ..strokeCap = StrokeCap.round;
  final Paint _reflectionCore = Paint()
    ..color = const Color(0xFFFFFDF2).withValues(alpha: 0.55)
    ..strokeWidth = 3.4
    ..strokeCap = StrokeCap.round;

  late final List<Paint> _wavePaints = List<Paint>.generate(8, (row) {
    final t = (row + 1) / 9;
    return Paint()
      ..color = const Color(0xFFFFFFFF).withValues(alpha: 0.12 + t * 0.14)
      ..strokeWidth = 1.2 + t * 1.2
      ..strokeCap = StrokeCap.round;
  });

  /// 静态层的栅格化倍率：远景都是低频渐变，1.5 倍已足够，
  /// 换来的是每帧只做一次贴图采样，不再重复计算大面积渐变。
  static const double _rasterScale = 1.5;

  /// 天空+落日与灯塔+海面各自的世界范围。
  ///
  /// 天空裁到海面之上、海面从灯塔光束顶端开始，避免两张贴图都覆盖整幅画面；
  /// 被裁掉的部分原本也会被海面或路面盖住，视觉上没有差别。
  static const Rect _skyRegion = Rect.fromLTWH(
    0,
    0,
    AppConstants.worldWidth,
    170,
  );
  static const Rect _seaRegion = Rect.fromLTWH(
    0,
    78,
    AppConstants.worldWidth,
    AppConstants.worldHeight - 78,
  );

  Picture? _skyPicture;
  Picture? _seaPicture;
  ui.Image? _skyImage;
  ui.Image? _seaImage;
  final Paint _imagePaint = Paint()..filterQuality = FilterQuality.low;

  double _elapsed = 0;

  @override
  Future<void> onLoad() async {
    _skyPicture = _recordRegion(_skyRegion, (canvas) {
      _paintSky(canvas);
      _paintSun(canvas);
    });
    _seaPicture = _recordRegion(_seaRegion, (canvas) {
      _paintLighthouse(canvas);
      _paintSea(canvas);
    });
    _skyImage = _rasterize(_skyPicture!, _skyRegion);
    _seaImage = _rasterize(_seaPicture!, _seaRegion);
  }

  @override
  void onRemove() {
    _skyImage?.dispose();
    _seaImage?.dispose();
    _skyPicture?.dispose();
    _seaPicture?.dispose();
    _skyImage = null;
    _seaImage = null;
    _skyPicture = null;
    _seaPicture = null;
    super.onRemove();
  }

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

    _drawStaticLayer(canvas, _skyImage, _skyPicture!, _skyRegion);
    _paintClouds(canvas, travel);
    _paintRidges(canvas, travel);
    _drawStaticLayer(canvas, _seaImage, _seaPicture!, _seaRegion);
    _paintWaveGlints(canvas, travel);
  }

  /// 在 [region] 里录制静态层：先按栅格倍率放大，再平移到区域左上角。
  Picture _recordRegion(Rect region, void Function(Canvas canvas) painter) {
    final recorder = PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.scale(_rasterScale);
    canvas.translate(-region.left, -region.top);
    painter(canvas);
    return recorder.endRecording();
  }

  ui.Image? _rasterize(Picture picture, Rect region) {
    try {
      return picture.toImageSync(
        (region.width * _rasterScale).round(),
        (region.height * _rasterScale).round(),
      );
    } catch (_) {
      // Web 的 HTML 渲染器不支持 toImageSync，退回每帧绘制矢量 Picture。
      return null;
    }
  }

  void _drawStaticLayer(
    Canvas canvas,
    ui.Image? image,
    Picture picture,
    Rect region,
  ) {
    if (image != null) {
      canvas.drawImageRect(
        image,
        Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
        region,
        _imagePaint,
      );
      return;
    }
    canvas.save();
    canvas.translate(region.left, region.top);
    canvas.scale(1 / _rasterScale);
    canvas.drawPicture(picture);
    canvas.restore();
  }

  void _paintSky(Canvas canvas) {
    canvas.drawRect(
      Rect.fromLTWH(0, 0, width, IsoProjection.horizonY + 10),
      Paint()
        ..shader = Gradient.linear(
          Offset.zero,
          const Offset(0, IsoProjection.horizonY + 10),
          <Color>[
            RideColors.skyTop,
            RideColors.skyMid,
            RideColors.skyLow,
            const Color(0xFFFFE9C4),
          ],
          <double>[0, 0.52, 0.82, 1],
        ),
    );
    // 落日附近整体烘一层暖光，让夕阳的亮度压过天空。
    final sunCenter = Offset(width * 0.78, IsoProjection.horizonY - 14);
    canvas.drawCircle(
      sunCenter,
      380,
      Paint()
        ..shader = Gradient.radial(
          sunCenter,
          380,
          <Color>[
            RideColors.sun.withValues(alpha: 0.34),
            RideColors.skyMid.withValues(alpha: 0.16),
            RideColors.skyMid.withValues(alpha: 0),
          ],
          <double>[0, 0.35, 1],
        ),
    );
    canvas.drawRect(
      Rect.fromLTWH(0, IsoProjection.horizonY - 30, width, 30),
      Paint()
        ..shader = Gradient.linear(
          const Offset(0, IsoProjection.horizonY - 30),
          const Offset(0, IsoProjection.horizonY),
          <Color>[
            RideColors.skyLow.withValues(alpha: 0),
            RideColors.sun.withValues(alpha: 0.42),
          ],
        ),
    );
  }

  void _paintSun(Canvas canvas) {
    final center = Offset(width * 0.78, IsoProjection.horizonY - 14);

    canvas.drawCircle(
      center,
      250,
      Paint()
        ..shader = Gradient.radial(
          center,
          250,
          <Color>[
            RideColors.sun.withValues(alpha: 0.62),
            RideColors.sun.withValues(alpha: 0.24),
            RideColors.sun.withValues(alpha: 0),
          ],
          <double>[0, 0.38, 1],
        ),
    );

    // 放射状阳光，烘焙一次，避免每帧算渐变。
    // 画布在下面会平移到太阳中心，因此渐变用局部坐标定义。
    final rayPaint = Paint()
      ..shader = Gradient.linear(
        Offset.zero,
        const Offset(0, -330),
        <Color>[
          RideColors.sun.withValues(alpha: 0.2),
          RideColors.sun.withValues(alpha: 0),
        ],
      );
    for (var i = 0; i < 12; i++) {
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(i * math.pi / 6 + 0.12);
      canvas.drawPath(
        Path()
          ..moveTo(-7, 0)
          ..lineTo(-30, -330)
          ..lineTo(30, -330)
          ..lineTo(7, 0)
          ..close(),
        rayPaint,
      );
      canvas.restore();
    }

    canvas.drawCircle(
      center,
      104,
      Paint()
        ..shader = Gradient.radial(
          center,
          104,
          <Color>[
            RideColors.sun.withValues(alpha: 0.6),
            RideColors.sun.withValues(alpha: 0.12),
            RideColors.sun.withValues(alpha: 0),
          ],
          <double>[0, 0.4, 1],
        ),
    );

    canvas.drawCircle(
      center,
      50,
      Paint()
        ..shader = Gradient.radial(
          center,
          50,
          <Color>[
            _sunCore,
            const Color(0xFFFFF6C8),
            RideColors.sun,
            _sunEdge,
          ],
          <double>[0, 0.32, 0.72, 1],
        ),
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
        _cloudBody,
      );
    }
    canvas.drawOval(
      Rect.fromCenter(
        center: center + Offset(2 * scale, 10 * scale),
        width: 96 * scale,
        height: 16 * scale,
      ),
      _cloudShade,
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
      paint: _ridgeFar,
    );
    _paintRidge(
      canvas,
      travel: travel,
      speed: 0.28,
      baseY: IsoProjection.horizonY + 8,
      period: 214,
      peak: 36,
      phase: 3.4,
      paint: _ridgeNear,
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
    required Paint paint,
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
    canvas.drawPath(path, paint);
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
    // 太阳落在海面的一条亮带
    canvas.drawRect(
      Rect.fromLTWH(0, top, width, 10),
      Paint()
        ..shader = Gradient.linear(
          const Offset(0, top),
          const Offset(0, top + 10),
          <Color>[
            RideColors.sun.withValues(alpha: 0.35),
            RideColors.sun.withValues(alpha: 0),
          ],
        ),
    );
  }

  void _paintWaveGlints(Canvas canvas, double travel) {
    const top = IsoProjection.horizonY + 6;
    final bottom = IsoProjection.seaEdgeY - 6;
    const rows = 8;
    for (var row = 0; row < rows; ++row) {
      final t = (row + 1) / (rows + 1);
      final y = top + (bottom - top) * t;
      final span = 9.0 + t * 24;
      final gap = 84.0 + t * 72;
      final offset =
          (travel * (0.16 + t * 0.34) + _elapsed * (4 + t * 9)) % gap;
      final paint = _wavePaints[row];
      for (var i = -1; i * gap - offset < width + gap; i++) {
        final x = i * gap - offset;
        canvas.drawLine(Offset(x, y), Offset(x + span, y), paint);
      }
    }

    final centerX = width * 0.78;
    for (var i = 0; i < 9; i++) {
      final y = top + 4 + i * 11;
      final w = 16.0 + i * 9 + math.sin(_elapsed * 1.4 + i) * 4;
      canvas.drawLine(
        Offset(centerX - w / 2, y),
        Offset(centerX + w / 2, y),
        _reflectionPaint,
      );
    }
    canvas.drawLine(
      Offset(centerX - 30, bottom - 6),
      Offset(centerX + 30, bottom - 6),
      _reflectionCore,
    );
  }
}

class _CloudSeed {
  const _CloudSeed(this.x, this.y, this.scale);

  final double x;
  final double y;
  final double scale;
}
