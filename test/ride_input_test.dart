import 'package:bird_on_a_bike/game/input/ride_input.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('下滑手势', () {
    test('明确向下滑动触发俯身', () {
      expect(isDuckSwipe(const Offset(0, 40)), isTrue);
      expect(isDuckSwipe(const Offset(12, 38)), isTrue);
    });

    test('横向或向上滑动不触发', () {
      expect(isDuckSwipe(const Offset(40, 10)), isFalse);
      expect(isDuckSwipe(const Offset(0, -40)), isFalse);
    });

    test('位移太小不触发', () {
      expect(isDuckSwipe(const Offset(0, 10)), isFalse);
      expect(isDuckSwipe(Offset.zero), isFalse);
    });
  });

  group('上滑手势', () {
    test('明确向上滑动触发跳跃', () {
      expect(isJumpSwipe(const Offset(0, -40)), isTrue);
      expect(isJumpSwipe(const Offset(10, -24)), isTrue);
    });

    test('横向或向下滑动不触发', () {
      expect(isJumpSwipe(const Offset(40, -10)), isFalse);
      expect(isJumpSwipe(const Offset(0, 40)), isFalse);
    });

    test('位移太小不触发', () {
      expect(isJumpSwipe(const Offset(0, -10)), isFalse);
      expect(isJumpSwipe(Offset.zero), isFalse);
    });
  });
}
