import 'package:bird_on_a_bike/models/difficulty.dart';
import 'package:bird_on_a_bike/models/game_state.dart';
import 'package:bird_on_a_bike/models/obstacle.dart';
import 'package:bird_on_a_bike/models/pickup.dart';
import 'package:bird_on_a_bike/models/rider_motion.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('GameState', () {
    test('默认状态为空闲且从零开始', () {
      const state = GameState();
      expect(state.status, GameStatus.idle);
      expect(state.distance, 0);
      expect(state.score, 0);
      expect(state.fish, 0);
      expect(state.combo, 1);
      expect(state.obstacles, isEmpty);
      expect(state.pickups, isEmpty);
      expect(state.difficulty, Difficulty.normal);
    });

    test('总分 = 距离取整 + 小鱼加成', () {
      const state = GameState(distance: 123.8, bonusScore: 40);
      expect(state.score, 163);
    });

    test('copyWith 保留未修改字段', () {
      const original = GameState(
        status: GameStatus.playing,
        distance: 10,
        bonusScore: 20,
        fish: 2,
        highScore: 100,
      );
      final copy = original.copyWith(distance: 12.5);
      expect(copy.distance, 12.5);
      expect(copy.bonusScore, 20);
      expect(copy.fish, 2);
      expect(copy.highScore, 100);
      expect(copy.status, GameStatus.playing);
    });

    test('护盾与磁铁状态', () {
      const state = GameState(shieldCharges: 1, magnetRemaining: 3);
      expect(state.hasShield, isTrue);
      expect(state.magnetActive, isTrue);
      expect(state.invulnerableActive, isFalse);
    });

    test('游戏状态判定', () {
      expect(const GameState().isIdle, isTrue);
      expect(
        const GameState(status: GameStatus.playing).isPlaying,
        isTrue,
      );
      expect(const GameState(status: GameStatus.paused).isPaused, isTrue);
      expect(const GameState(status: GameStatus.over).isOver, isTrue);
    });
  });

  group('Difficulty', () {
    test('难度越高初速度越大、障碍越密集', () {
      expect(
        Difficulty.easy.baseSpeed,
        lessThan(Difficulty.normal.baseSpeed),
      );
      expect(
        Difficulty.normal.baseSpeed,
        lessThan(Difficulty.hard.baseSpeed),
      );
      expect(
        Difficulty.easy.spawnScale,
        greaterThan(Difficulty.hard.spawnScale),
      );
    });

    test('每种难度都有标签与说明', () {
      for (final difficulty in Difficulty.values) {
        expect(difficulty.label, isNotEmpty);
        expect(difficulty.description, isNotEmpty);
      }
    });
  });

  group('实体模型', () {
    test('障碍移动与离屏判定', () {
      const obstacle = Obstacle(id: 1, kind: ObstacleKind.rock, x: 100);
      final moved = obstacle.moveBy(-50);
      expect(moved.x, 50);
      expect(moved.right, 50 + ObstacleKind.rock.width);
      expect(
        const Obstacle(id: 2, kind: ObstacleKind.rock, x: -200).isOffscreen,
        isTrue,
      );
    });

    test('悬空横幅有离地间隙', () {
      expect(ObstacleKind.banner.overhead, isTrue);
      expect(ObstacleKind.banner.clearance, greaterThan(0));
      expect(ObstacleKind.rock.overhead, isFalse);
      expect(ObstacleKind.rock.clearance, 0);
    });

    test('拾取物移动保留类型与高度', () {
      const pickup = Pickup(
        id: 3,
        kind: PickupKind.fish,
        x: 200,
        y: 60,
        phase: 1,
      );
      final moved = pickup.moveBy(-10);
      expect(moved.x, 190);
      expect(moved.y, 60);
      expect(moved.kind, PickupKind.fish);
    });
  });

  group('RiderMotion 常量', () {
    test('站立判定高于俯身判定', () {
      expect(
        RiderMotion.standingHeight,
        greaterThan(RiderMotion.duckHeight),
      );
      expect(RiderMotion.maxJumps, 2);
    });
  });
}
