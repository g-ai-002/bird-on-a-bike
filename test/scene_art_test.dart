import 'dart:ui';

import 'package:bird_on_a_bike/game/painting/pelican_art.dart';
import 'package:bird_on_a_bike/game/painting/prop_art.dart';
import 'package:bird_on_a_bike/game/rendering/baked_sprite.dart';
import 'package:bird_on_a_bike/models/obstacle.dart';
import 'package:bird_on_a_bike/models/pickup.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('全部道具与骑行者画法都能完成渲染', (tester) async {
    final recorder = PictureRecorder();
    final canvas = Canvas(recorder);

    for (final kind in ObstacleKind.values) {
      final sprite = BakedSprite.bake(
        size: PropArt.obstacleSize(kind),
        painter: (inner, size) => PropArt.paintObstacle(inner, size, kind),
      );
      sprite.render(canvas, const Offset(120, 400));
      sprite.render(canvas, const Offset(320, 400), rotation: 0.02);
      sprite.dispose();
    }

    for (final kind in PickupKind.values) {
      final sprite = BakedSprite.bake(
        size: PropArt.pickupSize(kind),
        painter: (inner, size) => PropArt.paintPickup(inner, size, kind),
        anchorY: 0.5,
      );
      sprite.render(canvas, const Offset(520, 300), scale: 1.04);
      sprite.dispose();
    }

    for (final look in <RideLook>[
      const RideLook(wheelAngle: 0.4, wingPhase: 1.2),
      const RideLook(ducking: true, shield: true),
      const RideLook(airborne: true, magnet: true, wingPhase: 2.4),
    ]) {
      paintPelicanRider(canvas, kRiderArtSize, look);
    }

    final picture = recorder.endRecording();
    final image = await picture.toImage(800, 450);
    expect(image.width, 800);
    expect(image.height, 450);
    image.dispose();
    picture.dispose();
  });

  test('吃鱼张嘴程度先开后合', () {
    expect(eatMouthOpen(0), 0);
    expect(eatMouthOpen(kEatMouthSeconds), 0);
    expect(eatMouthOpen(kEatMouthSeconds / 2), closeTo(1, 1e-9));
    expect(
      eatMouthOpen(kEatMouthSeconds * 0.75),
      lessThan(eatMouthOpen(kEatMouthSeconds * 0.5)),
    );
  });

  testWidgets('张嘴时鹈鹕喙部画面与闭嘴不同', (tester) async {
    // 像素回读依赖真实异步，需放在 runAsync 里，否则会卡在 toByteData。
    final closed = await tester.runAsync(
      () => _renderRiderPixels(const RideLook(wheelAngle: 0.4)),
    );
    final open = await tester.runAsync(
      () => _renderRiderPixels(const RideLook(wheelAngle: 0.4, mouthOpen: 1)),
    );
    expect(open, isNot(equals(closed)));
  });
}

/// 把一帧骑行者渲染成原始像素，用于比较不同姿态的画面差异。
Future<List<int>> _renderRiderPixels(RideLook look) async {
  final recorder = PictureRecorder();
  final canvas = Canvas(recorder);
  paintPelicanRider(canvas, kRiderArtSize, look);
  final picture = recorder.endRecording();
  final image = await picture.toImage(
    kRiderArtSize.width.round(),
    kRiderArtSize.height.round(),
  );
  final bytes = await image.toByteData();
  image.dispose();
  picture.dispose();
  return bytes!.buffer.asUint8List();
}
