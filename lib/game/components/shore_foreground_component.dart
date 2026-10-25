import 'dart:ui';

import '../../utils/constants.dart';
import '../iso_projection.dart';
import '../painting/prop_art.dart';
import 'scene_layer_component.dart';

/// 贴近镜头的近景剪影：底边草丛与碎石。
///
/// 比路面滚得更快（1.18 倍），用最暗的色块压住画面下沿，
/// 让中景的等距路面产生纵深。
class ShoreForegroundComponent extends SceneLayerComponent {
  ShoreForegroundComponent({required super.provider, super.priority});

  static const Color _ink = Color(0xFF16262B);
  static const Color _inkSoft = Color(0xFF1E3138);
  static const double _parallax = 1.18;

  @override
  void render(Canvas canvas) {
    final travel = IsoProjection.travelPixels(provider.state.distance) * _parallax;
    final unitScroll = travel / IsoProjection.pxPerUnit;

    canvas.drawRect(
      Rect.fromLTWH(0, height - 12, width, 12),
      Paint()..color = _ink.withValues(alpha: 0.55),
    );

    const gap = 2.4;
    final tile = (unitScroll / gap).floor();
    for (var i = -2; i <= AppConstants.worldWidth / (gap * 10) + 3; i++) {
      final index = tile + i;
      final worldX = index * gap - unitScroll;
      if (worldX < -46 || worldX > 46) continue;
      final screenX =
          IsoProjection.project(worldX, 0, IsoProjection.roadNearZ).dx;
      final tuftHeight = 16.0 + (index % 4) * 6.5;
      final tuftWidth = tuftHeight * 0.7;
      canvas.save();
      canvas.translate(screenX, height + 4);
      PropArt.paintGrassTuft(
        canvas,
        Size(tuftWidth, tuftHeight),
        color: index.isEven ? _ink : _inkSoft,
      );
      canvas.restore();
    }

    const stoneGap = 8.3;
    final stoneTile = (unitScroll / stoneGap).floor();
    for (var i = -1; i <= 12; i++) {
      final index = stoneTile + i;
      final worldX = index * stoneGap - unitScroll;
      if (worldX < -44 || worldX > 44) continue;
      if (index % 3 != 0) continue;
      final screenX =
          IsoProjection.project(worldX, 0, IsoProjection.roadNearZ).dx;
      final size = 14.0 + (index % 3) * 6;
      canvas.save();
      canvas.translate(screenX, height + 6);
      canvas.scale(1, 0.6);
      PropArt.paintStone(canvas, Size(size, size));
      canvas.restore();
    }
  }
}
