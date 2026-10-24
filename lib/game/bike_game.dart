import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flame/input.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/game_state.dart';
import '../providers/game_provider.dart';
import '../services/audio_service.dart';
import '../utils/constants.dart';
import 'bike_world.dart';
import 'components/death_flash_component.dart';
import 'components/ground_component.dart';
import 'components/obstacle_component.dart';
import 'components/particle_burst_component.dart';
import 'components/pickup_component.dart';
import 'components/rider_component.dart';
import 'components/score_popup_layer.dart';
import 'components/speed_lines_component.dart';
import 'components/sky_component.dart';
import 'input/ride_input_component.dart';
import 'ride_style.dart';

/// 基于 Flame 的横版骑行游戏。
///
/// 规则、碰撞与计分都在 [GameProvider] 中；这里负责世界组装、
/// 输入分发、相机反馈与遮罩调度。
class BikeGame extends FlameGame<BikeWorld> with KeyboardEvents {
  BikeGame({required this.provider})
      : super(
          world: BikeWorld(),
          camera: CameraComponent.withFixedResolution(
            width: AppConstants.worldWidth,
            height: AppConstants.worldHeight,
          ),
        );

  static const String pauseOverlayId = 'pause';
  static const String countdownOverlayId = 'countdown';
  static const String gameOverOverlayId = 'gameOver';

  final GameProvider provider;

  /// 开局倒计时：3、2、1、0（0 显示 GO）。
  final ValueNotifier<int> countdown = ValueNotifier<int>(0);

  late final SkyComponent _sky;
  late final GroundComponent _ground;
  late final SpeedLinesComponent _speedLines;
  late final ObstacleComponent _obstacles;
  late final PickupComponent _pickups;
  late final RiderComponent _rider;
  late final ParticleBurstComponent _particles;
  late final DeathFlashComponent _flash;
  late final ScorePopupLayer _popups;
  late final RideInputComponent _input;

  final math.Random _random = math.Random();
  Vector2 _cameraBase = Vector2(
    AppConstants.worldWidth / 2,
    AppConstants.worldHeight / 2,
  );

  bool _ready = false;
  GameStatus _lastStatus = GameStatus.idle;

  double _zoomPulse = 0;
  double _zoomStrength = 0.02;
  double _shakeRemaining = 0;
  double _flashRemaining = 0;
  double _slowMotionRemaining = 0;

  bool _countdownActive = false;
  double _countdownRemaining = 0;
  double _goRemaining = 0;
  int _lastTickValue = -1;

  bool _gameOverOverlayPending = false;
  double _gameOverOverlayDelay = 0;

  static const double _zoomDuration = 0.28;
  static const double _shakeDuration = 0.45;
  static const double _flashDuration = 0.3;
  static const double _slowMotionDuration = 0.45;
  static const double _slowMotionScale = 0.35;
  static const double _countdownSeconds = 3.0;

  @override
  Color backgroundColor() => RideColors.skyTop;

  @override
  Future<void> onLoad() async {
    _sky = SkyComponent(provider: provider, priority: 0);
    _ground = GroundComponent(provider: provider, priority: 10);
    _speedLines = SpeedLinesComponent(provider: provider, priority: 12);
    _obstacles = ObstacleComponent(provider: provider, priority: 20);
    _pickups = PickupComponent(provider: provider, priority: 30);
    _rider = RiderComponent(provider: provider, priority: 40);
    _particles = ParticleBurstComponent(provider: provider, priority: 50);
    _flash = DeathFlashComponent(provider: provider, priority: 60);
    _popups = ScorePopupLayer(color: RideColors.fish);
    _input = RideInputComponent(
      onJump: _onJump,
      onDuck: _onDuckSwipe,
      priority: 100,
    );

    await world.addAll(<Component>[
      _sky,
      _ground,
      _speedLines,
      _obstacles,
      _pickups,
      _rider,
      _particles,
      _flash,
      _input,
      _popups,
    ]);

    camera.viewfinder.position = _cameraBase;
    camera.viewfinder.zoom = 1;
    _ready = true;
  }

