import 'dart:ui';

import 'package:bird_on_a_bike/game/painting/pelican_art.dart';
import 'package:bird_on_a_bike/game/painting/prop_art.dart';
import 'package:bird_on_a_bike/game/rendering/stacked_sprite.dart';
import 'package:bird_on_a_bike/models/obstacle.dart';
import 'package:bird_on_a_bike/models/pickup.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('全部道具与骑行者画法都能完成渲染', (tester) async {
    final recorder = PictureRecorder();
    final canvas = Canvas(recorder);

    for (final kind in ObstacleKind.values) {
      final sprite = StackedSprite.bake(
        size: PropArt.obstacleSize(kind),
        painter: (inner, size) => PropArt.paintObstacle(inner, size, kind),
        layers: 3,
      );
      sprite.render(canvas, const Offset(120, 400));
      sprite.render(canvas, const Offset(320, 400), rotation: 0.02);
      sprite.dispose();
    }

    for (final kind in PickupKind.values) {
      final sprite = StackedSprite.bake(
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
      paintStacked(
        canvas,
        size: kRiderArtSize,
        painter: (inner, size) => paintPelicanRider(inner, size, look),
      );
    }

    final picture = recorder.endRecording();
    final image = await picture.toImage(800, 450);
    expect(image.width, 800);
    expect(image.height, 450);
    image.dispose();
    picture.dispose();
  });
}
