import 'dart:math' as math;
import 'dart:ui';
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flame/rendering.dart';

import '../../models/game_state.dart';
import '../../models/obstacle.dart';
import '../../models/pickup.dart';
import '../iso_projection.dart';
import '../painting/pelican_art.dart';
import '../painting/prop_art.dart';
import '../rendering/baked_sprite.dart';
import '../rendering/rider_sprites.dart';
import '../ride_style.dart';
import '../world_layout.dart';
import 'scene_layer_component.dart';

/// 骑行者、障碍与拾取物所在的 2.5D 实体层。
///
/// - 烘焙精灵：道具在加载时烘焙成单张 [BakedSprite]，每帧只画一次；
///   骑行者的车轮、曲柄、腿与踏板按角度预烘焙，只现场绘制矢量正稿。
/// - 3D 装饰器：骑行者套一层 [Rotate3DDecorator]，做轻微的偏航与透视。
/// - 等距深度排序：按世界 z 由远到近绘制，骑行者插在 z = 0 的位置。
///   实体只在生成、拾取或磁铁吸附时改变深度，因此排序结果会缓存到
///   [GameProvider.entityRevision] 变化时才重算。
class RideEntitiesComponent extends SceneLayerComponent {
  RideEntitiesComponent({required super.provider, super.priority});

  static const double _riderScale = 0.78;

  /// 拾取物光晕的位图倍率：1080p 下放大后仍接近 1:1。
  static const double _glowScale = 3;

  final Rotate3DDecorator _riderTilt = Rotate3DDecorator(
    perspective: 0.0011,
  );
  final Paint _shadowPaint = Paint()..color = const Color(0x55202426);
  final Paint _riderShadowPaint = Paint();
  final Paint _glowPaint = Paint()..filterQuality = FilterQuality.medium;

  /// 深度排序结果；只有 [GameProvider.entityRevision] 变化时才重算。
  final List<Obstacle> _sortedObstacles = <Obstacle>[];
  final List<Pickup> _sortedPickups = <Pickup>[];
  int _orderRevision = -1;

  final Map<ObstacleKind, List<BakedSprite>> _obstacleSprites =
      <ObstacleKind, List<BakedSprite>>{};
  final Map<PickupKind, BakedSprite> _pickupSprites =
      <PickupKind, BakedSprite>{};
  final Map<PickupKind, ui.Image> _glowImages = <PickupKind, ui.Image>{};

  /// 骑行者的静态层：车身一张，鹈鹕按站姿/俯身各一张。
  late final Picture _bikePicture;
  late final Picture _pelicanStand;
  late final Picture _pelicanDuck;

  /// 车轮/曲柄/腿/踏板的 12 档角度缓存，在加载时烘焙，避免首帧卡顿。
  late final RiderSpriteCache _riderSprites;

  double _elapsed = 0;
  double _wheelAngle = 0;
  double _wingPhase = 0;

  @override
  void onLoad() {
    _bikePicture = _recordRiderLayer(paintRiderBikeStatic);
    _pelicanStand = _recordRiderBody(ducking: false);
    _pelicanDuck = _recordRiderBody(ducking: true);
    _riderSprites = RiderSpriteCache();
    for (final kind in ObstacleKind.values) {
      _obstacleSprites[kind] = <BakedSprite>[
        for (var variant = 0; variant < 2; variant++)
          BakedSprite.bake(
            size: PropArt.obstacleSize(kind),
            painter: (canvas, size) =>
                PropArt.paintObstacle(canvas, size, kind, variant: variant),
          ),
      ];
    }
    for (final kind in PickupKind.values) {
      _pickupSprites[kind] = BakedSprite.bake(
        size: PropArt.pickupSize(kind),
        painter: (canvas, size) => PropArt.paintPickup(canvas, size, kind),
        anchorY: 0.5,
      );
      _glowImages[kind] = _bakeGlow(kind);
    }
  }

  /// 在骑行者的美术坐标系里录制一张静态层。
  Picture _recordRiderLayer(void Function(Canvas canvas) painter) {
    final recorder = PictureRecorder();
    final canvas = Canvas(recorder);
    applyRiderArtTransform(canvas, kRiderArtSize);
    painter(canvas);
    return recorder.endRecording();
  }

  Picture _recordRiderBody({required bool ducking}) {
    return _recordRiderLayer(
      (canvas) => paintRiderBodyStatic(canvas, ducking: ducking),
    );
  }

  /// 拾取物光晕烘焙成 [_glowScale] 倍位图：径向渐变只算一次，
  /// 之后每帧只做一次采样。
  ui.Image _bakeGlow(PickupKind kind) {
    const logical = 48.0;
    final recorder = PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.scale(_glowScale);
    canvas.translate(logical / 2, logical / 2);
    final color = pickupColor(kind);
    canvas.drawCircle(
      Offset.zero,
      24,
      Paint()
        ..shader = Gradient.radial(
          Offset.zero,
          24,
          <Color>[
            color.withValues(alpha: 0.32),
            color.withValues(alpha: 0),
          ],
        ),
    );
    final picture = recorder.endRecording();
    final image = picture.toImageSync(
      (logical * _glowScale).round(),
      (logical * _glowScale).round(),
    );
    picture.dispose();
    return image;
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
    for (final image in _glowImages.values) {
      image.dispose();
    }
    _riderSprites.dispose();
    _bikePicture.dispose();
    _pelicanStand.dispose();
    _pelicanDuck.dispose();
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
    if (provider.entityRevision != _orderRevision) {
      _orderRevision = provider.entityRevision;
      _sortedObstacles
        ..clear()
        ..addAll(state.obstacles)
        ..sort((a, b) => b.z.compareTo(a.z));
      _sortedPickups
        ..clear()
        ..addAll(state.pickups)
        ..sort((a, b) => b.z.compareTo(a.z));
    }
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

  void _paintPickup(Canvas canvas, Pickup pickup) {
    final sprite = _pickupSprites[pickup.kind];
    if (sprite == null) return;
    final base = IsoProjection.project(pickup.x, pickup.y, pickup.z);
    final bob = math.sin(_elapsed * 2.6 + pickup.phase) * 3.4;
    final center = base + Offset(0, -bob);

    final glow = _glowImages[pickup.kind];
    if (glow != null) {
      canvas.drawImageRect(
        glow,
        Rect.fromLTWH(0, 0, glow.width.toDouble(), glow.height.toDouble()),
        Rect.fromCenter(center: center, width: 48, height: 48),
        _glowPaint,
      );
    }

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
      applyRiderArtTransform(tilted, kRiderArtSize);
      // 动态层与静态层交错绘制，保持车轮/曲柄/腿被车身遮住的层次。
      paintRiderSpeedMarks(tilted, look);
      _riderSprites.drawWheels(tilted, _wheelAngle);
      tilted.drawPicture(_bikePicture);
      _riderSprites.drawCranks(tilted, _wheelAngle);
      _riderSprites.drawLegs(tilted, _wheelAngle, ducking: look.ducking);
      tilted.drawPicture(look.ducking ? _pelicanDuck : _pelicanStand);
      paintRiderWing(tilted, look);
      paintRiderScarf(tilted, look);
      _riderSprites.drawPedals(tilted, _wheelAngle);
      paintRiderEffects(tilted, look);
    }, canvas);
    canvas.restore();
  }
}