  @override
  KeyEventResult onKeyEvent(
    KeyEvent event,
    Set<LogicalKeyboardKey> keysPressed,
  ) {
    final key = event.logicalKey;
    final isDown = event is KeyDownEvent;
    final isUp = event is KeyUpEvent;

    if (isDown) {
      if (key == LogicalKeyboardKey.space ||
          key == LogicalKeyboardKey.arrowUp ||
          key == LogicalKeyboardKey.keyW ||
          key == LogicalKeyboardKey.keyZ) {
        _onJump();
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.arrowDown ||
          key == LogicalKeyboardKey.keyS ||
          key == LogicalKeyboardKey.controlLeft ||
          key == LogicalKeyboardKey.controlRight) {
        _onDuckDown();
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.keyP ||
          key == LogicalKeyboardKey.escape) {
        provider.togglePause();
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.keyR ||
          key == LogicalKeyboardKey.enter) {
        if (provider.isOver || provider.isIdle) {
          provider.start();
          return KeyEventResult.handled;
        }
      }
      return KeyEventResult.ignored;
    }

    if (isUp) {
      if (key == LogicalKeyboardKey.space ||
          key == LogicalKeyboardKey.arrowUp ||
          key == LogicalKeyboardKey.keyW ||
          key == LogicalKeyboardKey.keyZ) {
        provider.releaseJump();
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.arrowDown ||
          key == LogicalKeyboardKey.keyS ||
          key == LogicalKeyboardKey.controlLeft ||
          key == LogicalKeyboardKey.controlRight) {
        provider.releaseDuck();
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  void _onJump() {
    if (!_ready || _countdownActive) return;
    provider.jump();
  }

  void _onDuckDown() {
    if (!_ready || _countdownActive) return;
    provider.holdDuck();
  }

  void _onDuckSwipe() {
    if (!_ready || _countdownActive) return;
    provider.duckFor(AppConstants.duckTouchSeconds);
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (!_ready) return;

    _updateSlowMotion(dt);
    final visualDt = _slowMotionRemaining > 0 ? dt * _slowMotionScale : dt;
    _updateCamera(visualDt);
    _updateFeedback(visualDt);
    _updateGameOverOverlay(dt);

    final status = provider.state.status;
    if (status != _lastStatus) {
      _handleStatusChange(status);
    }
    if (status != GameStatus.playing) return;

    if (_countdownActive) {
      _updateCountdown(dt);
      return;
    }

    final previous = provider.state;
    provider.advance(dt);
    _detectPickups(previous, provider.state);
  }

  void _handleStatusChange(GameStatus status) {
    final previous = _lastStatus;
    if (status == previous) return;
    _lastStatus = status;

    if (status == GameStatus.paused) {
      overlays.add(pauseOverlayId, priority: 20);
      return;
    }

    overlays.remove(pauseOverlayId);

    if (status == GameStatus.playing) {
      if (previous == GameStatus.idle || previous == GameStatus.over) {
        _resetForNewGame();
        _startCountdown();
      }
      return;
    }

    if (status == GameStatus.over) {
      _triggerCrash();
      return;
    }

    if (status == GameStatus.idle) {
      _countdownActive = false;
      countdown.value = 0;
      overlays.remove(countdownOverlayId);
      overlays.remove(gameOverOverlayId);
    }
  }

  void _resetForNewGame() {
    _particles.clear();
    _popups.clear();
    _flash.opacity = 0;
    _flashRemaining = 0;
    _shakeRemaining = 0;
    _zoomPulse = 0;
    _zoomStrength = 0.02;
    _slowMotionRemaining = 0;
    world.timeScale = 1;
    _cameraBase = Vector2(
      AppConstants.worldWidth / 2,
      AppConstants.worldHeight / 2,
    );
    camera.viewfinder.position = _cameraBase;
    camera.viewfinder.zoom = 1;
    _countdownActive = false;
    countdown.value = 0;
    _lastTickValue = -1;
    _gameOverOverlayPending = false;
    overlays.remove(gameOverOverlayId);
    overlays.remove(countdownOverlayId);
  }

  void _startCountdown() {
    _countdownActive = true;
    _countdownRemaining = _countdownSeconds;
    _goRemaining = 0;
    countdown.value = 3;
    _lastTickValue = 3;
    overlays.add(countdownOverlayId, priority: 10);
  }

  void _updateCountdown(double dt) {
    if (_countdownRemaining > 0) {
      _countdownRemaining -= dt;
      final value = _countdownRemaining.ceil().clamp(1, 3).toInt();
      if (countdown.value != value) {
        countdown.value = value;
      }
      if (_countdownRemaining <= 0) {
        _goRemaining = 0.45;
        countdown.value = 0;
      }
      _playTick(countdown.value);
      return;
    }

    _playTick(0);
    _goRemaining -= dt;
    if (_goRemaining <= 0) {
      _countdownActive = false;
      overlays.remove(countdownOverlayId);
    }
  }

  void _playTick(int value) {
    if (!provider.audioEnabled) return;
    if (value == _lastTickValue) return;
    _lastTickValue = value;
    AudioService().playTick();
  }

  void _triggerCrash() {
    _countdownActive = false;
    countdown.value = 0;
    overlays.remove(countdownOverlayId);
    _slowMotionRemaining = _slowMotionDuration;
    world.timeScale = _slowMotionScale;
    _zoomPulse = 1;
    _zoomStrength = 0.055;
    _shakeRemaining = _shakeDuration;
    _flashRemaining = _flashDuration;
    _gameOverOverlayPending = true;
    _gameOverOverlayDelay = 0.7;
  }

  void _detectPickups(GameState previous, GameState next) {
    final head = Vector2(
      AppConstants.riderX,
      AppConstants.groundY - next.rider.height - 118,
    );

    if (next.fish > previous.fish) {
      _particles.burst(head, color: RideColors.fish, count: 10, spread: 150);
      final gain = next.bonusScore - previous.bonusScore;
      _popups.show(
        head + Vector2(0, -20),
        next.combo > 1 ? '+$gain ×${next.combo}' : '+$gain',
        color: RideColors.fish,
        fontSize: next.combo > 1 ? 21.0 : 18.0,
      );
    }

    if (next.shieldCharges > previous.shieldCharges) {
      _particles.burst(head, color: RideColors.shield, count: 16);
      _popups.show(
        head + Vector2(0, -20),
        '护盾 +1',
        color: RideColors.shield,
      );
    }

    if (next.magnetRemaining > previous.magnetRemaining + 0.5) {
      _particles.burst(head, color: RideColors.magnet, count: 16);
      _popups.show(
        head + Vector2(0, -20),
        '磁铁',
        color: RideColors.magnet,
      );
    }

    if (next.shieldCharges < previous.shieldCharges) {
      _particles.burst(head, color: RideColors.shield, count: 20);
      _popups.show(
        head + Vector2(0, -20),
        '护盾破碎',
        color: RideColors.shield,
      );
      _shakeRemaining = 0.22;
    }
  }

  void _updateSlowMotion(double dt) {
    if (_slowMotionRemaining <= 0) {
      if (world.timeScale != 1.0) {
        world.timeScale = 1.0;
      }
      return;
    }
    _slowMotionRemaining = math.max(0.0, _slowMotionRemaining - dt);
    world.timeScale = _slowMotionRemaining > 0 ? _slowMotionScale : 1.0;
  }

  void _updateCamera(double dt) {
    _zoomPulse = math.max(0.0, _zoomPulse - dt / _zoomDuration);
    final eased = 1 - (1 - _zoomPulse) * (1 - _zoomPulse);
    camera.viewfinder.zoom = 1 + _zoomStrength * eased;

    if (_shakeRemaining > 0) {
      _shakeRemaining = math.max(0.0, _shakeRemaining - dt);
      final strength = 9 * (_shakeRemaining / _shakeDuration);
      camera.viewfinder.position = Vector2(
        _cameraBase.x + (_random.nextDouble() * 2 - 1) * strength,
        _cameraBase.y + (_random.nextDouble() * 2 - 1) * strength,
      );
    } else {
      camera.viewfinder.position = _cameraBase;
    }
  }

  void _updateFeedback(double dt) {
    if (_flashRemaining <= 0) return;
    _flashRemaining = math.max(0.0, _flashRemaining - dt);
    _flash.opacity = 0.42 * (_flashRemaining / _flashDuration);
  }

  void _updateGameOverOverlay(double dt) {
    if (!_gameOverOverlayPending) return;
    _gameOverOverlayDelay -= dt;
    if (_gameOverOverlayDelay <= 0) {
      _gameOverOverlayPending = false;
      overlays.add(gameOverOverlayId, priority: 20);
    }
  }
}
