import 'dart:ui';

/// 精灵画法：在左上角为原点的 [Size] 画布内完成绘制。
typedef SpritePainter = void Function(Canvas canvas, Size size);

/// 静态道具精灵：加载时把矢量画法烘焙成一张 [Picture]，之后每帧只画一次。
///
/// 只有一层正稿，不再分层压暗叠影，因此绘制时没有额外离屏图层。
class BakedSprite {
  BakedSprite._(this._picture, this._size, this._anchor);

  final Picture _picture;

  /// 含四周留白的整张精灵尺寸。
  final Size _size;

  /// 正稿锚点在精灵内的位置。
  final Offset _anchor;

  Size get size => _size;

  static BakedSprite bake({
    required Size size,
    required SpritePainter painter,
    double anchorX = 0.5,
    double anchorY = 1,
    double padding = 2,
  }) {
    final total = Size(
      size.width + padding * 2,
      size.height + padding * 2,
    );
    final origin = Offset(padding, padding);

    final recorder = PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.translate(origin.dx, origin.dy);
    painter(canvas, size);

    return BakedSprite._(
      recorder.endRecording(),
      total,
      Offset(
        origin.dx + size.width * anchorX,
        origin.dy + size.height * anchorY,
      ),
    );
  }

  /// 以 [point] 对齐锚点绘制精灵。
  void render(
    Canvas canvas,
    Offset point, {
    double scale = 1,
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
    canvas.drawPicture(_picture);
    canvas.restore();
  }

  void dispose() {
    _picture.dispose();
  }
}
