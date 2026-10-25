import 'dart:ui';

import 'package:bird_on_a_bike/game/cover_camera.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('画布缩放（保左右长度）', () {
    test('同比例画布缩放为 1', () {
      expect(gameZoom(const Size(800, 450), const Size(800, 450)), 1);
      expect(
        gameZoom(const Size(1920, 1080), const Size(800, 450)),
        closeTo(2.4, 1e-9),
      );
    });

    test('更宽的画布按宽度放大，上下裁切', () {
      expect(gameZoom(const Size(1200, 450), const Size(800, 450)), 1.5);
      expect(
        gameZoom(const Size(2560, 1080), const Size(800, 450)),
        closeTo(3.2, 1e-9),
      );
    });

    test('更高的画布保持左右长度，上下留白', () {
      // 折叠屏展开等近方形画布：可见世界宽度仍是 800，多出来的高度交给留白层。
      expect(gameZoom(const Size(1000, 1000), const Size(800, 450)), 1.25);
      expect(gameZoom(const Size(1200, 900), const Size(800, 450)), 1.5);
      // 留白量 = 画布高度 - 世界高度 × 缩放。
      expect(1000 - 450 * 1.25, closeTo(437.5, 1e-9));
      expect(900 - 450 * 1.5, closeTo(225, 1e-9));
    });

    test('空尺寸回退为 1', () {
      expect(gameZoom(Size.zero, const Size(800, 450)), 1);
      expect(gameZoom(const Size(800, 450), Size.zero), 1);
    });
  });
}
