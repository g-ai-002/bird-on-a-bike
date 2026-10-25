import 'dart:ui';

import 'package:bird_on_a_bike/game/cover_camera.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('画布铺满（cover）缩放', () {
    test('同比例画布缩放为 1', () {
      expect(coverZoom(const Size(800, 450), const Size(800, 450)), 1);
      expect(
        coverZoom(const Size(1920, 1080), const Size(800, 450)),
        closeTo(2.4, 1e-9),
      );
    });

    test('更宽或更高的画布按更大的比例放大，避免留黑边', () {
      expect(coverZoom(const Size(1200, 450), const Size(800, 450)), 1.5);
      expect(coverZoom(const Size(800, 900), const Size(800, 450)), 2);
      expect(
        coverZoom(const Size(960, 660), const Size(800, 450)),
        closeTo(660 / 450, 1e-9),
      );
    });

    test('空尺寸回退为 1', () {
      expect(coverZoom(Size.zero, const Size(800, 450)), 1);
      expect(coverZoom(const Size(800, 450), Size.zero), 1);
    });
  });
}
