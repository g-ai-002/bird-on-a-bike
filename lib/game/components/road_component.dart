import 'dart:ui';

import '../../utils/constants.dart';
import '../iso_projection.dart';
import '../rendering/scenery_sprites.dart';
import '../ride_style.dart';
import 'scene_layer_component.dart';

/// 等距路面：单向单车道沥青带、沙石路肩、海岸沙带与沿路植被。
///
/// 静态路面（路肩、沥青、沙带、边线）首次渲染时烘焙成一张 [Picture]；
/// 行车箭头单独烘焙并按骑行距离平移；草丛、碎石与椰树来自
/// [ScenerySprites] 的缓存精灵，只有整块移出画布才停止绘制。
class RoadComponent extends SceneLayerComponent {
  RoadComponent({required super.provider, super.priority});

  static const double _xNear = -70;
  static const double _xFar = 70;
  static const double _arrowPeriod = 15;

  final Paint _foamPaint = Paint()
    ..color = const Color(0xFFFFFFFF).withValues(alpha: 0.4);
  final Paint _seamPaint = Paint()
    ..color = const Color(0xFF000000).withValues(alpha: 0.14);
  final Paint _arrowPaint = Paint()
    ..color = RideColors.roadLine.withValues(alpha: 0.38);

  Picture? _staticPicture;
  Picture? _arrowPicture;

  @override
  void render(Canvas canvas) {
    _ensureStatic();
    final state = provider.state;
    final travel = IsoProjection.travelPixels(state.distance);
    final unitScroll = travel / IsoProjection.pxPerUnit;

    canvas.drawPicture(_staticPicture!);
    _paintFoam(canvas, unitScroll);

    final arrowShift = (unitScroll % _arrowPeriod) * IsoProjection.pxPerUnit;
    canvas.save();
    canvas.translate(-arrowShift, 0);
    canvas.drawPicture(_arrowPicture!);
    canvas.restore();

    _paintCrossSeams(canvas, unitScroll);
    _paintShoreProps(canvas, unitScroll);
  }

  void _ensureStatic() {
    if (_staticPicture != null) return;
    _staticPicture = _record((canvas) {
      _paintShoulders(canvas);
      _paintSurf(canvas);
      _paintFarShore(canvas);
      _paintNearShore(canvas);
      _paintEdgeLines(canvas);
    });
    _arrowPicture = _record(_paintLaneArrows);
  }

  Picture _record(void Function(Canvas canvas) painter) {
    final recorder = PictureRecorder();
    final canvas = Canvas(recorder);
    painter(canvas);
    return recorder.endRecording();
  }

  Path _quad(double x0, double x1, double z0, double z1) {
    final a = IsoProjection.project(x0, 0, z0);
    final b = IsoProjection.project(x1, 0, z0);
    final c = IsoProjection.project(x1, 0, z1);
    final d = IsoProjection.project(x0, 0, z1);
    return Path()
      ..moveTo(a.dx, a.dy)
      ..lineTo(b.dx, b.dy)
      ..lineTo(c.dx, c.dy)
      ..lineTo(d.dx, d.dy)
      ..close();
  }

  void _paintShoulders(Canvas canvas) {
    final paint = Paint()
      ..shader = Gradient.linear(
        Offset(0, IsoProjection.roadFarY),
        Offset(0, IsoProjection.roadNearY),
        <Color>[
          const Color(0xFF7C6748),
          const Color(0xFF6A5439),
          const Color(0xFF57432C),
        ],
        <double>[0, 0.55, 1],
      );
    canvas.drawPath(
      _quad(
        _xNear,
        _xFar,
        IsoProjection.laneHalfZ,
        IsoProjection.roadFarZ,
      ),
      paint,
    );
    canvas.drawPath(
      _quad(
        _xNear,
        _xFar,
        IsoProjection.roadNearZ,
        -IsoProjection.laneHalfZ,
      ),
      paint,
    );
  }

