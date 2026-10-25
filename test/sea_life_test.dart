import 'dart:ui';

import 'package:bird_on_a_bike/game/components/sea_life_component.dart';
import 'package:bird_on_a_bike/providers/game_provider.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes/fake_storage.dart';

void main() {
  testWidgets('远处跃出水面的鱼可以完成渲染', (tester) async {
    final game = GameProvider(FakeStorageService.create(), audioEnabled: false);
    game.start();
    final sea = SeaLifeComponent(provider: game, priority: -45);
    // 推进到多个跃鱼周期，覆盖跃起与溅水画面。
    for (var i = 0; i < 14; i++) {
      sea.update(0.6);
    }

    final recorder = PictureRecorder();
    final canvas = Canvas(recorder);
    sea.render(canvas);
    final picture = recorder.endRecording();
    final image = await picture.toImage(800, 450);
    expect(image.width, 800);
    image.dispose();
    picture.dispose();
  });

  test('入水前不出现落水浪花与波纹', () {
    const period = 6.4;
    final splash = SeaJumpSplash.at(
      cycle: SeaJumpSplash.jumpPortion * 0.95,
      period: period,
    );
    expect(splash.landingStrength, 0);
    expect(splash.rippleProgress, isEmpty);
  });

  test('跃出瞬间起水花，并在跃出阶段内淡出', () {
    const period = 6.4;
    final takeOff = SeaJumpSplash.at(cycle: 0, period: period);
    expect(takeOff.takeOffStrength, 1);
    expect(takeOff.landingStrength, 0);

    final faded = SeaJumpSplash.at(
      cycle: SeaJumpSplash.jumpPortion * 0.6,
      period: period,
    );
    expect(faded.takeOffStrength, 0);
  });

  test('鱼入水那一刻才开始落水浪花与波纹', () {
    const period = 6.4;
    final landing = SeaJumpSplash.at(
      cycle: SeaJumpSplash.jumpPortion,
      period: period,
    );
    expect(landing.landingStrength, 1);
    expect(landing.rippleProgress.first, 0);

    final later = SeaJumpSplash.at(
      cycle: SeaJumpSplash.jumpPortion + 0.2 / period,
      period: period,
    );
    expect(later.landingStrength, greaterThan(0));
    expect(later.landingStrength, lessThan(1));
    expect(later.rippleProgress.first, greaterThan(0));
  });
}
