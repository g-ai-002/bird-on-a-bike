import 'package:flame/components.dart';

import '../../providers/game_provider.dart';
import '../../utils/constants.dart';

/// 覆盖整个游戏世界的图层基类。
abstract class SceneLayerComponent extends PositionComponent {
  SceneLayerComponent({
    required this.provider,
    int? priority,
  }) : super(
          position: Vector2.zero(),
          size: Vector2(AppConstants.worldWidth, AppConstants.worldHeight),
          priority: priority,
        );

  final GameProvider provider;
}
