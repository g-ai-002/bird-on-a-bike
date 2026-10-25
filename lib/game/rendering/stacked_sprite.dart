import 'dart:math' as math;
import 'dart:ui';

/// 精灵画法：在左上角为原点的 [Size] 画布内完成绘制。
typedef SpritePainter = void Function(Canvas canvas, Size size);

/// 精灵堆叠：把同一张 2D 画法按固定偏移重复若干层，逐层压暗后叠上正稿，
/// 用很低的绘制成本做出「有厚度」的低多边形体积感。
///
/// 静态道具在加载时烘焙成一张 [Picture]，之后每帧只画一次；
/// 骑行者这类每帧变化的精灵走 [paintStacked] 直接分层绘制。
class StackedSprite {
  StackedSprite._(this._picture, this._size, this._anchor);

  final Picture _picture;

  /// 含堆叠偏移与留白后的整张精灵尺寸。
  final Size _size;

  /// 正稿锚点在精灵内的位置。
  final Offset _anchor;

  Size get size => _size;

  static StackedSprite bake({
    required Size size,
    required SpritePainter painter,
    int layers = 4,
    Offset step = const Offset(-1.1, 1.9),
    Color shade = const Color(0xFF7C919B),
    double anchorX = 0.5,
    double anchorY = 1,
    double padding = 2,
  }) {
    final spread = Offset(step.dx * (layers - 1), step.dy * (layers - 1));
    final padLeft = math.max(0.0, -spread.dx) + padding;
    final padRight = math.max(0.0, spread.dx) + padding;
    final padTop = math.max(0.0, -spread.dy) + padding;
    final padBottom = math.max(0.0, spread.dy) + padding;
    final total = Size(
      size.width + padLeft + padRight,
      size.height + padTop + padBottom,
    );
    final origin = Offset(padLeft, padTop);

    final recorder = PictureRecorder();
    final canvas = Canvas(recorder);
    final layerBounds = Rect.fromLTWH(
      origin.dx - padding,
      origin.dy - padding,
      size.width + padding * 2,
      size.height + padding * 2,
    );

    for (var i = layers - 1; i >= 1; i--) {
      final t = i / math.max(1, layers - 1);
      final tint = Color.lerp(
        const Color(0xFFFFFFFF),
        shade,
        0.35 + 0.55 * t,
      )!;
      canvas.save();
      canvas.translate(
        origin.dx + step.dx * i,
        origin.dy + step.dy * i,
      );
      canvas.saveLayer(
        layerBounds,
        Paint()..colorFilter = ColorFilter.mode(tint, BlendMode.modulate),
      );
      painter(canvas, size);
      canvas.restore();
      canvas.restore();
    }

    canvas.save();
    canvas.translate(origin.dx, origin.dy);
    painter(canvas, size);
    canvas.restore();

    return StackedSprite._(
      recorder.endRecording(),
      total,
      Offset(origin.dx + size.width * anchorX, origin.dy + size.height * anchorY),
    );
  }

  /// 以 [point] 对齐锚点绘制精灵。
  void render(
    Canvas canvas,
    Offset point, {
    double scale = 1,
    Paint? paint,
    double rotation = 0,
  }) {
    canvas.save();
    canvas.translate(point.dx, point.dy);
    if (rotation != 0) {
      canvas.rotate(rotation);
    }
    if (scale != 1) {
      canvas.scale(scale);
    }
    canvas.translate(-_anchor.dx, -_anchor.dy);
    if (paint == null) {
      canvas.drawPicture(_picture);
    } else {
      canvas.saveLayer(Offset.zero & _size, paint);
      canvas.drawPicture(_picture);
      canvas.restore();
    }
    canvas.restore();
  }

  void dispose() {
    _picture.dispose();
  }
}

/// 动态精灵的分层绘制（画布原点应已对齐到精灵左上角）。
void paintStacked(
  Canvas canvas, {
  required Size size,
  required SpritePainter painter,
  int layers = 3,
  Offset step = const Offset(-1.2, 2.0),
  Color shade = const Color(0xFF7C919B),
  double padding = 2,
}) {
  final bounds = Rect.fromLTWH(
    -padding,
    -padding,
    size.width + padding * 2,
    size.height + padding * 2,
  );
  for (var i = layers - 1; i >= 1; i--) {
    final t = i / math.max(1, layers - 1);
    final tint = Color.lerp(const Color(0xFFFFFFFF), shade, 0.35 + 0.55 * t)!;
    canvas.save();
    canvas.translate(step.dx * i, step.dy * i);
    canvas.saveLayer(
      bounds,
      Paint()..colorFilter = ColorFilter.mode(tint, BlendMode.modulate),
    );
    painter(canvas, size);
    canvas.restore();
    canvas.restore();
  }
  painter(canvas, size);
}
