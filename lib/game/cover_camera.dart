import 'dart:ui';

/// 把固定画幅的世界铺进任意大小的画布所需的缩放。
///
/// 水平方向永远铺满：可见宽度就是世界宽度，骑行距离不会被裁短。
/// 画布比世界更高（折叠屏展开、近方形窗口）时，多出来的高度改为上下留白，
/// 由 `LetterboxComponent` 用天空色与近景墨色补齐，而不是继续放大去填满高度。
/// 画布比世界更宽时与原来的 cover 结果一致，只裁切上下。
double gameZoom(Size canvas, Size world) {
  if (canvas.isEmpty || world.isEmpty) {
    return 1;
  }
  return canvas.width / world.width;
}
