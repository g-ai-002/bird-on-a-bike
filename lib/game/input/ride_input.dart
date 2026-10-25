import 'dart:ui';

/// 触发俯身所需的最小下滑距离（逻辑像素）。
const double duckSwipeThreshold = 24;

/// 触发跳跃所需的最小上滑距离（逻辑像素）。
const double jumpSwipeThreshold = 20;

/// 位移是否构成一次明确的下滑手势。
bool isDuckSwipe(Offset delta) {
  return delta.dy > duckSwipeThreshold && delta.dy.abs() > delta.dx.abs();
}

/// 位移是否构成一次明确的上滑手势（上滑同样起跳）。
bool isJumpSwipe(Offset delta) {
  return delta.dy < -jumpSwipeThreshold && delta.dy.abs() > delta.dx.abs();
}
