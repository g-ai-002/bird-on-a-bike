import 'dart:math' as math;
import 'dart:ui';

import '../../utils/constants.dart';
import '../iso_projection.dart';
import '../painting/prop_art.dart';
import '../ride_style.dart';
import 'scene_layer_component.dart';

/// 等距路面：沥青带、海岸沙带、车道线与沿路植被。
///
/// 路面沿世界 x 方向延伸、沿 z 方向斜向抬升；虚线、横向接缝与
/// 沙带上的草丛都按骑行距离滚动，构成地图的主滚动层。
class RoadComponent extends SceneLayerComponent {
  RoadComponent({required super.provider, super.priority});

  static const double _xNear = -70;
  static const double _xFar = 70;
  static const double _edgeLineZ = 6.2;
  static const double _laneZ = 2.6;

  @override
  void render(Canvas canvas) {
    final state = provider.state;
    final travel = IsoProjection.travelPixels(state.distance);
    final unitScroll = travel / IsoProjection.pxPerUnit;

    _paintSurf(canvas);
    _paintFarShore(canvas, unitScroll);
    _paintNearShore(canvas);
    _paintEdgeLines(canvas);
    _paintLaneDashes(canvas, unitScroll);
    _paintCrossSeams(canvas, unitScroll);
    _paintShoreProps(canvas, unitScroll);
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

  void _paintFarShore(Canvas canvas, double unitScroll) {
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

    // 海水拍岸的白沫，随距离缓慢流动
    final foamShift = (unitScroll * 0.9) % 5.0;
    final foam = Paint()..color = const Color(0xFFFFFFFF).withValues(alpha: 0.4);
    for (var i = -14; i <= 14; i++) {
      final x = i * 5.0 - foamShift;
      final path = Path()
        ..moveTo(IsoProjection.project(x, 0, seaZ).dx, IsoProjection.seaEdgeY)
        ..quadraticBezierTo(
          IsoProjection.project(x + 2.4, 0, seaZ + 0.16).dx,
          IsoProjection.seaEdgeY - 2.2,
          IsoProjection.project(x + 5.0, 0, seaZ).dx,
          IsoProjection.seaEdgeY,
        )
        ..lineTo(IsoProjection.project(x + 5.0, 0, seaZ).dx, IsoProjection.seaEdgeY + 2.4)
        ..lineTo(IsoProjection.project(x, 0, seaZ).dx, IsoProjection.seaEdgeY + 2.4)
        ..close();
      canvas.drawPath(path, foam);
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

  void _paintLaneDashes(Canvas canvas, double unitScroll) {
    const dash = 3.4;
    const period = dash * 2;
    final offset = unitScroll % period;
    final paint = Paint()..color = RideColors.roadLine.withValues(alpha: 0.8);
    for (final z in <double>[-_laneZ, _laneZ]) {
      for (var i = -9; i <= 9; i++) {
        final x = i * period - offset;
        canvas.drawPath(_quad(x, x + dash, z - 0.14, z + 0.14), paint);
      }
    }
  }

  void _paintCrossSeams(Canvas canvas, double unitScroll) {
    const period = 28.0;
    final offset = unitScroll % period;
    final paint = Paint()..color = const Color(0xFF000000).withValues(alpha: 0.14);
    for (var i = -3; i <= 4; i++) {
      final x = i * period - offset;
      canvas.drawPath(
        _quad(
          x,
          x + 0.16,
          IsoProjection.roadNearZ,
          IsoProjection.roadFarZ,
        ),
        paint,
      );
    }
  }

  void _paintShoreProps(Canvas canvas, double unitScroll) {
    // 沙带上的草丛，按固定节距铺满可见范围
    const grassGap = 3.1;
    final grassTile = (unitScroll / grassGap).floor();
    for (var i = -2; i <= AppConstants.worldWidth / (grassGap * 10) + 3; i++) {
      final index = grassTile + i;
      final worldX = index * grassGap - unitScroll;
      if (worldX < -44 || worldX > 44) continue;
      final z = 7.9 + (index % 3) * 0.35;
      final base = IsoProjection.project(worldX, 0, z);
      final height = 12.0 + (index % 4) * 3.5;
      final widthPx = height * 0.62;
      canvas.save();
      canvas.translate(base.dx, base.dy);
      PropArt.paintGrassTuft(
        canvas,
        Size(widthPx, height),
        color: index.isEven
            ? const Color(0xFF5F8A4E)
            : const Color(0xFF7A9A5A),
      );
      canvas.restore();
    }

    // 零星碎石
    const stoneGap = 9.7;
    final stoneTile = (unitScroll / stoneGap).floor();
    for (var i = -1; i <= 10; i++) {
      final index = stoneTile + i;
      final worldX = index * stoneGap - unitScroll;
      if (worldX < -44 || worldX > 44) continue;
      final base = IsoProjection.project(worldX, 0, 8.15 + (index % 2) * 0.4);
      final size = 9.0 + (index % 3) * 3.5;
      canvas.save();
      canvas.translate(base.dx, base.dy);
      canvas.scale(1, 0.72);
      PropArt.paintStone(
        canvas,
        Size(size, size),
        light: index % 3 == 0,
      );
      canvas.restore();
    }

    // 木麻黄：远景椰树，同样随路面滚动
    const palmGap = 37.0;
    final palmTile = (unitScroll / palmGap).floor();
    for (var i = -1; i <= 3; i++) {
      final index = palmTile + i;
      final worldX = index * palmGap - unitScroll + 6;
      if (worldX < -46 || worldX > 48) continue;
      final base = IsoProjection.project(worldX, 0, 8.6);
      _paintPalm(canvas, base, index.isEven ? 1.0 : 0.82, index);
    }
  }

  void _paintPalm(Canvas canvas, Offset base, double scale, int index) {
    final lean = (index.isEven ? 1.0 : -1.0) * 5.0 * scale;
    final top = base + Offset(lean, -58 * scale);

    final trunk = Path()
      ..moveTo(base.dx - 2.8 * scale, base.dy)
      ..quadraticBezierTo(
        base.dx + lean * 0.2,
        base.dy - 32 * scale,
        top.dx - 1.5 * scale,
        top.dy,
      )
      ..lineTo(top.dx + 1.5 * scale, top.dy)
      ..quadraticBezierTo(
        base.dx + lean * 0.2 + 2.4 * scale,
        base.dy - 32 * scale,
        base.dx + 2.8 * scale,
        base.dy,
      )
      ..close();
    canvas.drawPath(trunk, Paint()..color = const Color(0xFF7A5230));

    final leafColors = <Color>[
      const Color(0xFF4F7A4E),
      const Color(0xFF3E6642),
      const Color(0xFF5E8A56),
    ];
    for (var i = 0; i < 7; i++) {
      final angle = -math.pi / 2 + (i - 3) * 0.38;
      final length = (24 + (i % 3) * 6) * scale;
      final tip = top +
          Offset(math.cos(angle) * length, math.sin(angle) * length * 0.5 + 6);
      final frond = Path()
        ..moveTo(top.dx, top.dy)
        ..quadraticBezierTo(
          top.dx + math.cos(angle) * length * 0.5,
          top.dy + math.sin(angle) * length * 0.2 - 7 * scale,
          tip.dx,
          tip.dy,
        );
      canvas.drawPath(
        frond,
        Paint()
          ..color = leafColors[i % leafColors.length]
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.2 * scale
          ..strokeCap = StrokeCap.round,
      );
      canvas.drawLine(
        Offset(tip.dx, tip.dy),
        Offset(tip.dx - 2 * scale, tip.dy + 4 * scale),
        Paint()
          ..color = leafColors[(i + 1) % leafColors.length]
          ..strokeWidth = 1.8 * scale
          ..strokeCap = StrokeCap.round,
      );
    }
    canvas.drawCircle(
      top,
      3.4 * scale,
      Paint()..color = const Color(0xFF3E6642),
    );
  }
}
