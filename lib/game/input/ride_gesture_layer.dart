import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/events.dart';

import 'ride_input.dart';

/// 铺满整个游戏画布的手势层。
///
/// 挂在相机的 viewport 上（HUD 空间），因此不受取景器缩放影响，
/// 画布任意位置的点击、上滑与下滑都能收到：
/// 点击 / 上滑起跳，下滑俯身。
class RideGestureLayer extends PositionComponent
    with TapCallbacks, DragCallbacks {
  RideGestureLayer({
    required this.onJump,
    required this.onDuck,
    super.priority,
  });

  final VoidCallback onJump;
  final VoidCallback onDuck;

  Offset _dragDelta = Offset.zero;
  bool _triggered = false;

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    this.size = size;
  }

  @override
  void onParentResize(Vector2 maxSize) {
    super.onParentResize(maxSize);
    size = maxSize;
  }

  @override
  void onTapUp(TapUpEvent event) {
    onJump();
  }

  @override
  void onDragStart(DragStartEvent event) {
    super.onDragStart(event);
    _dragDelta = Offset.zero;
    _triggered = false;
  }

  @override
  void onDragUpdate(DragUpdateEvent event) {
    super.onDragUpdate(event);
    _dragDelta += Offset(event.localDelta.x, event.localDelta.y);
    if (_triggered) return;
    if (isJumpSwipe(_dragDelta)) {
      _triggered = true;
      onJump();
    } else if (isDuckSwipe(_dragDelta)) {
      _triggered = true;
      onDuck();
    }
  }

  @override
  void onDragEnd(DragEndEvent event) {
    super.onDragEnd(event);
    _dragDelta = Offset.zero;
    _triggered = false;
  }

  @override
  void onDragCancel(DragCancelEvent event) {
    super.onDragCancel(event);
    _dragDelta = Offset.zero;
    _triggered = false;
  }
}
