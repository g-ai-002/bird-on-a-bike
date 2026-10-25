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
import 'components/particle_burst_component.dart';
import 'components/ride_entities_component.dart';
import 'components/road_component.dart';
import 'components/score_popup_layer.dart';
import 'components/sea_life_component.dart';
import 'components/shore_foreground_component.dart';
import 'components/sky_backdrop_component.dart';
import 'components/speed_lines_component.dart';
import 'components/vignette_component.dart';
import 'components/wheel_spray_component.dart';
import 'cover_camera.dart';
import 'input/ride_gesture_layer.dart';
import 'ride_style.dart';
import 'world_layout.dart';

/// 基于 Flame 主循环的 2.5D 海岸骑行游戏。
///
/// 规则、碰撞与计分都在 [GameProvider] 中；画面由远景视差、等距路面、
/// 精灵堆叠的实体层与屏幕空间特效叠成，不再依赖 Flutter GPU。
class BikeGame extends FlameGame<BikeWorld> with KeyboardEvents {
  BikeGame({required this.provider})
      : super(
          world: BikeWorld(),
          camera: CameraComponent(),
        );

  static const String pauseOverlayId = 'pause';
  static const String countdownOverlayId = 'countdown';
  static const String gameOverOverlayId = 'gameOver';

  final GameProvider provider;

  /// 开局倒计时：3、2、1、0（0 显示 GO）。
  final ValueNotifier<int> countdown = ValueNotifier<int>(0);

  late final SpeedLinesComponent _speedLines;
  late final ParticleBurstComponent _particles;
  late final DeathFlashComponent _flash;
  late final ScorePopupLayer _popups;
  late final WheelSprayComponent _spray;
  late final RideGestureLayer _gestures;

  final math.Random _random = math.Random();
  Vector2 _cameraBase = Vector2(
    AppConstants.worldWidth / 2,
    AppConstants.worldHeight / 2,
  );

  /// 把 800×450 的世界铺满画布所需的缩放（cover）。
  double _baseZoom = 1;

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
    _speedLines = SpeedLinesComponent(provider: provider, priority: 12);
    _particles = ParticleBurstComponent(provider: provider, priority: 50);
    _flash = DeathFlashComponent(provider: provider, priority: 60);
    _popups = ScorePopupLayer(color: RideColors.fish);
    _spray = WheelSprayComponent(provider: provider, priority: 9);

    final scene = <Component>[
      SkyBackdropComponent(provider: provider, priority: -50),
      SeaLifeComponent(provider: provider, priority: -45),
      RoadComponent(provider: provider, priority: -40),
      RideEntitiesComponent(provider: provider, priority: 0),
      ShoreForegroundComponent(provider: provider, priority: 6),
      VignetteComponent(priority: 8),
      _spray,
      _speedLines,
      _particles,
      _flash,
      _popups,
    ];

    await world.addAll(scene);

    // 手势层挂在 viewport 上：画布任意位置都能收到点击、上滑与下滑，
    // 且不受取景器 cover 缩放影响。
    _gestures = RideGestureLayer(
      onJump: _onJump,
      onDuck: _onDuckSwipe,
      priority: 100,
    );
    camera.viewport.add(_gestures);

    _updateBaseZoom(size);
    camera.viewfinder.position = _cameraBase;
    camera.viewfinder.zoom = _baseZoom;
    _ready = true;
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    _updateBaseZoom(size);
    camera.viewfinder.position = _cameraBase;
    camera.viewfinder.zoom = _baseZoom;
  }

  void _updateBaseZoom(Vector2 canvasSize) {
    _baseZoom = coverZoom(
      Size(canvasSize.x, canvasSize.y),
      const Size(AppConstants.worldWidth, AppConstants.worldHeight),
    );
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
    _spray.clear();
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
    camera.viewfinder.zoom = _baseZoom;
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
      WorldLayout.screenX(WorldLayout.riderX),
      WorldLayout.screenY(next.rider.height + 11.8),
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
    camera.viewfinder.zoom = _baseZoom * (1 + _zoomStrength * eased);

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
