import 'dart:math' as math;
import 'dart:ui' show Canvas, Color, Rect;

import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart' as vm;

import '../../models/game_state.dart';
import '../../models/obstacle.dart';
import '../../models/pickup.dart';
import '../../providers/game_provider.dart';
import '../ride_style.dart';
import 'scene_units.dart';

/// 固定侧视相机下的 3D 海岸骑行场景。
///
/// 玩法仍由 [GameProvider] 以 2D 像素推进，这里只把每帧快照换算成 3D
/// 位置与姿态：低多边形鹈鹕、自行车、礁石/木箱/浮木/横幅与小鱼，
/// 背景是渐变天空、海面、远山与夕阳。相机固定不动，撞车反馈仍由
/// Flame 的取景器缩放与震动完成。
class RideScene {
  RideScene({required this.provider});

  final GameProvider provider;

  final Scene scene = Scene();
  late final PerspectiveCamera camera;

  static final vm.Vector3 _xAxis = vm.Vector3(1, 0, 0);
  static final vm.Vector3 _yAxis = vm.Vector3(0, 1, 0);
  static final vm.Vector3 _zAxis = vm.Vector3(0, 0, 1);

  // 共享几何体
  late final CuboidGeometry _cube;
  late final CylinderGeometry _cylinder;
  late final CylinderGeometry _cone;
  late final SphereGeometry _sphere;
  late final TorusGeometry _ring;
  late final TorusGeometry _rimRing;
  late final TorusGeometry _thinRing;
  late final DiscGeometry _disc;
  late final IcosphereGeometry _rock;

  // 共享材质
  late final PhysicallyBasedMaterial _roadMat;
  late final PhysicallyBasedMaterial _sandMat;
  late final PhysicallyBasedMaterial _lineMat;
  late final PhysicallyBasedMaterial _seaMat;
  late final PhysicallyBasedMaterial _waveMat;
  late final PhysicallyBasedMaterial _hillMat;
  late final PhysicallyBasedMaterial _cloudMat;
  late final PhysicallyBasedMaterial _tyreMat;
  late final PhysicallyBasedMaterial _rimMat;
  late final PhysicallyBasedMaterial _frameMat;
  late final PhysicallyBasedMaterial _frameDarkMat;
  late final PhysicallyBasedMaterial _featherMat;
  late final PhysicallyBasedMaterial _featherShadeMat;
  late final PhysicallyBasedMaterial _beakMat;
  late final PhysicallyBasedMaterial _pouchMat;
  late final PhysicallyBasedMaterial _legMat;
  late final PhysicallyBasedMaterial _scarfMat;
  late final PhysicallyBasedMaterial _eyeMat;
  late final PhysicallyBasedMaterial _crateMat;
  late final PhysicallyBasedMaterial _crateDarkMat;
  late final PhysicallyBasedMaterial _rockMat;
  late final PhysicallyBasedMaterial _rockDarkMat;
  late final PhysicallyBasedMaterial _logMat;
  late final PhysicallyBasedMaterial _bannerMat;
  late final PhysicallyBasedMaterial _bannerPoleMat;
  late final PhysicallyBasedMaterial _whiteMat;
  late final UnlitMaterial _sunMat;
  late final UnlitMaterial _shadowMat;
  late final UnlitMaterial _fishMat;
  late final UnlitMaterial _fishDarkMat;
  late final UnlitMaterial _shieldMat;
  late final UnlitMaterial _magnetMat;
  late final UnlitMaterial _redMat;

  // 背景与路面
  final List<Node> _clouds = [];
  final List<_CloudSeed> _cloudSeeds = [];
  final List<Node> _waves = [];
  final List<_WaveSeed> _waveSeeds = [];
  final List<Node> _dashes = [];

  // 骑行者
  late final Node _rider;
  late final Node _torso;
  late final Node _rearSpin;
  late final Node _frontSpin;
  late final Node _nearWing;
  late final Node _farWing;
  late final Node _scarf;
  late final Node _shieldRing;
  late final Node _magnetRing;
  late final Node _riderShadow;
  late final Node _crankArmA;
  late final Node _crankArmB;
  late final Node _pedalA;
  late final Node _pedalB;
  late final Node _legNearUpper;
  late final Node _legNearLower;
  late final Node _legFarUpper;
  late final Node _legFarLower;

  final Map<int, Node> _obstacleNodes = {};
  final Map<int, Node> _pickupNodes = {};

  double _elapsed = 0;
  double _wheelAngle = 0;
  double _wingPhase = 0;

