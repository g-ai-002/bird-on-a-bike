import 'package:bird_on_a_bike/utils/ride_hints.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('玩法提示按所在平台切换文案', () {
    if (isDesktopPlatform) {
      expect(RideHints.home, contains('空格'));
      expect(RideHints.home, contains('↓ / S'));
      expect(RideHints.inGame, contains('P 暂停'));
      expect(RideHints.jump, contains('W'));
      expect(RideHints.duck, contains('S'));
      expect(RideHints.pause, contains('Esc'));
    } else {
      expect(RideHints.home, contains('点击'));
      expect(RideHints.home, contains('下滑'));
      expect(RideHints.inGame, contains('右上角'));
      expect(RideHints.jump, contains('上滑'));
      expect(RideHints.duck, contains('下滑'));
      expect(RideHints.pause, contains('右上角'));
    }
    expect(RideHints.home, isNot(contains('\n')));
    expect(RideHints.inGame, isNot(contains('\n')));
  });
}