  void _paintSurf(Canvas canvas) {
    final far = IsoProjection.roadFarY;
    final near = IsoProjection.roadNearY;
    canvas.drawPath(
      _quad(
        _xNear,
        _xFar,
        -IsoProjection.laneHalfZ,
        IsoProjection.laneHalfZ,
      ),
      Paint()
        ..shader = Gradient.linear(
          Offset(0, far),
          Offset(0, near),
          <Color>[
            const Color(0xFF3A3A38),
            const Color(0xFF4A4A46),
            const Color(0xFF55554F),
          ],
          <double>[0, 0.55, 1],
        ),
    );
    canvas.drawPath(
      _quad(_xNear, _xFar, -0.9, 0.9),
      Paint()..color = const Color(0xFFFFFFFF).withValues(alpha: 0.03),
    );
  }

  void _paintFarShore(Canvas canvas) {
    const farZ = IsoProjection.roadFarZ;
    const seaZ = IsoProjection.seaEdgeZ;
    canvas.drawPath(
      _quad(_xNear, _xFar, farZ, seaZ),
      Paint()
        ..shader = Gradient.linear(
          Offset(0, IsoProjection.seaEdgeY),
          Offset(0, IsoProjection.roadFarY),
          <Color>[const Color(0xFFC79A6A), const Color(0xFFB08050)],
        ),
    );
  }

  void _paintFoam(Canvas canvas, double unitScroll) {
    const seaZ = IsoProjection.seaEdgeZ;
    final foamShift = (unitScroll * 0.9) % 5.0;
    for (var i = -14; i <= 14; i++) {
      final x = i * 5.0 - foamShift;
      final start = IsoProjection.project(x, 0, seaZ).dx;
      final mid = IsoProjection.project(x + 2.4, 0, seaZ + 0.16).dx;
      final end = IsoProjection.project(x + 5.0, 0, seaZ).dx;
      final path = Path()
        ..moveTo(start, IsoProjection.seaEdgeY)
        ..quadraticBezierTo(mid, IsoProjection.seaEdgeY - 2.2, end,
            IsoProjection.seaEdgeY)
        ..lineTo(end, IsoProjection.seaEdgeY + 2.4)
        ..lineTo(start, IsoProjection.seaEdgeY + 2.4)
        ..close();
      canvas.drawPath(path, _foamPaint);
    }
  }

  void _paintNearShore(Canvas canvas) {
    canvas.drawPath(
      _quad(
        _xNear,
        _xFar,
        IsoProjection.roadNearZ - 1.6,
        IsoProjection.roadNearZ,
      ),
      Paint()
        ..shader = Gradient.linear(
          Offset(0, IsoProjection.roadNearY),
          Offset(0, IsoProjection.roadNearY + 26),
          <Color>[const Color(0xFF6B4A2E), const Color(0xFF4B3420)],
        ),
    );
  }

  void _paintEdgeLines(Canvas canvas) {
    final paint = Paint()..color = RideColors.roadLine.withValues(alpha: 0.55);
    for (final z in <double>[
      -IsoProjection.laneEdgeZ,
      IsoProjection.laneEdgeZ,
    ]) {
      canvas.drawPath(_quad(_xNear, _xFar, z - 0.11, z + 0.11), paint);
    }
  }

  /// 单行道的地面箭头，指向骑行前进方向（画面右侧）。
  void _paintLaneArrows(Canvas canvas) {
    for (var i = -14; i <= 14; i++) {
      canvas.drawPath(_arrowPath(i * _arrowPeriod), _arrowPaint);
    }
  }

  Path _arrowPath(double x) {
    final tail = x;
    final neck = x + 2.0;
    final tip = x + 3.8;
    return Path()
      ..addPolygon(<Offset>[
        IsoProjection.project(tail, 0, -0.34),
        IsoProjection.project(neck, 0, -0.34),
        IsoProjection.project(neck, 0, -1.15),
        IsoProjection.project(tip, 0, 0),
        IsoProjection.project(neck, 0, 1.15),
        IsoProjection.project(neck, 0, 0.34),
        IsoProjection.project(tail, 0, 0.34),
      ], true);
  }