  /// 构建静态场景、骑行者与初始实体：必须在
  /// `Scene.initializeStaticResources()` 完成后调用。
  void build() {
    camera = PerspectiveCamera(
      position: vm.Vector3(0, 16, -52),
      target: vm.Vector3(0, 14, 0),
      fovFar: 700,
    );

    _createAssets();

    final sky = GradientSkySource(
      zenithColor: _linear3(RideColors.skyTop),
      horizonColor: _linear3(RideColors.skyMid),
      groundColor: _linear3(RideColors.sea),
      sunDirection: vm.Vector3(12, 5, 120).normalized(),
      sunColor: vm.Vector3(2.4, 1.7, 1.0),
      sunSharpness: 320,
    );
    scene.skybox = Skybox(sky);
    scene.sunLight = SunLight(
      sky,
      castsShadow: false,
      intensity: 1.2,
      shadowMaxDistance: 120,
    );
    scene.exposure = 1.1;

    _buildBackdrop();
    _buildStage();
    _buildRider();

    _syncRider();
    _syncObstacles();
    _syncPickups();
    _syncScenery();
  }

  void update(double dt) {
    _elapsed += dt;
    final state = provider.state;
    if (state.isPlaying) {
      _wheelAngle += state.speed * dt / 24;
      _wingPhase += dt * (state.rider.airborne ? 13.0 : 5.5);
    }

    _syncRider();
    _syncObstacles();
    _syncPickups();
    _syncScenery();
    scene.update(dt);
  }

  void render(Canvas canvas, Rect viewport) {
    scene.render(camera, canvas, viewport: viewport);
  }

  // ---------------------------------------------------------------------------
  // 资源
  // ---------------------------------------------------------------------------

  void _createAssets() {
    _cube = CuboidGeometry(vm.Vector3(1, 1, 1));
    _cylinder = CylinderGeometry(radialSegments: 16);
    _cone = CylinderGeometry(topRadius: 0, radialSegments: 16);
    _sphere = SphereGeometry(radius: 1, segments: 20, rings: 12);
    _ring = TorusGeometry(
      radius: 1,
      tubeRadius: 0.12,
      radialSegments: 24,
      tubularSegments: 8,
    );
    _rimRing = TorusGeometry(
      radius: 1,
      tubeRadius: 0.04,
      radialSegments: 24,
      tubularSegments: 6,
    );
    _thinRing = TorusGeometry(radius: 1, tubeRadius: 0.02, tubularSegments: 6);
    _disc = DiscGeometry(radius: 1, segments: 24);
    _rock = IcosphereGeometry(radius: 1, subdivisions: 1);

    _roadMat = _pbr(RideColors.road, roughness: 0.95);
    _sandMat = _pbr(const Color(0xFFB98A5A), roughness: 0.95);
    _lineMat = _pbr(RideColors.roadLine, roughness: 0.8);
    _seaMat = _pbr(RideColors.sea, roughness: 0.35, metallic: 0.1);
    _waveMat = _pbr(const Color(0xFF6FC3C9), roughness: 0.4);
    _hillMat = _pbr(RideColors.hillFar, roughness: 1.0);
    _cloudMat = _pbr(const Color(0xFFFFF4E2), roughness: 1.0);
    _tyreMat = _pbr(RideColors.tyre);
    _rimMat = _pbr(RideColors.pelicanShade, roughness: 0.5, metallic: 0.2);
    _frameMat = _pbr(RideColors.frame, roughness: 0.45, metallic: 0.25);
    _frameDarkMat = _pbr(RideColors.frameDark, roughness: 0.6);
    _featherMat = _pbr(RideColors.pelican, roughness: 0.9);
    _featherShadeMat = _pbr(RideColors.pelicanShade, roughness: 0.95);
    _beakMat = _pbr(RideColors.beak, roughness: 0.55);
    _pouchMat = _pbr(RideColors.pouch, roughness: 0.7);
    _legMat = _pbr(RideColors.leg, roughness: 0.7);
    _scarfMat = _pbr(RideColors.scarf, roughness: 0.8);
    _eyeMat = _pbr(RideColors.eye, roughness: 0.35);
    _crateMat = _pbr(RideColors.crate, roughness: 0.9);
    _crateDarkMat = _pbr(RideColors.crateDark, roughness: 0.9);
    _rockMat = _pbr(RideColors.rock, roughness: 1.0);
    _rockDarkMat = _pbr(RideColors.rockDark, roughness: 1.0);
    _logMat = _pbr(RideColors.log, roughness: 0.95);
    _bannerMat = _pbr(RideColors.banner);
    _bannerPoleMat = _pbr(RideColors.bannerPole, roughness: 0.9);
    _whiteMat = _pbr(const Color(0xFFFFF6E8), roughness: 0.8);
    _sunMat = _unlit(RideColors.sun);
    _shadowMat = _unlit(const Color(0xFF2A2A2A));
    _fishMat = _unlit(RideColors.fish);
    _fishDarkMat = _unlit(RideColors.fishDark);
    _shieldMat = _unlit(RideColors.shield);
    _magnetMat = _unlit(RideColors.magnet);
    _redMat = _unlit(const Color(0xFFE05A5A));
  }

