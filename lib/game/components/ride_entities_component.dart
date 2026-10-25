import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/rendering.dart';

import '../../models/game_state.dart';
import '../../models/obstacle.dart';
import '../../models/pickup.dart';
import '../iso_projection.dart';
import '../painting/pelican_art.dart';
import '../painting/prop_art.dart';
import '../rendering/stacked_sprite.dart';
import '../ride_style.dart';
import '../world_layout.dart';
import 'scene_layer_component.dart';

/// 骑行者、障碍与拾取物所在的 2.5D 实体层。
///
/// - 精灵堆叠：道具在加载时烘焙成带厚度阴影的 [StackedSprite]；
///   骑行者每帧变化，用 [paintStacked] 现场叠两层。
/// - 3D 装饰器：骑行者套一层 [Rotate3DDecorator]，做轻微的偏航与透视。
/// - 等距深度排序：按世界 z 由远到近绘制，骑行者插在 z = 0 的位置。
class RideEntitiesComponent extends SceneLayerComponent {
  RideEntitiesComponent({required super.provider, super.priority});

  static const double _riderScale = 0.78;

  final Rotate3DDecorator _riderTilt = Rotate3DDecorator(
    perspective: 0.0011,
  );
  final Paint _shadowPaint = Paint()..color = const Color(0x55202426);
  final Paint _riderShadowPaint = Paint();
  final Paint _pickupGlow = Paint();
  final Map<PickupKind, Shader> _glowShaders = <PickupKind, Shader>{};

  /// 每帧复用同一份列表，避免在渲染循环里反复分配。
  final List<Obstacle> _sortedObstacles = <Obstacle>[];
  final List<Pickup> _sortedPickups = <Pickup>[];

  final Map<ObstacleKind, List<StackedSprite>> _obstacleSprites =
      <ObstacleKind, List<StackedSprite>>{};
  final Map<PickupKind, StackedSprite> _pickupSprites =
      <PickupKind, StackedSprite>{};

  double _elapsed = 0;
  double _wheelAngle = 0;
  double _wingPhase = 0;

  @override
  void onLoad() {
    for (final kind in ObstacleKind.values) {
      _obstacleSprites[kind] = <StackedSprite>[
        for (var variant = 0; variant < 2; variant++)
          StackedSprite.bake(
            size: PropArt.obstacleSize(kind),
            painter: (canvas, size) =>
                PropArt.paintObstacle(canvas, size, kind, variant: variant),
            layers: kind == ObstacleKind.banner ? 3 : 4,
            step: const Offset(-0.95, 1.75),
          ),
      ];
    }
    for (final kind in PickupKind.values) {
      _pickupSprites[kind] = StackedSprite.bake(
        size: PropArt.pickupSize(kind),
        painter: (canvas, size) => PropArt.paintPickup(canvas, size, kind),
        layers: 3,
        step: const Offset(-0.7, 1.3),
        anchorY: 0.5,
      );
    }
  }

  @override
  void onRemove() {
    for (final sprites in _obstacleSprites.values) {
      for (final sprite in sprites) {
        sprite.dispose();
      }
    }
    for (final sprite in _pickupSprites.values) {
      sprite.dispose();
    }
    super.onRemove();
  }

  @override
  void update(double dt) {
    super.update(dt);
    final state = provider.state;
    if (!state.isPlaying) return;
    _elapsed += dt;
    // 车轮向右滚动：画面坐标 y 向下，角度递增即顺时针。
    _wheelAngle += state.speed * IsoProjection.pxPerUnit * dt / 24;
    _wingPhase += dt * (state.rider.airborne ? 13.0 : 5.5);
  }

  @override
  void render(Canvas canvas) {
    final state = provider.state;
    _sortedObstacles
      ..clear()
      ..addAll(state.obstacles)
      ..sort((a, b) => b.z.compareTo(a.z));
    _sortedPickups
      ..clear()
      ..addAll(state.pickups)
      ..sort((a, b) => b.z.compareTo(a.z));
    final obstacles = _sortedObstacles;
    final pickups = _sortedPickups;

    _paintShadows(canvas, state, obstacles, pickups);

    var obstacleIndex = 0;
    var pickupIndex = 0;
    var riderDrawn = false;
    while (obstacleIndex < obstacles.length || pickupIndex < pickups.length) {
      final obstacleZ = obstacleIndex < obstacles.length
          ? obstacles[obstacleIndex].z
          : double.negativeInfinity;
      final pickupZ = pickupIndex < pickups.length
          ? pickups[pickupIndex].z
          : double.negativeInfinity;
      final nextZ = math.max(obstacleZ, pickupZ);
      // 骑行者先画，z = 0 的障碍随后覆盖上来，正面对撞时能挡住单车。
      if (!riderDrawn && nextZ <= WorldLayout.riderZ) {
        _paintRider(canvas, state);
        riderDrawn = true;
      }
      if (obstacleZ >= pickupZ) {
        _paintObstacle(canvas, obstacles[obstacleIndex++]);
      } else {
        _paintPickup(canvas, pickups[pickupIndex++]);
      }
    }
    if (!riderDrawn) {
      _paintRider(canvas, state);
    }
  }

