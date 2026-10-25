import 'dart:ui';

import '../../utils/constants.dart';
import '../iso_projection.dart';
import '../rendering/scenery_sprites.dart';
import '../ride_style.dart';
import 'scene_layer_component.dart';

/// 等距路面：单向单车道沥青带、沙石路肩、海岸沙带与沿路植被。
///
/// 静态路面（路肩、沥青、沙带、边线）首次渲染时烘焙成一张 [Picture]；
/// 泡沫、横向接缝与行车箭头各自烘焙成一条可平铺的 [Picture]，每帧只做一次
/// 平移绘制，不再逐条构造 [Path]；草丛、碎石与椰树来自 [ScenerySprites]
/// 的位图精灵，只有整块移出可见区才停止绘制。
class RoadComponent extends SceneLayerComponent {
  RoadComponent({required super.provider, super.priority});

  static const double _xNear = -70;
  static const double _xFar = 70;
  static const double _arrowPeriod = 15;

  /// 泡沫与接缝平铺条带的宽度：画幅宽度再留一个周期，平移后不会露出缝隙。
  static const double _foamSpan = AppConstants.worldWidth + 50;
  static const double _seamSpan = AppConstants.worldWidth + 280;

  final Paint _foamPaint = Paint()
    ..color = const Color(0xFFFFFFFF).withValues(alpha: 0.4);
  final Paint _seamPaint = Paint()
    ..color = const Color(0xFF000000).withValues(alpha: 0.14);
  final Paint _arrowPaint = Paint()
    ..color = RideColors.roadLine.withValues(alpha: 0.38);

  Picture? _staticPicture;
  Picture? _arrowPicture;
  Picture? _foamPicture;
  Picture? _seamPicture;

  @override
  void onRemove() {
    _staticPicture?.dispose();
    _arrowPicture?.dispose();
    _foamPicture?.dispose();
    _seamPicture?.dispose();
    _staticPicture = null;
    _arrowPicture = null;
    _foamPicture = null;
    _seamPicture = null;
    super.onRemove();
  }

  @override
  void render(Canvas canvas) {
    _ensureStatic();
    final state = provider.state;
    final travel = IsoProjection.travelPixels(state.distance);
    final unitScroll = travel / IsoProjection.pxPerUnit;

    canvas.drawPicture(_staticPicture!);

    final foamShift = (unitScroll * 0.9) % 5.0 * IsoProjection.pxPerUnit;
    _drawStrip(canvas, _foamPicture!, -foamShift);

    final arrowShift = (unitScroll % _arrowPeriod) * IsoProjection.pxPerUnit;
    _drawStrip(canvas, _arrowPicture!, -arrowShift);

    final seamShift = (unitScroll % 28.0) * IsoProjection.pxPerUnit;
    _drawStrip(canvas, _seamPicture!, -seamShift);

    _paintShoreProps(canvas, unitScroll);
  }

  void _drawStrip(Canvas canvas, Picture picture, double shift) {
    canvas.save();
    canvas.translate(shift, 0);
    canvas.drawPicture(picture);
    canvas.restore();
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
    _foamPicture = _record(_paintFoamStrip);
    _seamPicture = _record(_paintSeamStrip);
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

  /// 一条 50 像素宽的海水泡沫，从 [screenX] 开始。
  ///
  /// 直接按屏幕坐标构造，避免平铺烘焙时反复调用投影。
  Path _foamPathAt(double screenX) {
    final midX =
        screenX + 2.4 * IsoProjection.pxPerUnit + 0.16 * IsoProjection.depthSlantX;
    final endX = screenX + 5.0 * IsoProjection.pxPerUnit;
    final y = IsoProjection.seaEdgeY;
    return Path()
      ..moveTo(screenX, y)
      ..quadraticBezierTo(midX, y - 2.2, endX, y)
      ..lineTo(endX, y + 2.4)
      ..lineTo(screenX, y + 2.4)
      ..close();
  }

  void _paintFoamStrip(Canvas canvas) {
    for (var x = 0.0; x <= _foamSpan; x += 50) {
      canvas.drawPath(_foamPathAt(x), _foamPaint);
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
    for (var x = 0.0; x <= _foamSpan; x += _arrowPeriod * IsoProjection.pxPerUnit) {
      canvas.drawPath(_arrowPathAt(x), _arrowPaint);
    }
  }

  Path _arrowPathAt(double screenX) {
    Offset point(double dx, double z) => Offset(
      screenX + dx * IsoProjection.pxPerUnit + z * IsoProjection.depthSlantX,
      AppConstants.groundY - z * IsoProjection.depthSlantY,
    );
    return Path()
      ..addPolygon(<Offset>[
        point(0, -0.34),
        point(2.0, -0.34),
        point(2.0, -1.15),
        point(3.8, 0),
        point(2.0, 1.15),
        point(2.0, 0.34),
        point(0, 0.34),
      ], true);
  }

  /// 一条横跨车道的接缝，从屏幕坐标 [screenX] 开始。
  Path _seamPathAt(double screenX) {
    Offset point(double dx, double z) => Offset(
      screenX + dx * IsoProjection.pxPerUnit + z * IsoProjection.depthSlantX,
      AppConstants.groundY - z * IsoProjection.depthSlantY,
    );
    return Path()
      ..addPolygon(<Offset>[
        point(0, -IsoProjection.laneHalfZ),
        point(0.16, -IsoProjection.laneHalfZ),
        point(0.16, IsoProjection.laneHalfZ),
        point(0, IsoProjection.laneHalfZ),
      ], true);
  }

  void _paintSeamStrip(Canvas canvas) {
    for (var x = 0.0; x <= _seamSpan; x += 280) {
      canvas.drawPath(_seamPathAt(x), _seamPaint);
    }
  }

  /// 沿路装饰需要遍历的 index 区间。
  ///
  /// 世界 x = index * gap - unitScroll + offset；区间由当前可见的世界范围反算，
  /// 前后各多留一格，保证精灵在完全进入画面前就已准备好，
  /// 而是否真正绘制仍由 [isVisibleAt] 决定。
  (int, int) _tileRange({
    required double gap,
    required double unitScroll,
    required double z,
    required double halfWidthPx,
    double offset = 0,
  }) {
    final (left, right) = visibleWorldXRange(z);
    final margin = halfWidthPx / IsoProjection.pxPerUnit;
    return (
      (((left - margin) + unitScroll - offset) / gap).floor() - 1,
      (((right + margin) + unitScroll - offset) / gap).ceil() + 1,
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
      if (!isVisibleAt(base, height * 0.31 + 2)) {
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
      if (!isVisibleAt(base, size / 2 + 2)) continue;
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
      if (!isVisibleAt(
        base,
        ScenerySprites.palmSize.width * scale / 2 + 4,
      )) {
        continue;
      }
      ScenerySprites.drawPalm(canvas, base, scale: scale, variant: index);
    }
  }
}