  // ---------------------------------------------------------------------------
  // 背景
  // ---------------------------------------------------------------------------

  void _buildBackdrop() {
    scene.add(
      _box(vm.Vector3(300, 0.5, 100), _seaMat, vm.Vector3(0, -2.6, 55)),
    );
    scene.add(
      _box(vm.Vector3(300, 0.06, 0.9), _lineMat, vm.Vector3(0, 0.04, 5.1)),
    );
    scene.add(
      _box(vm.Vector3(300, 0.06, 0.5), _sandMat, vm.Vector3(0, 0.02, 5.6)),
    );

    _buildClouds();
    _buildHills();
    _buildWaves();
  }

  void _buildClouds() {
    const specs = <_CloudSeed>[
      _CloudSeed(-34, 24, 1.0),
      _CloudSeed(-6, 29, 0.8),
      _CloudSeed(22, 23, 1.2),
      _CloudSeed(42, 27, 0.7),
    ];
    for (final seed in specs) {
      final node = _node(
        _sphere,
        _cloudMat,
        position: vm.Vector3(seed.x, seed.y, 72),
        scale: vm.Vector3(seed.scale * 6.5, seed.scale * 1.5, 1.5),
      );
      _cloudSeeds.add(seed);
      _clouds.add(node);
      scene.add(node);
    }
  }

  void _buildHills() {
    const hills = <_HillSeed>[
      _HillSeed(-36, 46, 16, 13),
      _HillSeed(-10, 52, 22, 17),
      _HillSeed(18, 48, 14, 11),
      _HillSeed(40, 56, 26, 15),
    ];
    for (final hill in hills) {
      scene.add(
        _node(
          _cone,
          _hillMat,
          position: vm.Vector3(hill.x, hill.height / 2 - 2.4, hill.z),
          scale: vm.Vector3(hill.radius, hill.height, hill.radius * 0.7),
        ),
      );
    }
  }

  void _buildWaves() {
    for (var i = 0; i < 22; i++) {
      final seed = _WaveSeed(
        x: -34 + (i * 7.3) % 68,
        z: 9 + (i % 7) * 4.4,
        width: 2.2 + (i % 3) * 0.7,
        speed: 0.35 + (i % 4) * 0.08,
      );
      final node = _box(
        vm.Vector3(seed.width, 0.05, 0.16),
        _waveMat,
        vm.Vector3(seed.x, -2.3, seed.z),
      );
      _waveSeeds.add(seed);
      _waves.add(node);
      scene.add(node);
    }

    for (var i = 0; i < 5; i++) {
      scene.add(
        _box(
          vm.Vector3(4.4 - i * 0.6, 0.05, 0.2),
          _sunMat,
          vm.Vector3(12 - i * 0.4, -2.28, 10 + i * 2.6),
        ),
      );
    }
  }

  // ---------------------------------------------------------------------------
  // 路面
  // ---------------------------------------------------------------------------

  void _buildStage() {
    scene.add(
      _box(vm.Vector3(240, 1.0, 40), _roadMat, vm.Vector3(0, -0.5, -15)),
    );
    scene.add(
      _box(vm.Vector3(240, 0.06, 0.24), _lineMat, vm.Vector3(0, 0.04, -4.6)),
    );

    for (var i = 0; i < 11; i++) {
      final dash = _box(
        vm.Vector3(4.8, 0.07, 0.36),
        _lineMat,
        vm.Vector3.zero(),
      );
      _dashes.add(dash);
      scene.add(dash);
    }
  }

  // ---------------------------------------------------------------------------
  // 骑行者
  // ---------------------------------------------------------------------------

