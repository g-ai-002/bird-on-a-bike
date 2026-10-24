import 'package:bird_on_a_bike/models/rider_motion.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('起跳', () {
    test('地面起跳获得向上速度并消耗一次跳跃', () {
      const rider = RiderMotion.grounded;
      final jumped = rider.jump();
      expect(jumped.velocity, RiderMotion.jumpVelocity);
      expect(jumped.jumps, 1);
      expect(jumped.ducking, isFalse);
    });

    test('最多两段跳', () {
      final first = RiderMotion.grounded.jump();
      final second = first.jump();
      final third = second.jump();
      expect(second.jumps, 2);
      expect(second.velocity, RiderMotion.doubleJumpVelocity);
      expect(third.jumps, 2);
      expect(third.velocity, second.velocity);
    });

    test('落地后重置跳跃次数', () {
      var rider = RiderMotion.grounded.jump();
      for (var i = 0; i < 200; i++) {
        rider = rider.step(1 / 60);
      }
      expect(rider.height, 0);
      expect(rider.jumps, 0);
      expect(rider.canJump, isTrue);
    });

    test('俯身时起跳会先站起', () {
      final rider = const RiderMotion(ducking: true);
      final jumped = rider.jump();
      expect(jumped.ducking, isFalse);
      expect(jumped.velocity, greaterThan(0));
    });
  });

  group('松键与下坠', () {
    test('松开跳跃键截断上升速度', () {
      final rising = RiderMotion.grounded.jump();
      final cut = rising.cutJump();
      expect(cut.velocity, closeTo(rising.velocity * 0.45, 0.001));
    });

    test('下落时松键不改变速度', () {
      const falling = RiderMotion(height: 40, velocity: -200, jumps: 1);
      expect(falling.cutJump().velocity, -200);
    });

    test('俯身时下落更快', () {
      const falling = RiderMotion(height: 80, velocity: -100, jumps: 1);
      final normal = falling.step(0.1);
      final ducking = falling.withDucking(true).step(0.1);
      expect(ducking.height, lessThan(normal.height));
    });
  });

  group('碰撞盒', () {
    test('俯身降低身体高度', () {
      expect(RiderMotion.grounded.bodyHeight, RiderMotion.standingHeight);
      expect(
        RiderMotion.grounded.withDucking(true).bodyHeight,
        RiderMotion.duckHeight,
      );
    });

    test('顶部高度随离地高度增加', () {
      const rider = RiderMotion(height: 30);
      expect(rider.top, 30 + RiderMotion.standingHeight);
    });

    test('空中状态判定', () {
      expect(RiderMotion.grounded.airborne, isFalse);
      expect(const RiderMotion(height: 1).airborne, isTrue);
      expect(const RiderMotion(velocity: 10).airborne, isTrue);
    });
  });
}