  void _paintShadows(
    Canvas canvas,
    GameState state,
    List<Obstacle> obstacles,
    List<Pickup> pickups,
  ) {
    for (final obstacle in obstacles) {
      final at = IsoProjection.project(obstacle.centerX, 0, obstacle.z);
      final w = obstacle.kind.width * IsoProjection.pxPerUnit * 0.95;
      canvas.drawOval(
        Rect.fromCenter(center: at, width: w, height: 9),
        _shadowPaint,
      );
    }
    for (final pickup in pickups) {
      final at = IsoProjection.project(pickup.x, 0, pickup.z);
      canvas.drawOval(
        Rect.fromCenter(center: at, width: 16, height: 5),
        _shadowPaint,
      );
    }

    final riderGround = IsoProjection.project(
      WorldLayout.riderX,
      0,
      WorldLayout.riderZ,
    );
    final lift = (state.rider.height / 16).clamp(0.0, 0.4);
    final scale = 1 - lift;
    _riderShadowPaint.color = const Color(
      0xFF202426,
    ).withValues(alpha: 0.3 - lift * 0.4);
    canvas.drawOval(
      Rect.fromCenter(
        center: riderGround + const Offset(0, 1),
        width: 104 * scale,
        height: 15 * scale,
      ),
      _riderShadowPaint,
    );
  }

  void _paintObstacle(Canvas canvas, Obstacle obstacle) {
    final sprites = _obstacleSprites[obstacle.kind];
    if (sprites == null || sprites.isEmpty) return;
    final sprite = sprites[obstacle.id % sprites.length];
    final anchor = IsoProjection.project(obstacle.centerX, 0, obstacle.z);
    final sway = obstacle.kind == ObstacleKind.banner
        ? math.sin(_elapsed * 1.4 + obstacle.id) * 0.016
        : 0.0;
    sprite.render(canvas, anchor, rotation: sway);
  }

  Shader _glowShader(PickupKind kind) {
    return _glowShaders.putIfAbsent(kind, () {
      final color = pickupColor(kind);
      return Gradient.radial(
        Offset.zero,
        24,
        <Color>[
          color.withValues(alpha: 0.32),
          color.withValues(alpha: 0),
        ],
      );
    });
  }

  void _paintPickup(Canvas canvas, Pickup pickup) {
    final sprite = _pickupSprites[pickup.kind];
    if (sprite == null) return;
    final base = IsoProjection.project(pickup.x, pickup.y, pickup.z);
    final bob = math.sin(_elapsed * 2.6 + pickup.phase) * 3.4;
    final center = base + Offset(0, -bob);

    canvas.save();
    canvas.translate(center.dx, center.dy);
    _pickupGlow.shader = _glowShader(pickup.kind);
    canvas.drawCircle(Offset.zero, 24, _pickupGlow);
    canvas.restore();

    final pulse = 1 + math.sin(_elapsed * 3.1 + pickup.phase) * 0.04;
    final tilt = pickup.kind == PickupKind.fish
        ? math.sin(_elapsed * 2.2 + pickup.phase) * 0.14
        : 0.0;
    sprite.render(canvas, center, scale: pulse, rotation: tilt);
  }

  void _paintRider(Canvas canvas, GameState state) {
    final look = RideLook(
      wheelAngle: _wheelAngle,
      wingPhase: _wingPhase,
      ducking: state.rider.ducking,
      airborne: state.rider.airborne,
      shield: state.hasShield,
      magnet: state.magnetActive,
    );
    final ground = IsoProjection.project(
      WorldLayout.riderX,
      state.rider.height,
      WorldLayout.riderZ,
    );

    canvas.save();
    canvas.translate(ground.dx, ground.dy);
    canvas.scale(_riderScale);
    _riderTilt
      ..angleY = 0.05 + math.sin(_elapsed * 0.85) * 0.055
      ..center = Vector2(0, -kRiderArtSize.height * 0.42);
    _riderTilt.applyChain((tilted) {
      tilted.translate(-kRiderArtSize.width / 2, -kRiderArtSize.height);
      paintStacked(
        tilted,
        size: kRiderArtSize,
        painter: (inner, size) => paintPelicanRider(inner, size, look),
        layers: 2,
        step: const Offset(-0.9, 1.6),
      );
    }, canvas);
    canvas.restore();
  }
}