  void _buildRider() {
    _rider = Node()..position = vm.Vector3(SceneUnits.riderX, 0, 0);
    scene.add(_rider);

    _riderShadow = _node(
      _disc,
      _shadowMat,
      position: vm.Vector3(SceneUnits.riderX, 0.03, 0),
      scale: vm.Vector3(2.4, 1, 0.9),
    );
    scene.add(_riderShadow);

    _rearSpin = _buildWheel(front: false);
    _frontSpin = _buildWheel(front: true);

    final rear = vm.Vector3(-2.7, 2.45, 0);
    final front = vm.Vector3(2.7, 2.45, 0);
    final crank = vm.Vector3(0, 2.45, 0);
    final seat = vm.Vector3(-1.0, 4.55, 0);
    final head = vm.Vector3(1.9, 4.4, 0);
    final handle = vm.Vector3(2.25, 5.35, 0);

    _rider.addAll([
      _rod(rear, seat, 0.1, _frameMat),
      _rod(seat, head, 0.1, _frameMat),
      _rod(head, front, 0.1, _frameMat),
      _rod(crank, seat, 0.09, _frameMat),
      _rod(crank, head, 0.09, _frameMat),
      _rod(rear, crank, 0.08, _frameMat),
      _rod(head, handle, 0.08, _frameDarkMat),
      _box(vm.Vector3(1.7, 0.22, 0.8), _tyreMat, vm.Vector3(-1.1, 4.75, 0)),
      _box(vm.Vector3(1.2, 1.0, 1.0), _crateMat, vm.Vector3(2.35, 5.0, 0)),
      _node(
        _cone,
        _fishDarkMat,
        position: vm.Vector3(2.9, 5.75, 0),
        scale: vm.Vector3(0.7, 0.9, 0.7),
        rotation: vm.Quaternion.axisAngle(_zAxis, math.pi / 2),
      ),
      _node(
        _thinRing,
        _frameDarkMat,
        position: crank,
        scale: vm.Vector3.all(0.62),
        rotation: vm.Quaternion.axisAngle(_xAxis, math.pi / 2),
      ),
    ]);

    _crankArmA = _rod(crank, crank, 0.07, _frameDarkMat);
    _crankArmB = _rod(crank, crank, 0.07, _frameDarkMat);
    _pedalA = _box(
      vm.Vector3(0.55, 0.16, 0.45),
      _frameDarkMat,
      vm.Vector3.zero(),
    );
    _pedalB = _box(
      vm.Vector3(0.55, 0.16, 0.45),
      _frameDarkMat,
      vm.Vector3.zero(),
    );
    _rider.addAll([_crankArmA, _crankArmB, _pedalA, _pedalB]);

    _buildPelican();

    _legNearUpper = _rod(crank, crank, 0.14, _legMat);
    _legNearLower = _rod(crank, crank, 0.13, _legMat);
    _legFarUpper = _rod(crank, crank, 0.14, _legMat);
    _legFarLower = _rod(crank, crank, 0.13, _legMat);
    _rider.addAll([_legFarUpper, _legFarLower, _legNearUpper, _legNearLower]);

    _shieldRing = _node(
      _thinRing,
      _shieldMat,
      position: vm.Vector3(0.2, 6.0, 0),
      scale: vm.Vector3.all(6.2),
      rotation: vm.Quaternion.axisAngle(_xAxis, math.pi / 2),
    );
    _magnetRing = _node(
      _thinRing,
      _magnetMat,
      position: vm.Vector3(0.2, 6.0, 0),
      scale: vm.Vector3.all(6.9),
      rotation: vm.Quaternion.axisAngle(_xAxis, math.pi / 2),
    );
    _shieldRing.visible = false;
    _magnetRing.visible = false;
    _rider.addAll([_magnetRing, _shieldRing]);
  }

  Node _buildWheel({required bool front}) {
    final root = Node()
      ..position = vm.Vector3(front ? 2.7 : -2.7, 2.45, 0)
      ..rotation = vm.Quaternion.axisAngle(_xAxis, math.pi / 2);
    final spin = Node();
    root.add(spin);

    spin.add(_node(_ring, _tyreMat, scale: vm.Vector3.all(2.35)));
    spin.add(_node(_rimRing, _rimMat, scale: vm.Vector3.all(1.8)));
    for (var i = 0; i < 4; i++) {
      final spoke = _box(
        vm.Vector3(0.07, 3.4, 0.07),
        _rimMat,
        vm.Vector3.zero(),
      );
      spoke.rotation = vm.Quaternion.axisAngle(_zAxis, i * math.pi / 4);
      spin.add(spoke);
    }
    spin.add(_node(_sphere, _frameMat, scale: vm.Vector3.all(0.4)));

    _rider.add(root);
    return spin;
  }

