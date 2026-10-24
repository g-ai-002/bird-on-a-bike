import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import 'scene_layer_component.dart';

/// 拾取/护盾破碎时的粒子层。
class ParticleBurstComponent extends SceneLayerComponent {
  ParticleBurstComponent({required super.provider, super.priority});

  final math.Random _random = math.Random();
  final List<_Particle> _particles = [];
  final Paint _paint = Paint();

  void burst(
    Vector2 center, {
    required Color color,
    int count = 14,
    double spread = 190,
  }) {
    for (var i = 0; i < count; i++) {
      final angle = _random.nextDouble() * math.pi * 2;
      final speed = spread * (0.35 + _random.nextDouble() * 0.65);
      final life = 0.36 + _random.nextDouble() * 0.28;
      _particles.add(
        _Particle(
          position: Vector2(center.x, center.y),
          velocity: Vector2(
            math.cos(angle) * speed,
            math.sin(angle) * speed - 30,
          ),
          remaining: life,
          total: life,
          radius: 2.2 + _random.nextDouble() * 2.6,
          color: color,
        ),
      );
    }
  }

  void clear() {
    _particles.clear();
  }

  @override
  void update(double dt) {
    super.update(dt);
    final friction = math.pow(0.1, dt).toDouble();
    for (final particle in _particles) {
      particle.remaining -= dt;
      particle.position = particle.position + particle.velocity * dt;
      particle.velocity = particle.velocity * friction;
    }
    _particles.removeWhere((particle) => particle.remaining <= 0);
  }

  @override
  void render(Canvas canvas) {
    for (final particle in _particles) {
      final life =
          (particle.remaining / particle.total).clamp(0.0, 1.0).toDouble();
      _paint.color = particle.color.withValues(alpha: 0.9 * life);
      canvas.drawCircle(
        Offset(particle.position.x, particle.position.y),
        particle.radius * (0.6 + 0.4 * life),
        _paint,
      );
    }
  }
}

class _Particle {
  _Particle({
    required this.position,
    required this.velocity,
    required this.remaining,
    required this.total,
    required this.radius,
    required this.color,
  });

  Vector2 position;
  Vector2 velocity;
  double remaining;
  final double total;
  final double radius;
  final Color color;
}
