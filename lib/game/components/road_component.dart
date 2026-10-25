import 'dart:ui';

import '../../utils/constants.dart';
import '../iso_projection.dart';
import '../rendering/scenery_sprites.dart';
import '../ride_style.dart';
import 'scene_layer_component.dart';

/// 等距路面：沥青带、海岸沙带、车道线与沿路植被。
///
/// 静态路面（沥青、沙带、边线）首次渲染时烘焙成一张 [Picture]；
/// 虚线单独烘焙并按骑行距离平移；草丛、碎石与椰树来自 [ScenerySprites]
/// 的缓存精灵，滚动时不再重复构建 Path。
class RoadComponent extends SceneLayerComponent {
  RoadComponent({required super.provider, super.priority});

  static const double _xNear = -70;
  static const double _xFar = 70;
  static const double _edgeLineZ = 6.2;
  static const double _laneZ = 2.6;
  static const double _dashLength = 3.4;
  static const double _dashPeriod = _dashLength * 2;

  final Paint _foamPaint = Paint()
    ..color = const Color(0xFFFFFFFF).withValues(alpha: 0.4);
  final Paint _seamPaint = Paint()
    ..color = const Color(0xFF000000).withValues(alpha: 0.14);
  final Paint _dashPaint = Paint()
    ..color = RideColors.roadLine.withValues(alpha: 0.8);

  Picture? _staticPicture;
  Picture? _dashPicture;

  @override
  void render(Canvas canvas) {
    _ensureStatic();
    final state = provider.state;
    final travel = IsoProjection.travelPixels(state.distance);
    final unitScroll = travel / IsoProjection.pxPerUnit;

    canvas.drawPicture(_staticPicture!);
    _paintFoam(canvas, unitScroll);

    final dashShift = (unitScroll % _dashPeriod) * IsoProjection.pxPerUnit;
    canvas.save();
    canvas.translate(-dashShift, 0);
    canvas.drawPicture(_dashPicture!);
    canvas.restore();

    _paintCrossSeams(canvas, unitScroll);
    _paintShoreProps(canvas, unitScroll);
  }

  void _ensureStatic() {
    if (_staticPicture != null) return;
    _staticPicture = _record((canvas) {
      _paintSurf(canvas);
      _paintFarShore(canvas);
      _paintNearShore(canvas);
      _paintEdgeLines(canvas);
    });
    _dashPicture = _record(_paintLaneDashes);
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

  void _paintSurf(Canvas canvas) {
    final far = IsoProjection.roadFarY;
    final near = IsoProjection.roadNearY;
    canvas.drawPath(
      _quad(_xNear, _xFar, IsoProjection.roadNearZ, IsoProjection.roadFarZ),
      Paint()
        ..shader = Gradient.linear(
          Offset(0, far),
          Offset(0, near),
          <Color>[
            const Color(0xFF333333),
            const Color(0xFF414141),
            const Color(0xFF4A4A46),
          ],
          <double>[0, 0.55, 1],
        ),
    );
    canvas.drawPath(
      _quad(_xNear, _xFar, -0.9, 0.9),
      Paint()..color = const Color(0xFFFFFFFF).withValues(alpha: 0.022),
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
    for (final z in <double>[-_edgeLineZ, _edgeLineZ]) {
      canvas.drawPath(_quad(_xNear, _xFar, z - 0.11, z + 0.11), paint);
    }
  }

  void _paintLaneDashes(Canvas canvas) {
    for (final z in <double>[-_laneZ, _laneZ]) {
      for (var i = -12; i <= 12; i++) {
        final x = i * _dashPeriod;
        canvas.drawPath(
          _quad(x, x + _dashLength, z - 0.14, z + 0.14),
          _dashPaint,
        );
      }
    }
  }

  void _paintCrossSeams(Canvas canvas, double unitScroll) {
    const period = 28.0;
    final offset = unitScroll % period;
    for (var i = -3; i <= 4; i++) {
      final x = i * period - offset;
      canvas.drawPath(
        _quad(x, x + 0.16, IsoProjection.roadNearZ, IsoProjection.roadFarZ),
        _seamPaint,
      );
    }
  }

  void _paintShoreProps(Canvas canvas, double unitScroll) {
    const grassGap = 3.1;
    final grassTile = (unitScroll / grassGap).floor();
    const grassCount = AppConstants.worldWidth / (grassGap * 10) + 3;
    for (var i = -2; i <= grassCount; i++) {
      final index = grassTile + i;
      final worldX = index * grassGap - unitScroll;
      if (worldX < -44 || worldX > 44) continue;
      final z = 7.9 + (index % 3) * 0.35;
      final base = IsoProjection.project(worldX, 0, z);
      final height = 12.0 + (index % 4) * 3.5;
      ScenerySprites.drawGrass(
        canvas,
        base,
        Size(height * 0.62, height),
        index.isEven ? const Color(0xFF5F8A4E) : const Color(0xFF7A9A5A),
      );
    }

    const stoneGap = 9.7;
    final stoneTile = (unitScroll / stoneGap).floor();
    for (var i = -1; i <= 10; i++) {
      final index = stoneTile + i;
      final worldX = index * stoneGap - unitScroll;
      if (worldX < -44 || worldX > 44) continue;
      final base = IsoProjection.project(worldX, 0, 8.15 + (index % 2) * 0.4);
      final size = 9.0 + (index % 3) * 3.5;
      ScenerySprites.drawStone(
        canvas,
        base,
        Size(size, size * 0.72),
        light: index % 3 == 0,
      );
    }

    const palmGap = 37.0;
    final palmTile = (unitScroll / palmGap).floor();
    for (var i = -1; i <= 3; i++) {
      final index = palmTile + i;
      final worldX = index * palmGap - unitScroll + 6;
      if (worldX < -46 || worldX > 48) continue;
      final base = IsoProjection.project(worldX, 0, 8.6);
      ScenerySprites.palm(
        index,
      ).render(canvas, base, scale: index.isEven ? 1.0 : 0.82);
    }
  }
}