  void _buildPelican() {
    _torso = Node()..position = vm.Vector3(-0.5, 6.0, 0);
    _rider.add(_torso);

    _torso.add(
      _node(
        _sphere,
        _featherMat,
        position: vm.Vector3(0.9, 0.9, 0),
        scale: vm.Vector3(2.5, 1.9, 1.7),
      ),
    );
    _torso.add(
      _node(
        _cone,
        _featherShadeMat,
        position: vm.Vector3(-1.9, 0.7, 0),
        scale: vm.Vector3(1.8, 1.0, 1.2),
        rotation: vm.Quaternion.axisAngle(_zAxis, math.pi / 2),
      ),
    );

    final neckStart = vm.Vector3(1.2, 1.5, 0);
    final neckEnd = vm.Vector3(2.4, 3.1, 0);
    _torso.add(_rod(neckStart, neckEnd, 0.5, _featherMat));

    _torso.add(
      _node(
        _sphere,
        _featherMat,
        position: vm.Vector3(2.6, 3.3, 0),
        scale: vm.Vector3.all(1.05),
      ),
    );
    _torso.add(
      _node(
        _sphere,
        _eyeMat,
        position: vm.Vector3(3.2, 3.45, 0.85),
        scale: vm.Vector3.all(0.18),
      ),
    );

    final beakBase = vm.Vector3(2.9, 3.15, 0);
    final beakTip = vm.Vector3(4.4, 2.9, 0);
    _torso.add(_coneRod(beakBase, beakTip, 0.42, _beakMat));
    _torso.add(
      _node(
        _sphere,
        _pouchMat,
        position: vm.Vector3(3.4, 2.85, 0.2),
        scale: vm.Vector3(1.15, 0.55, 0.55),
      ),
    );
    _torso.add(
      _node(
        _cone,
        _featherShadeMat,
        position: vm.Vector3(2.45, 4.35, 0),
        scale: vm.Vector3(0.45, 0.8, 0.45),
      ),
    );

    _nearWing = Node()..position = vm.Vector3(0.6, 1.6, 0.9);
    _farWing = Node()..position = vm.Vector3(0.6, 1.6, -0.85);
    _torso.add(_nearWing);
    _torso.add(_farWing);
    _nearWing.add(
      _node(
        _sphere,
        _featherMat,
        position: vm.Vector3(-0.9, 0, 0),
        scale: vm.Vector3(1.9, 1.0, 0.32),
      ),
    );
    _farWing.add(
      _node(
        _sphere,
        _featherShadeMat,
        position: vm.Vector3(-0.9, 0, 0),
        scale: vm.Vector3(1.8, 0.95, 0.3),
      ),
    );

    _scarf = Node()..position = vm.Vector3(2.2, 3.45, 0);
    _torso.add(_scarf);
    for (var i = 0; i < 3; i++) {
      _scarf.add(
        _box(
          vm.Vector3(0.9, 0.16, 0.3),
          _scarfMat,
          vm.Vector3(-0.5 - i * 0.8, -0.1 - i * 0.08, 0),
        ),
      );
    }
  }

  // ---------------------------------------------------------------------------
  // 每帧同步
  // ---------------------------------------------------------------------------

  void _syncRider() {
    final state = provider.state;
    final ducking = state.rider.ducking;
    final airborne = state.rider.airborne;
    final over = state.status == GameStatus.over;

    _rider.position = vm.Vector3(
      SceneUnits.riderX,
      SceneUnits.height(state.rider.height),
      0,
    );
    _rider.rotation = over
        ? vm.Quaternion.axisAngle(_zAxis, -0.16)
        : vm.Quaternion.identity();

    _torso.position = vm.Vector3(-0.5, ducking ? 2.0 : 6.0, 0);
    _torso.rotation = ducking
        ? vm.Quaternion.axisAngle(_zAxis, -0.18)
        : vm.Quaternion.identity();

    final wheelRotation = vm.Quaternion.axisAngle(_yAxis, _wheelAngle);
    _rearSpin.rotation = wheelRotation;
    _frontSpin.rotation = wheelRotation;

    final flap = math.sin(_wingPhase) * (airborne ? 0.55 : 0.22);
    _nearWing.rotation = vm.Quaternion.axisAngle(_zAxis, flap);
    _farWing.rotation = vm.Quaternion.axisAngle(_zAxis, -flap * 0.8);
    _scarf.rotation = vm.Quaternion.axisAngle(
      _zAxis,
      math.sin(_wingPhase * 1.6) * 0.12,
    );

    _shieldRing.visible = state.hasShield;
    _magnetRing.visible = state.magnetActive;
    if (state.magnetActive) {
      _magnetRing.rotation = vm.Quaternion.axisAngle(
        _zAxis,
        math.sin(_elapsed * 2) * 0.1,
      );
    }

    final jump = SceneUnits.height(state.rider.height);
    final shadowScale = math.max(0.9, 2.4 - jump * 0.12);
    _riderShadow.scale = vm.Vector3(shadowScale, 1, shadowScale * 0.38);

    _syncPedals();
  }

