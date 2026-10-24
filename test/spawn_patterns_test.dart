import 'dart:math';

import 'package:bird_on_a_bike/game/spawn_patterns.dart';
import 'package:bird_on_a_bike/models/difficulty.dart';
import 'package:bird_on_a_bike/models/obstacle.dart';
import 'package:bird_on_a_bike/models/pickup.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('障碍节奏', () {
    test('间隔落在设计区间内并受难度影响', () {
      for (final difficulty in Difficulty.values) {
        for (var seed = 0; seed < 20; seed++) {
          final gap = obstacleGapSeconds(Random(seed), difficulty);
          expect(gap, greaterThanOrEqualTo(1.05 * difficulty.spawnScale));
          expect(gap, lessThanOrEqualTo(1.8 * difficulty.spawnScale));
        }
      }
      final easy =
          obstacleGapSeconds(Random(1), Difficulty.easy) / Difficulty.easy.spawnScale;
      final hard =
          obstacleGapSeconds(Random(1), Difficulty.hard) / Difficulty.hard.spawnScale;
      expect(easy, closeTo(hard, 1e-9));
    });

    test('悬空横幅的间隔更长', () {
      expect(
        obstacleGapForKind(1.0, ObstacleKind.banner),
        greaterThan(obstacleGapForKind(1.0, ObstacleKind.rock)),
      );
    });

    test('障碍种类覆盖地面三种与横幅', () {
      final kinds = <ObstacleKind>{};
      for (var seed = 0; seed < 120; seed++) {
        kinds.add(pickObstacleKind(Random(seed)));
      }
      expect(kinds, contains(ObstacleKind.rock));
      expect(kinds, contains(ObstacleKind.crate));
      expect(kinds, contains(ObstacleKind.log));
      expect(kinds, contains(ObstacleKind.banner));
    });

    test('道具种类为护盾或磁铁', () {
      for (var seed = 0; seed < 20; seed++) {
        expect(
          pickPowerUpKind(Random(seed)),
          anyOf(PickupKind.shield, PickupKind.magnet),
        );
      }
    });
  });

  group('鱼群', () {
    test('数量为 1~3 且 id 连续、横向间距 36', () {
      for (var seed = 0; seed < 40; seed++) {
        final fish = fishPattern(
          startId: 10,
          x: 700,
          random: Random(seed),
        );
        expect(fish.length, inInclusiveRange(1, 3));
        for (var i = 0; i < fish.length; i++) {
          expect(fish[i].kind, PickupKind.fish);
          expect(fish[i].id, 10 + i);
          expect(fish[i].x, 700 + i * 36);
          expect(fish[i].y, inInclusiveRange(34, 170));
        }
      }
    });

    test('鱼群间隔在 1.3~2.5 秒之间', () {
      for (var seed = 0; seed < 30; seed++) {
        final gap = fishGapSeconds(Random(seed));
        expect(gap, greaterThanOrEqualTo(1.3));
        expect(gap, lessThanOrEqualTo(2.5));
      }
    });

    test('道具间隔在 17~25 秒之间', () {
      for (var seed = 0; seed < 30; seed++) {
        final gap = powerUpGapSeconds(Random(seed));
        expect(gap, greaterThanOrEqualTo(17));
        expect(gap, lessThanOrEqualTo(25));
      }
    });
  });
}
