import 'dart:math' as math;
import 'dart:ui';

/// 把固定画幅的世界铺满任意大小的画布所需的缩放。
///
/// 采用 cover 语义：宁可裁掉一点天空或近景，也不在画面四周留黑边。
double coverZoom(Size canvas, Size world) {
  if (canvas.isEmpty || world.isEmpty) {
    return 1;
  }
  return math.max(canvas.width / world.width, canvas.height / world.height);
}