  void _syncPedals() {
    final crank = vm.Vector3(0, 2.45, 0);
    final hipY = _torso.position.y;
    final hipNear = vm.Vector3(-0.5, hipY + 0.2, 0.35);
    final hipFar = vm.Vector3(-0.5, hipY + 0.2, -0.35);

    final arm =
        vm.Vector3(math.cos(_wheelAngle), math.sin(_wheelAngle), 0) * 1.15;
    final pedalNear = crank + arm + vm.Vector3(0, 0, 0.55);
    final pedalFar = crank - arm + vm.Vector3(0, 0, -0.55);

    _pedalA.position = pedalNear;
    _pedalB.position = pedalFar;
    _placeRod(_crankArmA, crank, pedalNear, 0.07);
    _placeRod(_crankArmB, crank, pedalFar, 0.07);

    final kneeNear = _knee(hipNear, pedalNear, 1);
    final kneeFar = _knee(hipFar, pedalFar, -1);
    _placeRod(_legNearUpper, hipNear, kneeNear, 0.14);
    _placeRod(_legNearLower, kneeNear, pedalNear, 0.13);
    _placeRod(_legFarUpper, hipFar, kneeFar, 0.14);
    _placeRod(_legFarLower, kneeFar, pedalFar, 0.13);
  }

  vm.Vector3 _knee(vm.Vector3 hip, vm.Vector3 pedal, int side) {
    final mid = (hip + pedal) * 0.5;
    return mid + vm.Vector3(0.55, 0.15, 0.18 * side);
  }

  void _syncObstacles() {
    final alive = <int>{};
    for (final obstacle in provider.state.obstacles) {
      alive.add(obstacle.id);
      var node = _obstacleNodes[obstacle.id];
      if (node == null) {
        node = _buildObstacle(obstacle.kind);
        _obstacleNodes[obstacle.id] = node;
        scene.add(node);
      }
      node.position = vm.Vector3(SceneUnits.obstacleCenterX(obstacle), 0, 0);
    }

    for (final id in _obstacleNodes.keys.toList()) {
      if (alive.contains(id)) continue;
      final node = _obstacleNodes.remove(id);
      if (node != null) scene.remove(node);
    }
  }

  Node _buildObstacle(ObstacleKind kind) {
    final width = SceneUnits.obstacleWidth(kind);
    final height = SceneUnits.obstacleHeight(kind);
    final root = Node();

    switch (kind) {
      case ObstacleKind.rock:
        root.add(
          _node(
            _rock,
            _rockMat,
            position: vm.Vector3(0, height * 0.45, 0.1),
            scale: vm.Vector3(width * 0.55, height * 0.5, 1.05),
          ),
        );
        root.add(
          _node(
            _rock,
            _rockDarkMat,
            position: vm.Vector3(width * 0.2, height * 0.35, 0.55),
            scale: vm.Vector3(width * 0.24, height * 0.26, 0.55),
          ),
        );
        break;
      case ObstacleKind.crate:
        root.add(
          _box(
            vm.Vector3(width, height, 1.6),
            _crateMat,
            vm.Vector3(0, height / 2, 0),
          ),
        );
        for (final sign in <double>[-1, 1]) {
          final bar = _box(
            vm.Vector3(width * 1.18, 0.16, 0.12),
            _crateDarkMat,
            vm.Vector3(0, height / 2, 0.83),
          );
          bar.rotation = vm.Quaternion.axisAngle(_zAxis, sign * math.pi / 4);
          root.add(bar);
        }
        break;
      case ObstacleKind.log:
        root.add(
          _node(
            _cylinder,
            _logMat,
            position: vm.Vector3(0, height / 2, 0),
            scale: vm.Vector3(height, width, height),
            rotation: vm.Quaternion.axisAngle(_zAxis, math.pi / 2),
          ),
        );
        root.add(
          _node(
            _disc,
            _crateDarkMat,
            position: vm.Vector3(width / 2, height / 2, 0),
            scale: vm.Vector3(height, height, 1),
            rotation: vm.Quaternion.axisAngle(_zAxis, -math.pi / 2),
          ),
        );
        break;
      case ObstacleKind.banner:
        final clearance = SceneUnits.bannerClearance(kind);
        final poleTop = clearance + height + 1.6;
        root.add(
          _rod(
            vm.Vector3(-width / 2, 0, 0),
            vm.Vector3(-width / 2, poleTop, 0),
            0.14,
            _bannerPoleMat,
          ),
        );
        root.add(
          _rod(
            vm.Vector3(width / 2, 0, 0),
            vm.Vector3(width / 2, poleTop, 0),
            0.14,
            _bannerPoleMat,
          ),
        );
        root.add(
          _box(
            vm.Vector3(width, height, 0.7),
            _bannerMat,
            vm.Vector3(0, clearance + height / 2, 0),
          ),
        );
        for (var i = 0; i < 3; i++) {
          root.add(
            _box(
              vm.Vector3(0.7, height * 0.55, 0.1),
              _whiteMat,
              vm.Vector3(
                -width / 2 + width * (0.2 + i * 0.3),
                clearance + height / 2,
                0.41,
              ),
            ),
          );
        }
        break;
    }

    root.add(
      _node(
        _disc,
        _shadowMat,
        position: vm.Vector3(0, 0.035, 0),
        scale: vm.Vector3(width * 0.5, 1, 0.7),
      ),
    );
    return root;
  }

