import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../game/collision.dart';
import '../game/spawn_patterns.dart';
import '../models/difficulty.dart';
import '../models/game_state.dart';
import '../models/obstacle.dart';
import '../models/pickup.dart';
import '../models/rider_motion.dart';
import '../services/audio_service.dart';
import '../services/leaderboard_service.dart';
import '../services/log_service.dart';
import '../services/storage_service.dart';
import '../utils/constants.dart';

/// 骑行规则与状态：速度、跳跃、生成、碰撞与计分都在这里，
/// Flame 只负责按快照渲染，Flutter 页面只负责展示与输入转发。
class GameProvider extends ChangeNotifier {
  GameProvider(
    this._storage, {
    Random? random,
    this.audioEnabled = true,
    Future<void> Function(int score)? scoreSink,
  })  : _random = random ?? Random(),
        _scoreSink = scoreSink,
        _difficulty = _storage.difficulty,
        _state = GameState(
          difficulty: _storage.difficulty,
          highScore: _storage.highScore,
          bestDistance: _storage.bestDistance,
          speed: _storage.difficulty.baseSpeed,
        ) {
    _persistedHigh = _state.highScore;
    _persistedBest = _state.bestDistance;
  }

  final StorageService _storage;
  final Random _random;
  final bool audioEnabled;
  final Future<void> Function(int score)? _scoreSink;

  GameState _state;
  Difficulty _difficulty;

  int _nextId = 1;
  double _nextObstacleIn = 0;
  double _nextFishIn = 0;
  double _nextPowerUpIn = 0;
  double _duckTimer = 0;
  bool _duckHeld = false;
  double _notifyAccumulator = 0;
  int _persistedHigh = 0;
  double _persistedBest = 0;

  GameState get state => _state;
  Difficulty get difficulty => _difficulty;

  bool get isPlaying => _state.isPlaying;
  bool get isPaused => _state.isPaused;
  bool get isOver => _state.isOver;
  bool get isIdle => _state.isIdle;

  /// 切换难度，下一局从新难度开始；当前局同步初速度。
  void setDifficulty(Difficulty value) {
    if (_difficulty == value) return;
    _difficulty = value;
    _state = _state.copyWith(difficulty: value, speed: value.baseSpeed);
    notifyListeners();
  }

  void start() {
    LogService.info('骑行开始, 难度: ${_difficulty.label}');
    _nextId = 1;
    _nextObstacleIn = 1.7;
    _nextFishIn = 0.9;
    _nextPowerUpIn = 14 + _random.nextDouble() * 6;
    _duckHeld = false;
    _duckTimer = 0;
    _notifyAccumulator = 0;

    _state = GameState(
      status: GameStatus.playing,
      difficulty: _difficulty,
      highScore: _state.highScore,
      bestDistance: _state.bestDistance,
      speed: _difficulty.baseSpeed,
    );
    notifyListeners();
  }

  void pause() {
    if (!_state.isPlaying) return;
    LogService.info('骑行暂停');
    _state = _state.copyWith(status: GameStatus.paused);
    notifyListeners();
  }

  void resume() {
    if (!_state.isPaused) return;
    LogService.info('骑行继续');
    _state = _state.copyWith(status: GameStatus.playing);
    notifyListeners();
  }

  void togglePause() {
    if (_state.isPlaying) {
      pause();
    } else if (_state.isPaused) {
      resume();
    }
  }

  /// 起跳或二段跳；触屏点击与键盘空格都走这里。
  void jump() {
    if (!_state.isPlaying) return;
    final next = _state.rider.jump();
    if (next.jumps == _state.rider.jumps) return;
    _duckHeld = false;
    _duckTimer = 0;
    _state = _state.copyWith(rider: next);
    if (audioEnabled) {
      AudioService().playJump(doubleJump: next.jumps > 1);
    }
    notifyListeners();
  }

  /// 松开跳跃键，截断上升速度以获得更矮的跳跃。
  void releaseJump() {
    if (!_state.isPlaying) return;
    final next = _state.rider.cutJump();
    if (next.velocity == _state.rider.velocity) return;
    _state = _state.copyWith(rider: next);
  }

  /// 键盘按住下蹲。
  void holdDuck() {
    if (!_state.isPlaying) return;
    _duckHeld = true;
    _duckTimer = 0;
    _syncDucking();
  }

