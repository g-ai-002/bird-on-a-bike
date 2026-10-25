import 'package:bird_on_a_bike/game/scene3d/scene_units.dart';
import 'package:bird_on_a_bike/models/obstacle.dart';
import 'package:bird_on_a_bike/models/pickup.dart';
import 'package:bird_on_a_bike/models/rider_motion.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SceneUnits 坐标换算', () {
    test('画面中心为世界原点，骑行者固定在左侧', () {
      expect(SceneUnits.x(400), 0);
      expect(SceneUnits.x(190), -21);
      expect(SceneUnits.riderX, -21);
    });

    test('像素到世界单位按 10:1 折算', () {
      expect(SceneUnits.height(10), 1);
      expect(SceneUnits.height(96), 9.6);
      expect(SceneUnits.x(870), 47);
    });

    test('障碍中心与尺寸按玩法数据换算', () {
      const crate = Obstacle(id: 1, kind: ObstacleKind.crate, x: 300);
      expect(SceneUnits.obstacleCenterX(crate), SceneUnits.x(322));
      expect(SceneUnits.obstacleWidth(ObstacleKind.crate), 4.4);
      expect(SceneUnits.obstacleHeight(ObstacleKind.crate), 5.6);
    });

    test('横幅下沿足够俯身通过、不足以站立通过', () {
      final clearance = SceneUnits.bannerClearance(ObstacleKind.banner);
      expect(clearance, 6.8);
      expect(SceneUnits.height(RiderMotion.duckHeight), lessThan(clearance));
      expect(
        SceneUnits.height(RiderMotion.standingHeight),
        greaterThan(clearance),
      );
    });

    test('拾取物高度以离地高度为准', () {
      const fish = Pickup(id: 7, kind: PickupKind.fish, x: 520, y: 70);
      expect(SceneUnits.pickupX(fish), SceneUnits.x(520));
      expect(SceneUnits.pickupHeight(fish), 7);
    });
  });
}
