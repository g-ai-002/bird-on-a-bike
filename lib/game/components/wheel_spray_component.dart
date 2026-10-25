import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';

import '../../providers/game_provider.dart';
import '../../utils/constants.dart';
import '../world_layout.dart';

/// 后轮扬起的水雾：纯屏幕空间粒子，不参与 3D 渲染。
class WheelSprayComponent extends PositionComponent {
  WheelSprayComponent({required this.provider, super.priority})
    : super(
        position: Vector2.zero(),
        size: Vector2(AppConstants.worldWidth, AppConstants.worldHeight),
      );

  final GameProvider provider;
  final math.Random _random = math.Random();
  final List<_Drop> _drops = [];
  final Paint _paint = Paint();

  double _emitAccumulator = 0;

  void clear() {
    _drops.clear();
    _emitAccumulator = 0;
  }

  @override
  void update(double dt) {
    super.update(dt);
    final state = provider.state;
    if (state.isPlaying && dt > 0) {
      _emitAccumulator += dt * (6 + state.speed * 0.25);
      while (_emitAccumulator >= 1) {
        _emitAccumulator -= 1;
        _spawn(state.speed);
      }
    }

    for (final drop in _drops) {
      drop.remaining -= dt;
      drop.position += drop.velocity * dt;
      drop.velocity.y += 240 * dt;
    }
    _drops.removeWhere((drop) => drop.remaining <= 0);
  }

  void _spawn(double speed) {
    final baseX = WorldLayout.screenX(WorldLayout.riderX - 2.7);
    final life = 0.22 + _random.nextDouble() * 0.26;
    final back = 40 + speed * 1.6;
    _drops.add(
      _Drop(
        position: Vector2(
          baseX + _random.nextDouble() * 5,
          WorldLayout.screenY(0) - _random.nextDouble() * 2,
        ),
        velocity: Vector2(
          -back * (0.6 + _random.nextDouble() * 0.6),
          -20 - _random.nextDouble() * 55,
        ),
        remaining: life,
        total: life,
        radius: 1.2 + _random.nextDouble() * 1.8,
      ),
    );
  }

  @override
  void render(Canvas canvas) {
    for (final drop in _drops) {
      final life = (drop.remaining / drop.total).clamp(0.0, 1.0).toDouble();
      _paint.color = const Color(0xFFEAF7F8).withValues(alpha: 0.55 * life);
      canvas.drawCircle(
        Offset(drop.position.x, drop.position.y),
        drop.radius * (0.5 + 0.5 * life),
        _paint,
      );
    }
  }
}

class _Drop {
  _Drop({
    required this.position,
    required this.velocity,
    required this.remaining,
    required this.total,
    required this.radius,
  });

  Vector2 position;
  Vector2 velocity;
  double remaining;
  final double total;
  final double radius;
}
