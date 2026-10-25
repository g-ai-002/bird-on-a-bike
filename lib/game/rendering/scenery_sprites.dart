import 'dart:math' as math;
import 'dart:ui';
import 'dart:ui' as ui;

import '../painting/prop_art.dart';
import 'baked_sprite.dart';

/// 沿路植被与碎石的缓存精灵。
///
/// 草丛、碎石与椰树每帧会出现几十次，且缩放各不相同。矢量 Picture 在每次
/// 不同缩放比下都要重新光栅化，因此这里在首次使用时按 [_bakeScale] 倍烘焙成
/// 位图，之后每帧只做一次贴图采样。Web 的 HTML 渲染器不支持 `toImageSync` 时
/// 退回矢量 Picture，保持与之前一致的画法。
class ScenerySprites {
  ScenerySprites._();

  static const Size grassBaseSize = Size(20, 28);
  static const Size stoneBaseSize = Size(24, 24);
  static const Size palmSize = Size(140, 84);

  /// 位图烘焙倍率：1080p 下植被放大后仍接近 1:1 采样。
  static const double _bakeScale = 3;

  static final Map<int, _Sprite> _grass = <int, _Sprite>{};
  static final Map<int, _Sprite> _stones = <int, _Sprite>{};
  static final List<_Sprite?> _palms = <_Sprite?>[null, null];

  static final Paint _imagePaint = Paint()
    ..filterQuality = FilterQuality.medium;

  static _Sprite _grassSprite(Color color) {
    return _grass.putIfAbsent(
      color.toARGB32(),
      () => _bakeBottom(
        grassBaseSize,
        (canvas, size) => PropArt.paintGrassTuft(canvas, size, color: color),
      ),
    );
  }

  static _Sprite _stoneSprite({required bool light}) {
    return _stones.putIfAbsent(
      light ? 1 : 0,
      () => _bakeBottom(
        stoneBaseSize,
        (canvas, size) => PropArt.paintStone(canvas, size, light: light),
      ),
    );
  }

  static _Sprite _palmSprite(int variant) {
    final index = variant.isEven ? 0 : 1;
    return _palms[index] ??= _bakeRaw(
      palmSize,
      (canvas, size) => _paintPalm(canvas, size, index == 0 ? 1 : -1),
    );
  }

  static void drawGrass(
    Canvas canvas,
    Offset ground,
    Size size,
    Color color,
  ) {
    _grassSprite(color).draw(
      canvas,
      Rect.fromLTWH(
        ground.dx - size.width / 2,
        ground.dy - size.height,
        size.width,
        size.height,
      ),
      _imagePaint,
    );
  }

  static void drawStone(
    Canvas canvas,
    Offset ground,
    Size size, {
    bool light = false,
  }) {
    _stoneSprite(light: light).draw(
      canvas,
      Rect.fromLTWH(
        ground.dx - size.width / 2,
        ground.dy - size.height,
        size.width,
        size.height,
      ),
      _imagePaint,
    );
  }

  /// 以底边中点为锚点绘制椰树。
  static void drawPalm(
    Canvas canvas,
    Offset ground, {
    double scale = 1,
    int variant = 0,
  }) {
    final width = palmSize.width * scale;
    final height = palmSize.height * scale;
    _palmSprite(variant).draw(
      canvas,
      Rect.fromLTWH(
        ground.dx - width / 2,
        ground.dy - height,
        width,
        height,
      ),
      _imagePaint,
    );
  }

  /// 把一个以底边中点为原点的画法烘焙成位图精灵。
  static _Sprite _bakeBottom(Size size, SpritePainter painter) {
    return _bakeRaw(
      size,
      (canvas, inner) {
        canvas.translate(size.width / 2, size.height);
        painter(canvas, inner);
      },
    );
  }

  /// 烘焙一个以左上角为原点的画法；位图按 [_bakeScale] 放大,
  /// 矢量回退时仍以原始尺寸记录。
  static _Sprite _bakeRaw(Size size, SpritePainter painter) {
    final recorder = PictureRecorder();
    final canvas = Canvas(recorder);
    painter(canvas, size);
    final picture = recorder.endRecording();

    ui.Image? image;
    try {
      final rasterRecorder = PictureRecorder();
      final rasterCanvas = Canvas(rasterRecorder);
      rasterCanvas.scale(_bakeScale);
      rasterCanvas.drawPicture(picture);
      final rasterPicture = rasterRecorder.endRecording();
      image = rasterPicture.toImageSync(
        (size.width * _bakeScale).round(),
        (size.height * _bakeScale).round(),
      );
      rasterPicture.dispose();
    } catch (_) {
      image = null;
    }

    return _Sprite(picture, image, size);
  }

  static void _paintPalm(Canvas canvas, Size size, int direction) {
    final base = Offset(size.width / 2, size.height);
    final lean = direction * 6.0;
    final top = base + Offset(lean, -60);

    final trunk = Path()
      ..moveTo(base.dx - 2.8, base.dy)
      ..quadraticBezierTo(
        base.dx + lean * 0.2,
        base.dy - 32,
        top.dx - 1.5,
        top.dy,
      )
      ..lineTo(top.dx + 1.5, top.dy)
      ..quadraticBezierTo(
        base.dx + lean * 0.2 + 2.4,
        base.dy - 32,
        base.dx + 2.8,
        base.dy,
      )
      ..close();
    canvas.drawPath(trunk, Paint()..color = const Color(0xFF7A5230));

    const leafColors = <Color>[
      Color(0xFF4F7A4E),
      Color(0xFF3E6642),
      Color(0xFF5E8A56),
    ];
    for (var i = 0; i < 7; i++) {
      final angle = -math.pi / 2 + (i - 3) * 0.38;
      final length = 24.0 + (i % 3) * 6;
      final tip = top +
          Offset(
            math.cos(angle) * length,
            math.sin(angle) * length * 0.5 + 6,
          );
      final frond = Path()
        ..moveTo(top.dx, top.dy)
        ..quadraticBezierTo(
          top.dx + math.cos(angle) * length * 0.5,
          top.dy + math.sin(angle) * length * 0.2 - 7,
          tip.dx,
          tip.dy,
        );
      canvas.drawPath(
        frond,
        Paint()
          ..color = leafColors[i % leafColors.length]
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.2
          ..strokeCap = StrokeCap.round,
      );
      canvas.drawLine(
        Offset(tip.dx, tip.dy),
        Offset(tip.dx - 2, tip.dy + 4),
        Paint()
          ..color = leafColors[(i + 1) % leafColors.length]
          ..strokeWidth = 1.8
          ..strokeCap = StrokeCap.round,
      );
    }
    canvas.drawCircle(
      top,
      3.4,
      Paint()..color = const Color(0xFF3E6642),
    );
  }
}

/// 一张缓存精灵：位图优先，位图不可用时退回矢量 Picture。
class _Sprite {
  _Sprite(this.picture, this.image, this.size);

  final Picture picture;
  final ui.Image? image;
  final Size size;

  void draw(Canvas canvas, Rect dest, Paint paint) {
    final raster = image;
    if (raster == null) {
      canvas.save();
      canvas.translate(dest.center.dx, dest.bottom);
      canvas.scale(dest.width / size.width, dest.height / size.height);
      canvas.translate(-size.width / 2, -size.height);
      canvas.drawPicture(picture);
      canvas.restore();
      return;
    }
    canvas.drawImageRect(
      raster,
      Rect.fromLTWH(0, 0, raster.width.toDouble(), raster.height.toDouble()),
      dest,
      paint,
    );
  }
}
