import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/events.dart';

import '../../utils/constants.dart';
import 'ride_input.dart';

/// 覆盖整个游戏画面的触屏/鼠标输入层：
/// 点击跳跃，向下滑动俯身。
class RideInputComponent extends PositionComponent
    with TapCallbacks, DragCallbacks {
  RideInputComponent({
    required this.onJump,
    required this.onDuck,
    int? priority,
  }) : super(
          position: Vector2.zero(),
          size: Vector2(AppConstants.worldWidth, AppConstants.worldHeight),
          priority: priority,
        );

  final VoidCallback onJump;
  final VoidCallback onDuck;

  Vector2 _dragDelta = Vector2.zero();
  bool _duckTriggered = false;

  @override
  void onTapUp(TapUpEvent event) {
    onJump();
  }

  @override
  void onDragStart(DragStartEvent event) {
    super.onDragStart(event);
    _dragDelta = Vector2.zero();
    _duckTriggered = false;
  }

  @override
  void onDragUpdate(DragUpdateEvent event) {
    super.onDragUpdate(event);
    _dragDelta += event.localDelta;
    if (_duckTriggered) return;
    if (isDuckSwipe(Offset(_dragDelta.x, _dragDelta.y))) {
      _duckTriggered = true;
      onDuck();
    }
  }

  @override
  void onDragEnd(DragEndEvent event) {
    super.onDragEnd(event);
    _dragDelta = Vector2.zero();
    _duckTriggered = false;
  }

  @override
  void onDragCancel(DragCancelEvent event) {
    super.onDragCancel(event);
    _dragDelta = Vector2.zero();
    _duckTriggered = false;
  }
}
