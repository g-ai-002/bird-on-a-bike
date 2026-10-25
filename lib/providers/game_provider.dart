import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../game/collision.dart';
import '../game/spawn_patterns.dart';
import '../game/world_layout.dart';
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
  double _persistCooldown = 0;

  /// 实体列表双缓冲：每帧只清空并复用另一份，避免周期性分配列表。
  final List<Obstacle> _obstacleBufferA = <Obstacle>[];
  final List<Obstacle> _obstacleBufferB = <Obstacle>[];
  final List<Pickup> _pickupBufferA = <Pickup>[];
  final List<Pickup> _pickupBufferB = <Pickup>[];

  int _entityRevision = 0;

  /// 实体集合的版本号：生成、拾取、回收或磁铁吸附改变深度时递增。
  ///
  /// 渲染层按深度排序的结果会缓存到这个值变化为止，省掉每帧的排序与拷贝。
  int get entityRevision => _entityRevision;

  /// 进度落盘的最小间隔（秒）。最高速时距离增长约 6 m/s，
  /// 逐帧比较会让写盘退化成每秒一次；节流后只在暂停/结算时补写一次。
  static const double _persistInterval = 15;

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
    _persistCooldown = 0;
    _entityRevision++;

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
    // 暂停时立即落盘，避免退出后丢掉最多一个节流周期的进度。
    _persistProgress(_state, force: true);
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

    _persistCooldown = max(0.0, _persistCooldown - dt);

    final s = _state;
    final ducking = _duckHeld || _duckTimer > 0;
    _duckTimer = max(0.0, _duckTimer - dt);
    final rider = s.rider.copyWith(ducking: ducking).step(dt);

    final speed =
        min(AppConstants.maxSpeed, s.speed + AppConstants.speedRampPerMeter * dt);
    final moved = speed * dt;
    final distance = s.distance + moved / WorldLayout.unitsPerMeter;

    // 实体原地推进：写入另一份缓冲列表，既不复制实体也不分配列表。
    var entitiesChanged = false;
    final obstacles = identical(s.obstacles, _obstacleBufferA)
        ? _obstacleBufferB
        : _obstacleBufferA;
    obstacles.clear();
    for (final obstacle in s.obstacles) {
      obstacle.moveBy(-moved);
      if (obstacle.isOffscreen) {
        entitiesChanged = true;
      } else {
        obstacles.add(obstacle);
      }
    }
    final pickups = identical(s.pickups, _pickupBufferA)
        ? _pickupBufferB
        : _pickupBufferA;
    pickups.clear();
    for (final pickup in s.pickups) {
      pickup.moveBy(-moved);
      if (pickup.isOffscreen) {
        entitiesChanged = true;
      } else {
        pickups.add(pickup);
      }
    }

    _nextObstacleIn -= dt;
    if (_nextObstacleIn <= 0 && obstacles.length < AppConstants.maxObstacles) {
      final kind = pickObstacleKind(_random);
      obstacles.add(
        Obstacle(
          id: _nextId++,
          kind: kind,
          x: WorldLayout.obstacleSpawnX,
          // z 默认 0，正是骑行者所在的骑行线，才能正面挡住单车。
        ),
      );
      _nextObstacleIn = obstacleGapForKind(
        obstacleGapSeconds(_random, s.difficulty),
        kind,
      );
      entitiesChanged = true;
    }

    _nextFishIn -= dt;
    if (_nextFishIn <= 0 &&
        pickups.length < AppConstants.maxPickups - 3) {
      final pattern = fishPattern(
        startId: _nextId,
        x: WorldLayout.fishSpawnX,
        z: pickDepth(_random),
        random: _random,
      );
      _nextId += pattern.length;
      pickups.addAll(pattern);
      _nextFishIn = fishGapSeconds(_random);
      entitiesChanged = true;
    }

    _nextPowerUpIn -= dt;
    if (_nextPowerUpIn <= 0 && pickups.length < AppConstants.maxPickups) {
      final kind = pickPowerUpKind(_random);
      pickups.add(
        Pickup(
          id: _nextId++,
          kind: kind,
          x: WorldLayout.powerUpSpawnX,
          y: 7 + _random.nextDouble() * 5,
          z: pickDepth(_random),
          phase: _random.nextDouble() * pi * 2,
        ),
      );
      _nextPowerUpIn = powerUpGapSeconds(_random);
      entitiesChanged = true;
    }

    var magnetRemaining = max(0.0, s.magnetRemaining - dt);
    if (magnetRemaining > 0) {
      // 吸附直接改写拾取物坐标，避免每帧再复制一份列表。
      for (final pickup in pickups) {
        if (_attract(pickup, rider, dt)) {
          entitiesChanged = true;
        }
      }
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

    // 倒序删除已拾取的物件，省掉一份 remaining 列表。
    for (var i = pickups.length - 1; i >= 0; i--) {
      final pickup = pickups[i];
      if (!pickupReached(pickup, rider)) continue;
      pickups.removeAt(i);
      entitiesChanged = true;
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

    var shieldBroke = false;
    var crashed = false;
    for (var i = obstacles.length - 1; i >= 0; i--) {
      final obstacle = obstacles[i];
      if (!riderHitsObstacle(obstacle, rider)) continue;
      if (invulnerable > 0) continue;
      if (shieldCharges > 0) {
        shieldCharges--;
        invulnerable = AppConstants.shieldInvulnerable;
        shieldBroke = true;
        if (audioEnabled) {
          AudioService().playShieldBreak();
        }
        LogService.info('护盾抵挡了 ${obstacle.kind.label}');
        obstacles.removeAt(i);
        entitiesChanged = true;
        continue;
      }
      crashed = true;
      break;
    }

    if (entitiesChanged) _entityRevision++;

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

  /// 把拾取物向骑行者吸附一步；返回是否真的改动了坐标（会改变深度排序）。
  bool _attract(Pickup pickup, RiderMotion rider, double dt) {
    final dx = WorldLayout.riderX - pickup.x;
    final targetHeight = rider.height + rider.bodyHeight / 2;
    final dy = targetHeight - pickup.y;
    final dz = WorldLayout.riderZ - pickup.z;
    final distance = sqrt(dx * dx + dy * dy + dz * dz);
    if (distance > AppConstants.magnetRange || distance < 0.1) return false;

    final step = min(AppConstants.magnetSpeed * dt, distance);
    pickup.moveBy(
      dx / distance * step,
      dy: pickup.y + dy / distance * step,
      dz: pickup.z + dz / distance * step,
    );
    return true;
  }

  /// 进度落盘：默认 15 秒最多写一次，避免高速骑行时反复写磁盘。
  void _persistProgress(GameState state, {bool force = false}) {
    if (!force && _persistCooldown > 0) return;
    var wrote = false;
    if (state.highScore > _persistedHigh) {
      _persistedHigh = state.highScore;
      _storage.setHighScore(state.highScore);
      wrote = true;
    }
    if (state.bestDistance > _persistedBest) {
      _persistedBest = state.bestDistance;
      _storage.setBestDistance(state.bestDistance);
      wrote = true;
    }
    if (wrote) _persistCooldown = _persistInterval;
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
