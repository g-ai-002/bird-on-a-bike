import 'dart:ui' as ui;

import 'package:flame/components.dart';

import '../../utils/constants.dart';

/// 屏幕边缘轻微压暗，让视线集中在鹈鹕与路面上。
///
/// 径向渐变在加载时烘焙成半分辨率位图：渐变本身很平滑，放大看不出差别，
/// 之后每帧只做一次贴图采样，不再重复计算全屏 shader。
class VignetteComponent extends PositionComponent {
  VignetteComponent({super.priority})
    : super(
        position: Vector2.zero(),
        size: Vector2(AppConstants.worldWidth, AppConstants.worldHeight),
      );

  static const double _rasterScale = 0.5;

  late final ui.Paint _shaderPaint = ui.Paint()
    ..shader = ui.Gradient.radial(
      ui.Offset(size.x / 2, size.y * 0.46),
      size.x * 0.72,
      const <ui.Color>[
        ui.Color(0x00000000),
        ui.Color(0x14061018),
        ui.Color(0x33040B12),
      ],
      const <double>[0.5, 0.78, 1.0],
    );

  final ui.Paint _imagePaint = ui.Paint()
    ..filterQuality = ui.FilterQuality.low;

  ui.Image? _image;

  @override
  Future<void> onLoad() async {
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    canvas.scale(_rasterScale);
    canvas.drawRect(ui.Rect.fromLTWH(0, 0, size.x, size.y), _shaderPaint);
    final picture = recorder.endRecording();
    try {
      _image = picture.toImageSync(
        (size.x * _rasterScale).round(),
        (size.y * _rasterScale).round(),
      );
    } catch (_) {
      // Web 的 HTML 渲染器不支持 toImageSync，退回每帧绘制渐变。
      _image = null;
    }
    picture.dispose();
  }

  @override
  void onRemove() {
    _image?.dispose();
    _image = null;
    super.onRemove();
  }

  @override
  void render(ui.Canvas canvas) {
    final rect = ui.Rect.fromLTWH(0, 0, size.x, size.y);
    final image = _image;
    if (image == null) {
      canvas.drawRect(rect, _shaderPaint);
      return;
    }
    canvas.drawImageRect(
      image,
      ui.Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      rect,
      _imagePaint,
    );
  }
}