  void _syncPickups() {
    final alive = <int>{};
    for (final pickup in provider.state.pickups) {
      alive.add(pickup.id);
      var node = _pickupNodes[pickup.id];
      if (node == null) {
        node = _buildPickup(pickup.kind);
        _pickupNodes[pickup.id] = node;
        scene.add(node);
      }
      final bob = math.sin(_elapsed * 3 + pickup.phase) * 0.5;
      node.position = vm.Vector3(
        SceneUnits.pickupX(pickup),
        SceneUnits.pickupHeight(pickup) + bob,
        0,
      );
      node.rotation = pickup.kind == PickupKind.fish
          ? vm.Quaternion.axisAngle(
              _yAxis,
              math.sin(_elapsed * 2.4 + pickup.phase) * 0.18,
            )
          : vm.Quaternion.axisAngle(_yAxis, _elapsed * 1.4);
    }

    for (final id in _pickupNodes.keys.toList()) {
      if (alive.contains(id)) continue;
      final node = _pickupNodes.remove(id);
      if (node != null) scene.remove(node);
    }
  }

  Node _buildPickup(PickupKind kind) {
    final root = Node();
    switch (kind) {
      case PickupKind.fish:
        root.add(_node(_sphere, _fishMat, scale: vm.Vector3(1.3, 0.7, 0.45)));
        root.add(
          _node(
            _cone,
            _fishDarkMat,
            position: vm.Vector3(-1.15, 0, 0),
            scale: vm.Vector3(1.4, 1.0, 1.4),
            rotation: vm.Quaternion.axisAngle(_zAxis, math.pi / 2),
          ),
        );
        root.add(
          _node(
            _cone,
            _fishDarkMat,
            position: vm.Vector3(0, 0.6, 0),
            scale: vm.Vector3(0.8, 0.6, 0.8),
          ),
        );
        root.add(
          _node(
            _sphere,
            _eyeMat,
            position: vm.Vector3(0.7, 0.22, 0.42),
            scale: vm.Vector3.all(0.16),
          ),
        );
        break;
      case PickupKind.shield:
        root.add(
          _node(
            _ring,
            _shieldMat,
            scale: vm.Vector3.all(1.5),
            rotation: vm.Quaternion.axisAngle(_xAxis, math.pi / 2),
          ),
        );
        root.add(
          _box(vm.Vector3(0.28, 1.5, 0.28), _whiteMat, vm.Vector3.zero()),
        );
        root.add(
          _box(vm.Vector3(1.2, 0.28, 0.28), _whiteMat, vm.Vector3(0, 0.3, 0)),
        );
        break;
      case PickupKind.magnet:
        root.add(
          _box(vm.Vector3(0.6, 1.9, 0.5), _magnetMat, vm.Vector3(-1.0, 0.1, 0)),
        );
        root.add(
          _box(vm.Vector3(0.6, 1.9, 0.5), _magnetMat, vm.Vector3(1.0, 0.1, 0)),
        );
        root.add(
          _box(vm.Vector3(2.6, 0.6, 0.5), _magnetMat, vm.Vector3(0, -0.8, 0)),
        );
        root.add(
          _box(
            vm.Vector3(0.62, 0.42, 0.52),
            _redMat,
            vm.Vector3(-1.0, 1.05, 0),
          ),
        );
        root.add(
          _box(vm.Vector3(0.62, 0.42, 0.52), _redMat, vm.Vector3(1.0, 1.05, 0)),
        );
        break;
    }
    return root;
  }

