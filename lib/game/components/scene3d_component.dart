import 'dart:ui';

import 'package:flutter_scene/scene.dart';

import '../../services/log_service.dart';
import '../scene3d/ride_scene.dart';
import 'scene_layer_component.dart';

/// 把 [RideScene] 挂到 Flame 世界树上的渲染层。
///
/// 相机、震动与慢动作仍由 Flame 的取景器与世界时间缩放负责；
/// 这里只按整个世界矩形调用一次 `Scene.render`。
class Scene3DComponent extends SceneLayerComponent {
  Scene3DComponent({required super.provider, super.priority});

  RideScene? _rideScene;

  bool get isReady => _rideScene != null;

  /// 初始化 Flutter GPU 资源并构建场景。
  ///
  /// 返回 `false` 表示当前设备/构建没有可用的 Flutter GPU，
  /// 调用方应回退到 2D 渲染。
  Future<bool> prepare() async {
    try {
      await Scene.initializeStaticResources();
      final ride = RideScene(provider: provider)..build();
      _rideScene = ride;
      LogService.info('3D 场景初始化完成');
      return true;
    } catch (error, stack) {
      LogService.error('3D 场景初始化失败，回退 2D 渲染', error, stack);
      return false;
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    _rideScene?.update(dt);
  }

  @override
  void render(Canvas canvas) {
    final ride = _rideScene;
    if (ride == null) return;
    ride.render(canvas, Rect.fromLTWH(0, 0, width, height));
  }
}
