import 'package:bird_on_a_bike/game/collision.dart';
import 'package:bird_on_a_bike/game/world_layout.dart';
import 'package:bird_on_a_bike/models/obstacle.dart';
import 'package:bird_on_a_bike/models/pickup.dart';
import 'package:bird_on_a_bike/models/rider_motion.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const riderX = WorldLayout.riderX;

  Obstacle obstacleAt(ObstacleKind kind, double x, {double z = 0}) =>
      Obstacle(id: 1, kind: kind, x: x, z: z);

  group('地面障碍', () {
    test('贴地骑行会撞上礁石', () {
      final rock = obstacleAt(ObstacleKind.rock, riderX);
      expect(riderHitsObstacle(rock, RiderMotion.grounded), isTrue);
    });

    test('跳过礁石高度即安全', () {
      final rock = obstacleAt(ObstacleKind.rock, riderX);
      const rider = RiderMotion(height: 5);
      expect(riderHitsObstacle(rock, rider), isFalse);
    });

    test('木箱比礁石更高，需要更高的跳跃', () {
      final crate = obstacleAt(ObstacleKind.crate, riderX);
      const lowJump = RiderMotion(height: 4.2);
      const highJump = RiderMotion(height: 6);
      expect(riderHitsObstacle(crate, lowJump), isTrue);
      expect(riderHitsObstacle(crate, highJump), isFalse);
    });

    test('横向未接触时不判定碰撞', () {
      final rock = obstacleAt(ObstacleKind.rock, riderX + 20);
      expect(riderHitsObstacle(rock, RiderMotion.grounded), isFalse);
    });

    test('深度错开一个车身时不判定碰撞', () {
      final rock = obstacleAt(ObstacleKind.rock, riderX, z: 3);
      expect(riderHitsObstacle(rock, RiderMotion.grounded), isFalse);
      expect(
        riderHitsObstacle(rock, RiderMotion.grounded, riderZ: 3),
        isTrue,
      );
    });
  });

  group('悬空横幅', () {
    test('站立会撞上横幅', () {
      final banner = obstacleAt(ObstacleKind.banner, riderX);
      expect(riderHitsObstacle(banner, RiderMotion.grounded), isTrue);
    });

    test('俯身可以通过横幅', () {
      final banner = obstacleAt(ObstacleKind.banner, riderX);
      const ducking = RiderMotion(ducking: true);
      expect(riderHitsObstacle(banner, ducking), isFalse);
    });

    test('普通跳跃仍会撞上横幅', () {
      final banner = obstacleAt(ObstacleKind.banner, riderX);
      const rider = RiderMotion(height: 4, velocity: 20, jumps: 1);
      expect(riderHitsObstacle(banner, rider), isTrue);
    });

    test('跳得足够高可以从横幅上方越过', () {
      final banner = obstacleAt(ObstacleKind.banner, riderX);
      final bandTop =
          ObstacleKind.banner.clearance + ObstacleKind.banner.thickness;
      final rider = RiderMotion(height: bandTop + 1, velocity: -5, jumps: 2);
      expect(riderHitsObstacle(banner, rider), isFalse);
    });

    test('俯身且在空中不会因为低姿态而穿过横幅', () {
      final banner = obstacleAt(ObstacleKind.banner, riderX);
      const rider = RiderMotion(
        height: 6,
        velocity: -10,
        jumps: 1,
        ducking: true,
      );
      expect(riderHitsObstacle(banner, rider), isTrue);
    });
  });

  group('拾取判定', () {
    test('站立时能吃到胸口高度的小鱼', () {
      final fish = Pickup(id: 1, kind: PickupKind.fish, x: riderX, y: 4.8);
      expect(pickupReached(fish, RiderMotion.grounded), isTrue);
    });

    test('高处的鱼需要跳跃', () {
      final fish = Pickup(id: 1, kind: PickupKind.fish, x: riderX, y: 15);
      expect(pickupReached(fish, RiderMotion.grounded), isFalse);
      const jumping = RiderMotion(height: 11);
      expect(pickupReached(fish, jumping), isTrue);
    });

    test('横向远离时吃不到', () {
      final fish = Pickup(
        id: 1,
        kind: PickupKind.fish,
        x: riderX + 10,
        y: 4.8,
      );
      expect(pickupReached(fish, RiderMotion.grounded), isFalse);
    });

    test('深度错开时需要在同一骑行线上', () {
      final fish = Pickup(
        id: 1,
        kind: PickupKind.fish,
        x: riderX,
        y: 4.8,
        z: 4,
      );
      expect(pickupReached(fish, RiderMotion.grounded), isFalse);
      expect(pickupReached(fish, RiderMotion.grounded, riderZ: 4), isTrue);
    });
  });
}