  void _syncScenery() {
    final distancePx = provider.state.distance * 10;

    const dashSpan = 9.2;
    final dashOffset = distancePx / SceneUnits.pixelsPerUnit;
    for (var i = 0; i < _dashes.length; i++) {
      final raw = -48 + (i * dashSpan - dashOffset) % 96;
      final x = raw < -48 ? raw + 96 : raw;
      _dashes[i].position = vm.Vector3(x, 0.03, -2.4);
    }

    for (var i = 0; i < _waves.length; i++) {
      final seed = _waveSeeds[i];
      final travel = distancePx * seed.speed / SceneUnits.pixelsPerUnit;
      final raw = -40 + (seed.x + 40 - travel) % 80;
      final x = raw < -40 ? raw + 80 : raw;
      _waves[i].position = vm.Vector3(x, -2.3, seed.z);
    }

    final cloudTravel = distancePx * 0.06 / SceneUnits.pixelsPerUnit;
    for (var i = 0; i < _clouds.length; i++) {
      final seed = _cloudSeeds[i];
      final raw = -60 + (seed.x + 60 - cloudTravel) % 120;
      final x = raw < -60 ? raw + 120 : raw;
      _clouds[i].position = vm.Vector3(x, seed.y, 72);
    }
  }

  // ---------------------------------------------------------------------------
  // 小工具
  // ---------------------------------------------------------------------------

  Node _node(
    MeshGeometry geometry,
    Material material, {
    vm.Vector3? position,
    vm.Vector3? scale,
    vm.Quaternion? rotation,
  }) {
    final node = Node(mesh: Mesh(geometry, material));
    if (position != null) node.position = position;
    if (scale != null) node.scale = scale;
    if (rotation != null) node.rotation = rotation;
    return node;
  }

  Node _box(vm.Vector3 size, Material material, vm.Vector3 position) {
    return _node(_cube, material, position: position, scale: size);
  }

  Node _rod(vm.Vector3 a, vm.Vector3 b, double radius, Material material) {
    final node = _node(_cylinder, material);
    _placeRod(node, a, b, radius);
    return node;
  }

  Node _coneRod(vm.Vector3 a, vm.Vector3 b, double radius, Material material) {
    final node = _node(_cone, material);
    _placeRod(node, a, b, radius);
    return node;
  }

  void _placeRod(Node node, vm.Vector3 a, vm.Vector3 b, double radius) {
    final delta = b - a;
    final length = math.max(delta.length, 0.001);
    node.position = (a + b) * 0.5;
    node.scale = vm.Vector3(radius * 2, length, radius * 2);
    node.rotation = _fromYTo(delta);
  }

  vm.Quaternion _fromYTo(vm.Vector3 direction) {
    final target = direction.normalized();
    final dot = target.y.clamp(-1.0, 1.0).toDouble();
    if (dot > 0.9999) return vm.Quaternion.identity();
    if (dot < -0.9999) {
      return vm.Quaternion.axisAngle(_xAxis, math.pi);
    }
    final axis = _yAxis.cross(target)..normalize();
    return vm.Quaternion.axisAngle(axis, math.acos(dot));
  }

  PhysicallyBasedMaterial _pbr(
    Color color, {
    double roughness = 0.85,
    double metallic = 0.0,
  }) {
    return PhysicallyBasedMaterial()
      ..baseColorFactor = _linear4(color)
      ..roughnessFactor = roughness
      ..metallicFactor = metallic;
  }

  UnlitMaterial _unlit(Color color) {
    return UnlitMaterial()..baseColorFactor = _linear4(color);
  }

  vm.Vector4 _linear4(Color color) {
    return vm.Vector4(
      _srgbToLinear(color.r),
      _srgbToLinear(color.g),
      _srgbToLinear(color.b),
      color.a,
    );
  }

  vm.Vector3 _linear3(Color color) {
    return vm.Vector3(
      _srgbToLinear(color.r),
      _srgbToLinear(color.g),
      _srgbToLinear(color.b),
    );
  }

  double _srgbToLinear(double value) {
    return value <= 0.04045
        ? value / 12.92
        : math.pow((value + 0.055) / 1.055, 2.4).toDouble();
  }
}

class _CloudSeed {
  const _CloudSeed(this.x, this.y, this.scale);

  final double x;
  final double y;
  final double scale;
}

class _HillSeed {
  const _HillSeed(this.x, this.z, this.radius, this.height);

  final double x;
  final double z;
  final double radius;
  final double height;
}

class _WaveSeed {
  const _WaveSeed({
    required this.x,
    required this.z,
    required this.width,
    required this.speed,
  });

  final double x;
  final double z;
  final double width;
  final double speed;
}
