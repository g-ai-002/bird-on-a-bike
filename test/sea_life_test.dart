import 'dart:ui';

import 'package:bird_on_a_bike/game/components/sea_life_component.dart';
import 'package:bird_on_a_bike/providers/game_provider.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes/fake_storage.dart';

void main() {
  testWidgets('渔夫划船与跃出水面的鱼可以完成渲染', (tester) async {
    final game = GameProvider(FakeStorageService.create(), audioEnabled: false);
    game.start();
    final sea = SeaLifeComponent(provider: game, priority: -45);
    // 推进到多个跃鱼周期，同时覆盖划船与溅水两种画面。
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
}
