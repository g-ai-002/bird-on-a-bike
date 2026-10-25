import 'dart:ui';

import 'package:bird_on_a_bike/game/components/road_component.dart';
import 'package:bird_on_a_bike/providers/game_provider.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes/fake_storage.dart';

void main() {
  test('箭头平铺后右缘外始终留有待入箭头', () {
    const width = 800.0;
    final spacing = RoadComponent.arrowSpacing;
    final count = RoadComponent.arrowRowCount(width);
    // 平移量在 [0, 间距) 之间循环，覆盖最坏情况。
    for (final shift in <double>[
      0,
      spacing * 0.25,
      spacing * 0.5,
      spacing - 0.1,
    ]) {
      final lastStart = (count - 1) * spacing - shift;
      // 至少留出撞击抖动（约 9px）的余量：画面内的箭头都已提前绘制好。
      expect(lastStart, greaterThanOrEqualTo(width + 9));
    }
  });

  testWidgets('路面（含平铺箭头与沿路植被）可以完成渲染', (tester) async {
    final game = GameProvider(FakeStorageService.create(), audioEnabled: false);
    game.start();
    final road = RoadComponent(provider: game, priority: -40);

    final recorder = PictureRecorder();
    final canvas = Canvas(recorder);
    road.render(canvas);
    final picture = recorder.endRecording();
    final image = await picture.toImage(800, 450);
    expect(image.width, 800);
    expect(image.height, 450);
    image.dispose();
    picture.dispose();
  });
}
