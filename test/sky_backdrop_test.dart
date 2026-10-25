import 'dart:ui';

import 'package:bird_on_a_bike/game/components/sky_backdrop_component.dart';
import 'package:bird_on_a_bike/providers/game_provider.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes/fake_storage.dart';

void main() {
  testWidgets('远景天空、平铺山脊与波光可以完成渲染', (tester) async {
    final game = GameProvider(FakeStorageService.create(), audioEnabled: false);
    game.start();
    final sky = SkyBackdropComponent(
      provider: game,
      rasterScale: () => 2,
      priority: -50,
    );
    await sky.onLoad();
    sky.update(1 / 60);

    final recorder = PictureRecorder();
    final canvas = Canvas(recorder);
    sky.render(canvas);
    final picture = recorder.endRecording();
    final image = await picture.toImage(800, 450);
    expect(image.width, 800);
    expect(image.height, 450);
    image.dispose();
    picture.dispose();
  });
}
