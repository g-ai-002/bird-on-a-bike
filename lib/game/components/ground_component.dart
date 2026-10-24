import 'package:flutter/material.dart';

import '../../utils/constants.dart';
import '../ride_style.dart';
import 'scene_layer_component.dart';

/// 路面与路肩，虚线随骑行距离滚动。
class GroundComponent extends SceneLayerComponent {
  GroundComponent({required super.provider, super.priority});

  static const _pebbles = <Offset>[
    Offset(64, 430),
    Offset(168, 442),
    Offset(286, 424),
    Offset(392, 440),
    Offset(498, 432),
    Offset(612, 444),
    Offset(716, 426),
    Offset(772, 438),
  ];

  final Paint _paint = Paint();

  @override
  void render(Canvas canvas) {
    const top = AppConstants.groundY;
    canvas.drawRect(
      Rect.fromLTWH(
        0,
        top,
        AppConstants.worldWidth,
        AppConstants.worldHeight - top,
      ),
      Paint()..color = RideColors.road,
    );

    _paint.color = RideColors.roadLine.withValues(alpha: 0.9);
    canvas.drawRect(
      const Rect.fromLTWH(0, top - 3, AppConstants.worldWidth, 6),
      _paint,
    );
    _paint.color = RideColors.roadLine.withValues(alpha: 0.25);
    canvas.drawRect(
      const Rect.fromLTWH(0, top + 5, AppConstants.worldWidth, 2),
      _paint,
    );

    final distancePx = provider.state.distance * 10;
    final offset = distancePx % 92;
    _paint.color = RideColors.roadLine.withValues(alpha: 0.75);
    for (var x = -offset; x < AppConstants.worldWidth; x += 92) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, top + 34, 48, 5),
          const Radius.circular(2.5),
        ),
        _paint,
      );
    }

    _paint.color = RideColors.roadLine.withValues(alpha: 0.3);
    canvas.drawRect(
      const Rect.fromLTWH(0, AppConstants.worldHeight - 6, AppConstants.worldWidth, 3),
      _paint,
    );

    _paint.color = Colors.black.withValues(alpha: 0.12);
    for (final pebble in _pebbles) {
      final x = (pebble.dx - distancePx) % AppConstants.worldWidth;
      final wrapped = x < 0 ? x + AppConstants.worldWidth : x;
      canvas.drawCircle(Offset(wrapped, pebble.dy), 2.2, _paint);
    }
  }
}
