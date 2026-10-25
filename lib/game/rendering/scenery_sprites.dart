import 'dart:math' as math;
import 'dart:ui';

import '../painting/prop_art.dart';
import 'baked_sprite.dart';

/// 沿路植被与碎石的缓存精灵。
///
/// 草丛与碎石按颜色缓存成矢量 [Picture]，任意缩放下都清晰且不再重复
/// 构建 Path；椰树烘焙成整张 [BakedSprite]。
class ScenerySprites {
  ScenerySprites._();

  static const Size grassBaseSize = Size(20, 28);
  static const Size stoneBaseSize = Size(24, 24);
  static const Size palmSize = Size(140, 84);

  static final Map<int, Picture> _grass = <int, Picture>{};
  static final Map<int, Picture> _stones = <int, Picture>{};

  static final List<BakedSprite> _palms = <BakedSprite>[
    BakedSprite.bake(
      size: palmSize,
      painter: (canvas, size) => _paintPalm(canvas, size, 1),
    ),
    BakedSprite.bake(
      size: palmSize,
      painter: (canvas, size) => _paintPalm(canvas, size, -1),
    ),
  ];

  static Picture grass(Color color) {
    return _grass.putIfAbsent(
      color.toARGB32(),
      () => _recordBottom(
        grassBaseSize,
        (canvas, size) => PropArt.paintGrassTuft(canvas, size, color: color),
      ),
    );
  }

  static Picture stone({required bool light}) {
    return _stones.putIfAbsent(
      light ? 1 : 0,
      () => _recordBottom(
        stoneBaseSize,
        (canvas, size) => PropArt.paintStone(canvas, size, light: light),
      ),
    );
  }

  static BakedSprite palm(int variant) => _palms[variant.isEven ? 0 : 1];

  static void drawGrass(
    Canvas canvas,
    Offset ground,
    Size size,
    Color color,
  ) {
    canvas.save();
    canvas.translate(ground.dx, ground.dy);
    canvas.scale(
      size.width / grassBaseSize.width,
      size.height / grassBaseSize.height,
    );
    canvas.drawPicture(grass(color));
    canvas.restore();
  }

  static void drawStone(
    Canvas canvas,
    Offset ground,
    Size size, {
    bool light = false,
  }) {
    canvas.save();
    canvas.translate(ground.dx, ground.dy);
    canvas.scale(
      size.width / stoneBaseSize.width,
      size.height / stoneBaseSize.height,
    );
    canvas.drawPicture(stone(light: light));
    canvas.restore();
  }

  static Picture _recordBottom(Size size, SpritePainter painter) {
    final recorder = PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.translate(size.width / 2, size.height);
    painter(canvas, size);
    return recorder.endRecording();
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
