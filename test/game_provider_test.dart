import 'dart:math';

import 'package:bird_on_a_bike/models/difficulty.dart';
import 'package:bird_on_a_bike/models/game_state.dart';
import 'package:bird_on_a_bike/providers/game_provider.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes/fake_storage.dart';

void main() {
  test('从存储恢复最高分与最远距离', () async {
    final storage = FakeStorageService.create();
    await storage.setHighScore(42);
    await storage.setBestDistance(120);
    final game = GameProvider(storage, audioEnabled: false);

    expect(game.state.highScore, 42);
    expect(game.state.bestDistance, 120);
    expect(game.isIdle, isTrue);
  });

  test('选择难度后开局使用对应初速度', () async {
    final storage = FakeStorageService.create();
    final game = GameProvider(storage, audioEnabled: false);

    game.setDifficulty(Difficulty.hard);
    game.start();

    expect(game.isPlaying, isTrue);
    expect(game.state.difficulty, Difficulty.hard);
    expect(game.state.speed, Difficulty.hard.baseSpeed);
    expect(game.state.distance, 0);
  });

  test('最多两段跳，暂停时无法起跳', () async {
    final storage = FakeStorageService.create();
    final game = GameProvider(storage, audioEnabled: false);
    game.start();

    game.jump();
    expect(game.state.rider.jumps, 1);
    game.jump();
    expect(game.state.rider.jumps, 2);
    game.jump();
    expect(game.state.rider.jumps, 2);

    game.pause();
    game.jump();
    expect(game.state.rider.jumps, 2);
  });

  test('松开跳跃键会截断上升速度', () async {
    final storage = FakeStorageService.create();
    final game = GameProvider(storage, audioEnabled: false);
    game.start();

    game.jump();
    final velocity = game.state.rider.velocity;
    game.releaseJump();
    expect(game.state.rider.velocity, lessThan(velocity));
  });

  test('触屏俯身在一段时间后自动结束', () async {
    final storage = FakeStorageService.create();
    final game = GameProvider(storage, audioEnabled: false);
    game.start();

    game.duckFor(0.3);
    expect(game.state.rider.ducking, isTrue);

    for (var i = 0; i < 30; i++) {
      game.advance(1 / 60);
    }
    expect(game.state.rider.ducking, isFalse);
  });

  test('推进后距离与速度增长，并生成障碍和鱼', () async {
    final storage = FakeStorageService.create();
    final game = GameProvider(
      storage,
      random: Random(3),
      audioEnabled: false,
      scoreSink: (_) async {},
    );
    game.start();
    final baseSpeed = game.state.speed;

    for (var i = 0; i < 150; i++) {
      game.advance(1 / 60);
    }

    expect(game.state.distance, greaterThan(0));
    expect(game.state.speed, greaterThan(baseSpeed));
    expect(game.state.obstacles, isNotEmpty);
    expect(
      game.state.pickups.isNotEmpty || game.state.fish > 0,
      isTrue,
    );
  });

  test('不操作时最终会撞上障碍并结算', () async {
    final storage = FakeStorageService.create();
    int? recorded;
    final game = GameProvider(
      storage,
      random: Random(7),
      audioEnabled: false,
      scoreSink: (score) async {
        recorded = score;
      },
    );
    game.start();

    for (var i = 0; i < 60 * 40 && game.isPlaying; i++) {
      game.advance(1 / 60);
    }

    expect(game.isOver, isTrue);
    expect(game.state.score, greaterThan(0));
    expect(recorded, isNotNull);
    expect(recorded, game.state.score);
    expect(storage.highScore, greaterThan(0));
    expect(storage.bestDistance, greaterThan(0));
  });

  test('结束后状态冻结', () async {
    final storage = FakeStorageService.create();
    final game = GameProvider(
      storage,
      random: Random(11),
      audioEnabled: false,
      scoreSink: (_) async {},
    );
    game.start();
    for (var i = 0; i < 60 * 40 && game.isPlaying; i++) {
      game.advance(1 / 60);
    }
    expect(game.isOver, isTrue);

    final distance = game.state.distance;
    game.advance(1.0);
    game.jump();
    expect(game.state.distance, distance);
    expect(game.state.rider.jumps, 0);
  });

  test('暂停时 advance 不推进', () async {
    final storage = FakeStorageService.create();
    final game = GameProvider(storage, audioEnabled: false);
    game.start();
    final distance = game.state.distance;
    game.pause();

    game.advance(1.0);
    expect(game.state.distance, distance);

    game.resume();
    game.advance(1.0);
    expect(game.state.distance, greaterThan(distance));
  });

  test('状态切换通知与状态枚举一致', () async {
    final storage = FakeStorageService.create();
    final game = GameProvider(storage, audioEnabled: false);
    expect(game.state.status, GameStatus.idle);

    game.start();
    expect(game.state.status, GameStatus.playing);
    game.togglePause();
    expect(game.state.status, GameStatus.paused);
    game.togglePause();
    expect(game.state.status, GameStatus.playing);
  });
}