  void releaseDuck() {
    if (!_duckHeld) return;
    _duckHeld = false;
    _syncDucking();
  }

  /// 触屏下滑：保持一段时间的俯身。
  void duckFor(double seconds) {
    if (!_state.isPlaying) return;
    _duckTimer = max(_duckTimer, seconds);
    _syncDucking();
  }

  void _syncDucking() {
    final wanted = _duckHeld || _duckTimer > 0;
    if (_state.rider.ducking == wanted) return;
    _state = _state.copyWith(rider: _state.rider.withDucking(wanted));
    notifyListeners();
  }

  /// 推进一帧。由 BikeGame 在倒计时结束后按真实帧时间调用。
  void advance(double dt) {
    if (!_state.isPlaying || dt <= 0) return;
    // 窗口拖动或后台恢复可能产生超大帧间隔，限制步长避免瞬移穿模。
    if (dt > 0.05) dt = 0.05;

    final s = _state;
    final ducking = _duckHeld || _duckTimer > 0;
    _duckTimer = max(0.0, _duckTimer - dt);
    final rider = s.rider.copyWith(ducking: ducking).step(dt);

    final speed =
        min(AppConstants.maxSpeed, s.speed + AppConstants.speedRampPerMeter * dt);
    final moved = speed * dt;
    final distance = s.distance + moved / 10;

    var obstacles = <Obstacle>[
      for (final obstacle in s.obstacles) obstacle.moveBy(-moved),
    ]..removeWhere((obstacle) => obstacle.isOffscreen);
    var pickups = <Pickup>[
      for (final pickup in s.pickups) pickup.moveBy(-moved),
    ]..removeWhere((pickup) => pickup.isOffscreen);

    _nextObstacleIn -= dt;
    if (_nextObstacleIn <= 0 && obstacles.length < AppConstants.maxObstacles) {
      final kind = pickObstacleKind(_random);
      obstacles.add(
        Obstacle(
          id: _nextId++,
          kind: kind,
          x: AppConstants.worldWidth + 70,
        ),
      );
      _nextObstacleIn = obstacleGapForKind(
        obstacleGapSeconds(_random, s.difficulty),
        kind,
      );
    }

    _nextFishIn -= dt;
    if (_nextFishIn <= 0 &&
        pickups.length < AppConstants.maxPickups - 3) {
      final pattern = fishPattern(
        startId: _nextId,
        x: AppConstants.worldWidth + 100,
        random: _random,
      );
      _nextId += pattern.length;
      pickups.addAll(pattern);
      _nextFishIn = fishGapSeconds(_random);
    }

    _nextPowerUpIn -= dt;
    if (_nextPowerUpIn <= 0 && pickups.length < AppConstants.maxPickups) {
      final kind = pickPowerUpKind(_random);
      pickups.add(
        Pickup(
          id: _nextId++,
          kind: kind,
          x: AppConstants.worldWidth + 120,
          y: 70 + _random.nextDouble() * 50,
          phase: _random.nextDouble() * pi * 2,
        ),
      );
      _nextPowerUpIn = powerUpGapSeconds(_random);
    }

    var magnetRemaining = max(0.0, s.magnetRemaining - dt);
    if (magnetRemaining > 0) {
      pickups = [
        for (final pickup in pickups) _attract(pickup, rider, dt),
      ];
    }

    var fish = s.fish;
    var bonusScore = s.bonusScore;
    var combo = s.combo;
    var comboTimer = max(0.0, s.comboTimer - dt);
    if (comboTimer == 0) {
      combo = 1;
    }
    var shieldCharges = s.shieldCharges;
    var invulnerable = max(0.0, s.invulnerable - dt);
    var caughtFish = 0;
    var pickedPowerUp = false;

    final remainingPickups = <Pickup>[];
    for (final pickup in pickups) {
      if (!pickupReached(pickup, rider)) {
        remainingPickups.add(pickup);
        continue;
      }
      if (pickup.kind == PickupKind.fish) {
        caughtFish++;
        fish++;
        combo = comboTimer > 0
            ? min(AppConstants.maxCombo, combo + 1)
            : 1;
        comboTimer = AppConstants.comboWindow;
        bonusScore += AppConstants.fishBaseScore * combo;
        if (audioEnabled) {
          AudioService().playFish(combo);
        }
      } else if (pickup.kind == PickupKind.shield) {
        shieldCharges = min(2, shieldCharges + 1);
        pickedPowerUp = true;
        if (audioEnabled) {
          AudioService().playPowerUp();
        }
      } else {
        magnetRemaining = max(magnetRemaining, AppConstants.magnetDuration);
        pickedPowerUp = true;
        if (audioEnabled) {
          AudioService().playPowerUp();
        }
      }
    }
    pickups = remainingPickups;

    var shieldBroke = false;
    var crashed = false;
    final survivors = <Obstacle>[];
    for (final obstacle in obstacles) {
      if (!riderHitsObstacle(obstacle, rider)) {
        survivors.add(obstacle);
        continue;
      }
      if (invulnerable > 0) {
        survivors.add(obstacle);
        continue;
      }
      if (shieldCharges > 0) {
        shieldCharges--;
        invulnerable = AppConstants.shieldInvulnerable;
        shieldBroke = true;
        if (audioEnabled) {
          AudioService().playShieldBreak();
        }
        LogService.info('护盾抵挡了 ${obstacle.kind.label}');
        continue;
      }
      crashed = true;
      break;
    }
    if (!crashed) {
      obstacles = survivors;
    }

    final score = distance.floor() + bonusScore;
    final highScore = max(s.highScore, score);
    final bestDistance = max(s.bestDistance, distance);

    final next = s.copyWith(
      distance: distance,
      bonusScore: bonusScore,
      fish: fish,
      highScore: highScore,
      bestDistance: bestDistance,
      speed: speed,
      rider: rider,
      shieldCharges: shieldCharges,
      magnetRemaining: magnetRemaining,
      invulnerable: invulnerable,
      combo: combo,
      comboTimer: comboTimer,
      obstacles: obstacles,
      pickups: pickups,
    );
    _state = next;
    _persistProgress(next);

    if (crashed) {
      _finishRun(next);
      return;
    }

    _notifyAccumulator += dt;
    if (caughtFish > 0 ||
        pickedPowerUp ||
        shieldBroke ||
        _notifyAccumulator >= AppConstants.notifyInterval) {
      _notifyAccumulator = 0;
      notifyListeners();
    }
  }