  void _paintCrossSeams(Canvas canvas, double unitScroll) {
    const period = 28.0;
    final offset = unitScroll % period;
    for (var i = -3; i <= 4; i++) {
      final x = i * period - offset;
      canvas.drawPath(
        _quad(
          x,
          x + 0.16,
          -IsoProjection.laneHalfZ,
          IsoProjection.laneHalfZ,
        ),
        _seamPaint,
      );
    }
  }

  /// 沿路装饰需要遍历的 index 区间。
  ///
  /// 世界 x = index * gap - unitScroll + offset；区间由画布左右边界反算，
  /// 前后各多留一格，保证精灵在完全进入画面前就已准备好，
  /// 而是否真正绘制仍由 [IsoProjection.isGroundSpriteVisible] 决定。
  (int, int) _tileRange({
    required double gap,
    required double unitScroll,
    required double z,
    required double halfWidthPx,
    double offset = 0,
  }) {
    final left = IsoProjection.worldXAtScreenX(-halfWidthPx, z);
    final right = IsoProjection.worldXAtScreenX(
      AppConstants.worldWidth + halfWidthPx,
      z,
    );
    return (
      ((left + unitScroll - offset) / gap).floor() - 1,
      ((right + unitScroll - offset) / gap).ceil() + 1,
    );
  }

  void _paintShoreProps(Canvas canvas, double unitScroll) {
    const grassGap = 3.1;
    final (grassFirst, grassLast) = _tileRange(
      gap: grassGap,
      unitScroll: unitScroll,
      z: 8.6,
      halfWidthPx: 12,
    );
    for (var index = grassFirst; index <= grassLast; index++) {
      final worldX = index * grassGap - unitScroll;
      final z = 7.9 + (index % 3) * 0.35;
      final height = 12.0 + (index % 4) * 3.5;
      final base = IsoProjection.project(worldX, 0, z);
      if (!IsoProjection.isGroundSpriteVisible(base, height * 0.31 + 2)) {
        continue;
      }
      ScenerySprites.drawGrass(
        canvas,
        base,
        Size(height * 0.62, height),
        index.isEven ? const Color(0xFF5F8A4E) : const Color(0xFF7A9A5A),
      );
    }

    const stoneGap = 9.7;
    final (stoneFirst, stoneLast) = _tileRange(
      gap: stoneGap,
      unitScroll: unitScroll,
      z: 8.55,
      halfWidthPx: 11,
    );
    for (var index = stoneFirst; index <= stoneLast; index++) {
      final worldX = index * stoneGap - unitScroll;
      final base = IsoProjection.project(worldX, 0, 8.15 + (index % 2) * 0.4);
      final size = 9.0 + (index % 3) * 3.5;
      if (!IsoProjection.isGroundSpriteVisible(base, size / 2 + 2)) continue;
      ScenerySprites.drawStone(
        canvas,
        base,
        Size(size, size * 0.72),
        light: index % 3 == 0,
      );
    }

    const palmGap = 37.0;
    const palmOffset = 6.0;
    final (palmFirst, palmLast) = _tileRange(
      gap: palmGap,
      unitScroll: unitScroll,
      z: 8.6,
      halfWidthPx: ScenerySprites.palmSize.width / 2 + 6,
      offset: palmOffset,
    );
    for (var index = palmFirst; index <= palmLast; index++) {
      final worldX = index * palmGap - unitScroll + palmOffset;
      final scale = index.isEven ? 1.0 : 0.82;
      final base = IsoProjection.project(worldX, 0, 8.6);
      if (!IsoProjection.isGroundSpriteVisible(
        base,
        ScenerySprites.palmSize.width * scale / 2 + 4,
      )) {
        continue;
      }
      ScenerySprites.palm(index).render(canvas, base, scale: scale);
    }
  }
}
