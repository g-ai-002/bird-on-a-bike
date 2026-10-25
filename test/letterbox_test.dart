import 'dart:ui';

import 'package:bird_on_a_bike/game/components/letterbox_component.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('上下留白补块', () {
    test('16:9 取景不需要留白', () {
      final (top, bottom) = letterboxBands(
        const Rect.fromLTWH(0, 0, 800, 450),
        worldWidth: 800,
        worldHeight: 450,
      );
      expect(top, isNull);
      expect(bottom, isNull);
    });

    test('方形画布上下各补一块', () {
      final (top, bottom) = letterboxBands(
        const Rect.fromLTWH(0, -175, 800, 800),
        worldWidth: 800,
        worldHeight: 450,
      );
      expect(top, isNotNull);
      expect(bottom, isNotNull);
      expect(top!.bottom, 0);
      expect(bottom!.top, 450);
      expect(top.top, lessThan(0));
      expect(bottom.bottom, greaterThan(450));
    });

    test('只超出上沿时只补上方', () {
      final (top, bottom) = letterboxBands(
        const Rect.fromLTWH(0, -40, 800, 460),
        worldWidth: 800,
        worldHeight: 450,
      );
      expect(top, isNotNull);
      expect(bottom, isNull);
    });
  });
}