  Pickup _attract(Pickup pickup, RiderMotion rider, double dt) {
    final dx = AppConstants.riderX - pickup.x;
    final targetHeight = rider.height + rider.bodyHeight / 2;
    final dy = targetHeight - pickup.y;
    final distance = sqrt(dx * dx + dy * dy);
    if (distance > AppConstants.magnetRange || distance < 1) return pickup;

    final step = min(AppConstants.magnetSpeed * dt, distance);
    return pickup.moveBy(
      dx / distance * step,
      dy: pickup.y + dy / distance * step,
    );
  }

  void _persistProgress(GameState state) {
    if (state.highScore > _persistedHigh + 4) {
      _persistedHigh = state.highScore;
      _storage.setHighScore(state.highScore);
    }
    if (state.bestDistance > _persistedBest + 5) {
      _persistedBest = state.bestDistance;
      _storage.setBestDistance(state.bestDistance);
    }
  }

  void _finishRun(GameState last) {
    final score = last.score;
    final highScore = max(last.highScore, score);
    final bestDistance = max(last.bestDistance, last.distance);

    if (audioEnabled) {
      AudioService().playCrash();
    }
    LogService.info(
      '骑行结束: 距离 ${last.distance.toStringAsFixed(0)}m, '
      '得分 $score, 小鱼 ${last.fish}',
    );

    _persistedHigh = highScore;
    _persistedBest = bestDistance;
    _storage.setHighScore(highScore);
    _storage.setBestDistance(bestDistance);

    final sink = _scoreSink ?? LeaderboardService.addScore;
    unawaited(_recordScore(sink, score));

    _state = last.copyWith(
      status: GameStatus.over,
      highScore: highScore,
      bestDistance: bestDistance,
      shieldCharges: 0,
      magnetRemaining: 0,
      invulnerable: 0,
      combo: 1,
      comboTimer: 0,
    );
    notifyListeners();
  }

  Future<void> _recordScore(
    Future<void> Function(int score) sink,
    int score,
  ) async {
    try {
      await sink(score);
    } catch (e) {
      LogService.warning('成绩写入失败: $e');
    }
  }
}
