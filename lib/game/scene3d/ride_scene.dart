import 'dart:math' as math;
import 'dart:ui' show Canvas, Color, PlatformDispatcher, Rect;

import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart' as vm;

import '../../models/difficulty.dart';
import '../../models/game_state.dart';
import '../../models/obstacle.dart';
import '../../models/pickup.dart';
import '../../providers/game_provider.dart';
import '../../utils/constants.dart';
import '../ride_style.dart';
import '../world_layout.dart';

/// 世界坐标驱动的 3D 海岸骑行场景。
///
/// 玩法快照里的坐标就是世界单位，场景不再做像素换算：低多边形鹈鹕、
/// 自行车、礁石/木箱/浮木/横幅与小鱼都直接摆到对应位置，背景是渐变
/// 天空、海面、远山与夕阳。相机会随速度轻微后拉并跟随跳跃高度，
/// 撞车反馈仍由 Flame 的取景器缩放与震动完成。
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
  late final CylinderGeometry _bill;

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
  late final PhysicallyBasedMaterial _rockLightMat;
  late final PhysicallyBasedMaterial _woodLightMat;
  late final PhysicallyBasedMaterial _metalMat;
  late final PhysicallyBasedMaterial _beakDarkMat;
  late final PhysicallyBasedMaterial _pouchDarkMat;
  late final UnlitMaterial _sunMat;
  late final UnlitMaterial _shadowMat;
  late final UnlitMaterial _fishMat;
  late final UnlitMaterial _fishDarkMat;
  late final UnlitMaterial _shieldMat;
  late final UnlitMaterial _magnetMat;
  late final UnlitMaterial _redMat;
  late final UnlitMaterial _eyeGlintMat;
  late final UnlitMaterial _edgeMat;
  late final UnlitMaterial _outlineMat;

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
  late final Node _footA;
  late final Node _footB;

  final Map<int, Node> _obstacleNodes = {};
  final Map<int, Node> _pickupNodes = {};
  final Map<int, ObstacleKind> _obstacleKinds = {};
  final Map<int, PickupKind> _pickupKinds = {};
  final Map<ObstacleKind, List<Node>> _obstaclePool = {};
  final Map<PickupKind, List<Node>> _pickupPool = {};
  final Map<ObstacleKind, List<Mesh>> _obstacleMeshes = {};
  final Map<PickupKind, List<Mesh>> _pickupMeshes = {};

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

    final dpr =
        PlatformDispatcher.instance.implicitView?.devicePixelRatio ?? 1.0;
    scene
      ..antiAliasingMode = AntiAliasingMode.fxaa
      ..renderScale = dpr >= 2.0 ? 0.85 : 1.0;

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

    // 预热合并后的障碍/拾取物网格，避免首次生成时卡顿
    for (final kind in ObstacleKind.values) {
      _obstacleMeshes[kind] = _mergeNodeMeshes(_buildObstacle(kind));
    }
    for (final kind in PickupKind.values) {
      _pickupMeshes[kind] = _mergeNodeMeshes(_buildPickup(kind));
    }

    _syncRider();
    _syncObstacles();
    _syncPickups();
    _syncScenery();
  }

  void update(double dt) {
    _elapsed += dt;
    final state = provider.state;
    if (state.isPlaying) {
      _wheelAngle -= state.speed * WorldLayout.unitsPerMeter * dt / 24;
      _wingPhase += dt * (state.rider.airborne ? 13.0 : 5.5);
    }

    _syncRider();
    _syncObstacles();
    _syncPickups();
    _syncScenery();
    _updateCamera(dt, state);
    scene.update(dt);
  }

  void render(Canvas canvas, Rect viewport) {
    final dpr =
        PlatformDispatcher.instance.implicitView?.devicePixelRatio ?? 1.0;
    scene.render(
      camera,
      canvas,
      viewport: viewport,
      pixelRatio: math.min(dpr, 1.5),
    );
  }

  /// 相机随速度后拉、随跳跃抬高视线，并保留一点海浪般的横向漂移。
  void _updateCamera(double dt, GameState state) {
    final baseSpeed = state.difficulty.baseSpeed;
    final speedT =
        ((state.speed - baseSpeed) / (AppConstants.maxSpeed - baseSpeed))
            .clamp(0.0, 1.0)
            .toDouble();
    final follow = (1 - math.exp(-dt * 4.5)).clamp(0.0, 1.0).toDouble();

    final desiredY = 16 + speedT * 1.6;
    final desiredZ = -52 - speedT * 4;
    final desiredTargetY = 14 + state.rider.height * 0.08;

    camera.position.y += (desiredY - camera.position.y) * follow;
    camera.position.z += (desiredZ - camera.position.z) * follow;
    camera.position.x = math.sin(_elapsed * 0.55) * 0.3 * (0.4 + speedT);
    camera.target.y += (desiredTargetY - camera.target.y) * follow;
  }

  // ---------------------------------------------------------------------------
  // 资源
  // ---------------------------------------------------------------------------

  void _createAssets() {
    _cube = CuboidGeometry(vm.Vector3(1, 1, 1));
    _cylinder = CylinderGeometry(radialSegments: 20);
    _cone = CylinderGeometry(topRadius: 0, radialSegments: 16);
    _sphere = SphereGeometry(radius: 1, segments: 20, rings: 14);
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
    _thinRing = TorusGeometry(
      radius: 1,
      tubeRadius: 0.02,
      radialSegments: 24,
      tubularSegments: 6,
    );
    _disc = DiscGeometry(radius: 1, segments: 28);
    _rock = IcosphereGeometry(radius: 1, subdivisions: 1);
    _bill = CylinderGeometry(topRadius: 0.12, radialSegments: 16);

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
    _rockLightMat = _pbr(const Color(0xFFB6B6B6), roughness: 1.0);
    _woodLightMat = _pbr(const Color(0xFFD9A066), roughness: 0.9);
    _metalMat = _pbr(const Color(0xFFB8C2C8), roughness: 0.35, metallic: 0.8);
    _beakDarkMat = _pbr(const Color(0xFFD97A1E), roughness: 0.5);
    _pouchDarkMat = _pbr(const Color(0xFFE08A2E), roughness: 0.75);
    _sunMat = _unlit(RideColors.sun);
    _shadowMat = _unlit(const Color(0xFF2A2A2A));
    _fishMat = _unlit(RideColors.fish);
    _fishDarkMat = _unlit(RideColors.fishDark);
    _shieldMat = _unlit(RideColors.shield);
    _magnetMat = _unlit(RideColors.magnet);
    _redMat = _unlit(const Color(0xFFE05A5A));
    _eyeGlintMat = _unlit(const Color(0xFFFFFDF2));
    _edgeMat = _unlit(const Color(0xFFFFE2A8));
    _outlineMat = _unlit(const Color(0xFF151515));
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
    _rider = Node()
      ..position = vm.Vector3(WorldLayout.riderX, 0, WorldLayout.riderZ);
    scene.add(_rider);

    _riderShadow = _node(
      _disc,
      _shadowMat,
      position: vm.Vector3(WorldLayout.riderX, 0.03, WorldLayout.riderZ),
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
      _rod(
        crank + vm.Vector3(0, 0.26, 0.24),
        rear + vm.Vector3(0, 0.26, 0.24),
        0.035,
        _tyreMat,
      ),
      _rod(
        crank + vm.Vector3(0, -0.26, 0.24),
        rear + vm.Vector3(0, -0.26, 0.24),
        0.035,
        _tyreMat,
      ),
      _box(vm.Vector3(2.9, 0.1, 0.55), _frameMat, vm.Vector3(2.7, 4.92, 0)),
      _box(vm.Vector3(2.9, 0.1, 0.55), _frameMat, vm.Vector3(-2.7, 4.92, 0)),
      _rod(
        vm.Vector3(2.25, 5.35, -0.65),
        vm.Vector3(2.25, 5.35, 0.65),
        0.11,
        _frameDarkMat,
      ),
      _node(
        _sphere,
        _metalMat,
        position: vm.Vector3(2.25, 5.35, 0.7),
        scale: vm.Vector3.all(0.12),
      ),
      _node(
        _sphere,
        _metalMat,
        position: vm.Vector3(2.05, 5.58, 0.3),
        scale: vm.Vector3.all(0.16),
      ),
      _rod(
        head + vm.Vector3(0, 0, 0.22),
        front + vm.Vector3(0, 0, 0.22),
        0.055,
        _frameDarkMat,
      ),
      _rod(
        head + vm.Vector3(0, 0, -0.22),
        front + vm.Vector3(0, 0, -0.22),
        0.055,
        _frameDarkMat,
      ),
      _rod(
        vm.Vector3(-1.45, 4.68, 0.35),
        vm.Vector3(-0.95, 4.38, 0.35),
        0.04,
        _metalMat,
      ),
      _rod(
        vm.Vector3(-1.45, 4.68, -0.35),
        vm.Vector3(-0.95, 4.38, -0.35),
        0.04,
        _metalMat,
      ),
      for (final x in <double>[1.95, 2.35, 2.75])
        _box(
          vm.Vector3(0.08, 0.9, 0.06),
          _crateDarkMat,
          vm.Vector3(x, 5.0, -0.53),
        ),
      for (final y in <double>[4.75, 5.25])
        _box(
          vm.Vector3(1.1, 0.06, 0.06),
          _crateDarkMat,
          vm.Vector3(2.35, y, -0.53),
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
    _footA = _box(vm.Vector3(0.6, 0.12, 0.28), _legMat, vm.Vector3.zero());
    _footB = _box(vm.Vector3(0.6, 0.12, 0.28), _legMat, vm.Vector3.zero());
    _rider.addAll([_crankArmA, _crankArmB, _pedalA, _pedalB, _footA, _footB]);

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

    // 躯干：主身体、腹部阴影、胸口
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
        _sphere,
        _featherShadeMat,
        position: vm.Vector3(0.7, -0.05, 0.25),
        scale: vm.Vector3(1.8, 0.65, 1.35),
      ),
    );
    _torso.add(
      _node(
        _sphere,
        _featherMat,
        position: vm.Vector3(2.0, 1.0, 0.05),
        scale: vm.Vector3(1.45, 1.5, 1.45),
      ),
    );

    // 尾羽
    _torso.add(
      _node(
        _cone,
        _featherShadeMat,
        position: vm.Vector3(-2.2, 0.5, 0),
        scale: vm.Vector3(1.9, 1.2, 1.0),
        rotation: vm.Quaternion.axisAngle(_zAxis, math.pi / 2),
      ),
    );
    _torso.add(
      _node(
        _cone,
        _featherShadeMat,
        position: vm.Vector3(-2.0, 0.95, 0.25),
        scale: vm.Vector3(1.5, 0.8, 0.8),
        rotation: vm.Quaternion.axisAngle(_zAxis, math.pi / 2 - 0.25),
      ),
    );
    _torso.add(
      _node(
        _cone,
        _featherShadeMat,
        position: vm.Vector3(-2.0, 0.15, -0.25),
        scale: vm.Vector3(1.5, 0.8, 0.8),
        rotation: vm.Quaternion.axisAngle(_zAxis, math.pi / 2 + 0.25),
      ),
    );

    // 脖子：三段曲线 + 关节
    final neck1 = vm.Vector3(1.2, 1.5, 0);
    final neck2 = vm.Vector3(1.7, 2.3, 0);
    final neck3 = vm.Vector3(2.2, 2.9, 0);
    final neck4 = vm.Vector3(2.55, 3.15, 0);
    _torso.add(_rod(neck1, neck2, 0.54, _featherMat));
    _torso.add(_rod(neck2, neck3, 0.5, _featherMat));
    _torso.add(_rod(neck3, neck4, 0.46, _featherMat));
    _torso.add(
      _node(_sphere, _featherMat, position: neck2, scale: vm.Vector3.all(0.54)),
    );
    _torso.add(
      _node(_sphere, _featherMat, position: neck3, scale: vm.Vector3.all(0.5)),
    );

    // 头、脸颊与眼睛
    _torso.add(
      _node(
        _sphere,
        _featherMat,
        position: vm.Vector3(2.65, 3.35, 0),
        scale: vm.Vector3.all(1.1),
      ),
    );
    _torso.add(
      _node(
        _sphere,
        _pouchMat,
        position: vm.Vector3(2.95, 3.48, -0.78),
        scale: vm.Vector3(0.58, 0.46, 0.14),
      ),
    );

    // 卡通大眼：眼白、深色瞳孔和高光都朝相机一侧（-Z）
    final eyeCenter = vm.Vector3(2.98, 3.72, -0.98);
    _torso.add(
      _node(
        _sphere,
        _eyeGlintMat,
        position: eyeCenter,
        scale: vm.Vector3(0.4, 0.46, 0.22),
      ),
    );
    _torso.add(
      _node(
        _sphere,
        _eyeMat,
        position: eyeCenter + vm.Vector3(0.05, -0.01, -0.18),
        scale: vm.Vector3(0.25, 0.3, 0.16),
      ),
    );
    _torso.add(
      _node(
        _sphere,
        _eyeGlintMat,
        position: eyeCenter + vm.Vector3(0.13, 0.13, -0.32),
        scale: vm.Vector3(0.09, 0.09, 0.06),
      ),
    );
    _torso.add(
      _node(
        _sphere,
        _featherShadeMat,
        position: vm.Vector3(2.98, 4.02, -0.76),
        scale: vm.Vector3(0.4, 0.1, 0.16),
      ),
    );

    // 大嘴：扁长上喙 + 下喙缘 + 钩尖 + 喉囊
    final billBase = vm.Vector3(3.0, 3.25, 0);
    final billTip = vm.Vector3(6.3, 2.72, 0);
    _torso.add(_billRod(billBase, billTip, 0.64, 0.55, _beakMat));
    _torso.add(
      _billRod(
        billBase + vm.Vector3(0, 0.14, -0.02),
        billTip + vm.Vector3(0, 0.02, -0.02),
        0.06,
        0.8,
        _beakDarkMat,
      ),
    );
    _torso.add(
      _billRod(
        billBase + vm.Vector3(0, -0.12, 0),
        billTip + vm.Vector3(0, -0.06, 0),
        0.08,
        0.8,
        _beakMat,
      ),
    );
    _torso.add(
      _node(
        _sphere,
        _beakDarkMat,
        position: billTip + vm.Vector3(0.1, -0.16, 0),
        scale: vm.Vector3(0.22, 0.28, 0.22),
      ),
    );
    _torso.add(
      _node(
        _sphere,
        _pouchMat,
        position: vm.Vector3(4.4, 2.45, 0.05),
        scale: vm.Vector3(2.05, 0.62, 0.72),
      ),
    );
    _torso.add(
      _node(
        _sphere,
        _pouchMat,
        position: vm.Vector3(3.35, 2.55, 0),
        scale: vm.Vector3(1.0, 0.55, 0.62),
      ),
    );
    _torso.add(
      _billRod(
        vm.Vector3(3.25, 2.32, 0),
        vm.Vector3(6.0, 2.52, 0),
        0.05,
        0.7,
        _pouchDarkMat,
      ),
    );
    _torso.add(
      _node(
        _sphere,
        _eyeMat,
        position: vm.Vector3(3.55, 3.28, 0.25),
        scale: vm.Vector3.all(0.06),
      ),
    );

    // 冠羽
    _torso.add(
      _node(
        _cone,
        _featherShadeMat,
        position: vm.Vector3(2.3, 4.45, 0),
        scale: vm.Vector3(0.28, 0.95, 0.28),
        rotation: vm.Quaternion.axisAngle(_zAxis, 0.15),
      ),
    );
    _torso.add(
      _node(
        _cone,
        _featherShadeMat,
        position: vm.Vector3(2.0, 4.3, 0),
        scale: vm.Vector3(0.22, 0.75, 0.22),
        rotation: vm.Quaternion.axisAngle(_zAxis, 0.35),
      ),
    );
    _torso.add(
      _node(
        _cone,
        _featherShadeMat,
        position: vm.Vector3(2.55, 4.3, 0),
        scale: vm.Vector3(0.18, 0.65, 0.18),
        rotation: vm.Quaternion.axisAngle(_zAxis, -0.25),
      ),
    );

    // 双翼：肩部、主翼、翼尖与羽层
    _nearWing = Node()..position = vm.Vector3(0.6, 1.6, 0.9);
    _farWing = Node()..position = vm.Vector3(0.6, 1.6, -0.85);
    _torso.add(_nearWing);
    _torso.add(_farWing);
    _nearWing.add(
      _node(
        _sphere,
        _featherMat,
        position: vm.Vector3(-1.0, 0, 0),
        scale: vm.Vector3(2.0, 1.05, 0.35),
      ),
    );
    _nearWing.add(
      _node(
        _sphere,
        _featherShadeMat,
        position: vm.Vector3(-2.1, -0.1, 0.02),
        scale: vm.Vector3(1.1, 0.62, 0.3),
      ),
    );
    for (final x in <double>[-1.2, -1.7, -2.2]) {
      _nearWing.add(
        _node(
          _sphere,
          _featherShadeMat,
          position: vm.Vector3(x, -0.35, 0.05),
          scale: vm.Vector3(0.75, 0.16, 0.18),
        ),
      );
    }
    _farWing.add(
      _node(
        _sphere,
        _featherShadeMat,
        position: vm.Vector3(-1.0, 0, 0),
        scale: vm.Vector3(1.9, 1.0, 0.33),
      ),
    );
    _farWing.add(
      _node(
        _sphere,
        _featherShadeMat,
        position: vm.Vector3(-2.0, -0.1, 0.02),
        scale: vm.Vector3(1.0, 0.58, 0.28),
      ),
    );

    // 围巾
    _scarf = Node()..position = vm.Vector3(2.2, 3.45, 0);
    _torso.add(_scarf);
    _scarf.add(_node(_sphere, _scarfMat, scale: vm.Vector3.all(0.22)));
    for (var i = 0; i < 4; i++) {
      _scarf.add(
        _box(
          vm.Vector3(0.8, 0.14, 0.3),
          _scarfMat,
          vm.Vector3(-0.45 - i * 0.72, -0.1 - i * 0.06, i.isEven ? 0.1 : -0.1),
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
      WorldLayout.riderX,
      state.rider.height,
      WorldLayout.riderZ,
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

    final jump = state.rider.height;
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
    _footA.position = pedalNear + vm.Vector3(0, 0.1, 0);
    _footB.position = pedalFar + vm.Vector3(0, 0.1, 0);
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
        node = _takeObstacleNode(obstacle.kind);
        _obstacleNodes[obstacle.id] = node;
        _obstacleKinds[obstacle.id] = obstacle.kind;
      }
      node.position = vm.Vector3(obstacle.centerX, 0, obstacle.z);
    }

    for (final id in _obstacleNodes.keys.toList()) {
      if (alive.contains(id)) continue;
      final node = _obstacleNodes.remove(id);
      final kind = _obstacleKinds.remove(id);
      if (node == null) continue;
      node.visible = false;
      if (kind != null) {
        _obstaclePool.putIfAbsent(kind, () => []).add(node);
      }
    }
  }

  Node _takeObstacleNode(ObstacleKind kind) {
    final pooled = _obstaclePool[kind];
    if (pooled != null && pooled.isNotEmpty) {
      final node = pooled.removeLast();
      node.visible = true;
      return node;
    }
    final meshes = _obstacleMeshes[kind] ??= _mergeNodeMeshes(
      _buildObstacle(kind),
    );
    final node = _nodeFromMeshes(meshes);
    scene.add(node);
    return node;
  }

  Node _buildObstacle(ObstacleKind kind) {
    final width = kind.width;
    final height = kind.height;
    final root = Node();

    switch (kind) {
      case ObstacleKind.rock:
        // 深色背壳勾出轮廓
        root.add(
          _node(
            _rock,
            _outlineMat,
            position: vm.Vector3(0, height * 0.45, 0.55),
            scale: vm.Vector3(width * 0.6, height * 0.55, 0.9),
          ),
        );
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
        root.add(
          _node(
            _rock,
            _rockLightMat,
            position: vm.Vector3(-width * 0.12, height * 0.7, -0.65),
            scale: vm.Vector3(width * 0.16, height * 0.14, 0.3),
          ),
        );
        final crack = _box(
          vm.Vector3(width * 0.42, 0.07, 0.05),
          _edgeMat,
          vm.Vector3(0, height * 0.5, -0.96),
        );
        crack.rotation = vm.Quaternion.axisAngle(_zAxis, 0.45);
        root.add(crack);
        for (final x in <double>[-width * 0.34, width * 0.3]) {
          root.add(
            _node(
              _rock,
              _rockMat,
              position: vm.Vector3(x, height * 0.16, -0.55),
              scale: vm.Vector3(width * 0.12, height * 0.12, 0.35),
            ),
          );
        }
        break;
      case ObstacleKind.crate:
        // 深色背板 + 正面木框与金属角码
        root.add(
          _box(
            vm.Vector3(width * 1.08, height * 1.08, 0.12),
            _outlineMat,
            vm.Vector3(0, height / 2, 0.55),
          ),
        );
        root.add(
          _box(
            vm.Vector3(width, height, 1.6),
            _crateMat,
            vm.Vector3(0, height / 2, 0),
          ),
        );
        const frameZ = -0.82;
        root.add(
          _box(
            vm.Vector3(width * 1.06, 0.16, 0.12),
            _crateDarkMat,
            vm.Vector3(0, 0.1, frameZ),
          ),
        );
        root.add(
          _box(
            vm.Vector3(width * 1.06, 0.16, 0.12),
            _crateDarkMat,
            vm.Vector3(0, height - 0.1, frameZ),
          ),
        );
        root.add(
          _box(
            vm.Vector3(0.16, height * 1.04, 0.12),
            _crateDarkMat,
            vm.Vector3(-width / 2 + 0.08, height / 2, frameZ),
          ),
        );
        root.add(
          _box(
            vm.Vector3(0.16, height * 1.04, 0.12),
            _crateDarkMat,
            vm.Vector3(width / 2 - 0.08, height / 2, frameZ),
          ),
        );
        for (final sign in <double>[-1, 1]) {
          final bar = _box(
            vm.Vector3(width * 1.12, 0.2, 0.12),
            _crateDarkMat,
            vm.Vector3(0, height / 2, frameZ - 0.02),
          );
          bar.rotation = vm.Quaternion.axisAngle(_zAxis, sign * math.pi / 4);
          root.add(bar);
        }
        final highlight = _box(
          vm.Vector3(width * 1.02, 0.06, 0.13),
          _edgeMat,
          vm.Vector3(0, height / 2, frameZ - 0.06),
        );
        highlight.rotation = vm.Quaternion.axisAngle(_zAxis, math.pi / 4);
        root.add(highlight);
        for (final y in <double>[height * 0.34, height * 0.67]) {
          root.add(
            _box(
              vm.Vector3(width * 0.96, 0.07, 0.1),
              _crateDarkMat,
              vm.Vector3(0, y, frameZ - 0.01),
            ),
          );
        }
        for (final x in <double>[-width / 2, width / 2]) {
          for (final y in <double>[0.25, height - 0.25]) {
            root.add(
              _box(
                vm.Vector3(0.5, 0.5, 0.13),
                _metalMat,
                vm.Vector3(x, y, frameZ - 0.04),
              ),
            );
          }
        }
        root.add(
          _box(
            vm.Vector3(width * 1.02, 0.08, 0.14),
            _edgeMat,
            vm.Vector3(0, height + 0.02, frameZ + 0.02),
          ),
        );
        root.add(
          _box(
            vm.Vector3(1.3, 0.55, 0.08),
            _edgeMat,
            vm.Vector3(0, height * 0.55, frameZ - 0.08),
          ),
        );
        root.add(
          _box(
            vm.Vector3(1.08, 0.36, 0.09),
            _crateDarkMat,
            vm.Vector3(0, height * 0.55, frameZ - 0.13),
          ),
        );
        break;
      case ObstacleKind.log:
        // 深色背壳 + 亮色切面与年轮
        root.add(
          _node(
            _cylinder,
            _outlineMat,
            position: vm.Vector3(0, height / 2, 0.3),
            scale: vm.Vector3(height * 1.08, width * 1.02, height * 1.08),
            rotation: vm.Quaternion.axisAngle(_zAxis, math.pi / 2),
          ),
        );
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
            _woodLightMat,
            position: vm.Vector3(width / 2 + 0.02, height / 2, 0),
            scale: vm.Vector3(height * 0.95, height * 0.95, 1),
            rotation: vm.Quaternion.axisAngle(_zAxis, -math.pi / 2),
          ),
        );
        for (final factor in <double>[0.35, 0.62, 0.82]) {
          root.add(
            _node(
              _thinRing,
              _crateDarkMat,
              position: vm.Vector3(width / 2 + 0.04, height / 2, 0),
              scale: vm.Vector3.all(height * factor),
              rotation: vm.Quaternion.axisAngle(_zAxis, -math.pi / 2),
            ),
          );
        }
        root.add(
          _node(
            _thinRing,
            _outlineMat,
            position: vm.Vector3(width / 2 + 0.03, height / 2, 0),
            scale: vm.Vector3.all(height * 0.5),
            rotation: vm.Quaternion.axisAngle(_zAxis, -math.pi / 2),
          ),
        );
        for (final x in <double>[-width * 0.22, width * 0.12]) {
          root.add(
            _node(
              _ring,
              _crateDarkMat,
              position: vm.Vector3(x, height / 2, 0),
              scale: vm.Vector3.all(height * 0.5),
              rotation: vm.Quaternion.axisAngle(_zAxis, math.pi / 2),
            ),
          );
        }
        for (final y in <double>[height * 0.3, height * 0.52, height * 0.74]) {
          root.add(
            _box(
              vm.Vector3(width * 0.7, 0.05, 0.06),
              _crateDarkMat,
              vm.Vector3(-width * 0.05, y, -height * 0.5),
            ),
          );
        }
        root.add(
          _box(
            vm.Vector3(width * 0.8, 0.06, 0.3),
            _edgeMat,
            vm.Vector3(-width * 0.05, height + 0.02, 0),
          ),
        );
        root.add(
          _coneRod(
            vm.Vector3(width * 0.18, height * 0.95, -0.1),
            vm.Vector3(width * 0.3, height * 1.25, -0.2),
            0.18,
            _logMat,
          ),
        );
        break;
      case ObstacleKind.banner:
        final clearance = kind.clearance;
        final poleTop = clearance + height + 1.6;
        root.add(
          _box(
            vm.Vector3(width * 1.05, height * 1.08, 0.1),
            _outlineMat,
            vm.Vector3(0, clearance + height / 2, 0.42),
          ),
        );
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
        for (final x in <double>[-width / 2, width / 2]) {
          for (final y in <double>[0.5, poleTop - 0.4]) {
            root.add(
              _node(
                _ring,
                _metalMat,
                position: vm.Vector3(x, y, 0),
                scale: vm.Vector3.all(0.22),
              ),
            );
          }
        }
        root.add(
          _box(
            vm.Vector3(width, height, 0.7),
            _bannerMat,
            vm.Vector3(0, clearance + height / 2, 0),
          ),
        );
        const bannerZ = -0.38;
        root.add(
          _box(
            vm.Vector3(width * 1.02, 0.14, 0.1),
            _edgeMat,
            vm.Vector3(0, clearance + 0.07, bannerZ),
          ),
        );
        root.add(
          _box(
            vm.Vector3(width * 1.02, 0.14, 0.1),
            _edgeMat,
            vm.Vector3(0, clearance + height - 0.07, bannerZ),
          ),
        );
        root.add(
          _box(
            vm.Vector3(0.14, height * 0.94, 0.1),
            _edgeMat,
            vm.Vector3(-width / 2 + 0.07, clearance + height / 2, bannerZ),
          ),
        );
        root.add(
          _box(
            vm.Vector3(0.14, height * 0.94, 0.1),
            _edgeMat,
            vm.Vector3(width / 2 - 0.07, clearance + height / 2, bannerZ),
          ),
        );
        for (var i = 0; i < 4; i++) {
          root.add(
            _box(
              vm.Vector3(0.55, height * 0.58, 0.1),
              _whiteMat,
              vm.Vector3(
                -width / 2 + width * (0.16 + i * 0.22),
                clearance + height / 2,
                bannerZ - 0.02,
              ),
            ),
          );
        }
        final diamond = _box(
          vm.Vector3(0.85, 0.85, 0.1),
          _edgeMat,
          vm.Vector3(0, clearance + height / 2, bannerZ - 0.05),
        );
        diamond.rotation = vm.Quaternion.axisAngle(_zAxis, math.pi / 4);
        root.add(diamond);
        root.add(
          _rod(
            vm.Vector3(-width / 2, poleTop, 0),
            vm.Vector3(width / 2, poleTop, 0),
            0.03,
            _bannerPoleMat,
          ),
        );
        for (final x in <double>[-width / 2, width / 2]) {
          root.add(
            _node(
              _sphere,
              _edgeMat,
              position: vm.Vector3(x, poleTop + 0.06, 0),
              scale: vm.Vector3.all(0.18),
            ),
          );
          root.add(
            _box(
              vm.Vector3(0.34, 0.12, 0.34),
              _outlineMat,
              vm.Vector3(x, 0.06, 0),
            ),
          );
        }
        break;
    }

    root.add(
      _node(
        _disc,
        _outlineMat,
        position: vm.Vector3(0, 0.02, 0),
        scale: vm.Vector3(width * 0.58, 1, 0.8),
      ),
    );
    root.add(
      _node(
        _disc,
        _shadowMat,
        position: vm.Vector3(0, 0.04, 0),
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
        node = _takePickupNode(pickup.kind);
        _pickupNodes[pickup.id] = node;
        _pickupKinds[pickup.id] = pickup.kind;
      }
      final bob = math.sin(_elapsed * 3 + pickup.phase) * 0.5;
      node.position = vm.Vector3(
        pickup.x,
        pickup.y + bob,
        pickup.z,
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
      final kind = _pickupKinds.remove(id);
      if (node == null) continue;
      node.visible = false;
      if (kind != null) {
        _pickupPool.putIfAbsent(kind, () => []).add(node);
      }
    }
  }

  Node _takePickupNode(PickupKind kind) {
    final pooled = _pickupPool[kind];
    if (pooled != null && pooled.isNotEmpty) {
      final node = pooled.removeLast();
      node.visible = true;
      return node;
    }
    final meshes = _pickupMeshes[kind] ??= _mergeNodeMeshes(_buildPickup(kind));
    final node = _nodeFromMeshes(meshes);
    scene.add(node);
    return node;
  }

  Node _nodeFromMeshes(List<Mesh> meshes) {
    final node = Node();
    for (final mesh in meshes) {
      node.add(Node(mesh: mesh));
    }
    return node;
  }

  List<Mesh> _mergeNodeMeshes(Node root) {
    final groups = <Material, List<MeshData>>{};
    final dataCache = <Geometry, MeshData>{};
    void visit(Node node) {
      final mesh = node.mesh;
      if (mesh != null) {
        final transform = node.globalTransform;
        for (final primitive in mesh.primitives) {
          final source = dataCache.putIfAbsent(
            primitive.geometry,
            primitive.geometry.extractMeshData,
          );
          groups
              .putIfAbsent(primitive.material, () => [])
              .add(source.transformed(transform));
        }
      }
      for (final child in node.children) {
        visit(child);
      }
    }

    visit(root);
    return [
      for (final entry in groups.entries)
        Mesh(
          MeshGeometry.fromMeshData(
            MeshData.merge(entry.value),
            retainCpuData: false,
          ),
          entry.key,
        ),
    ];
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
    // 距离以米记录，1 米 = 10 世界单位，滚动量正好等于 distance。
    final scroll = provider.state.distance;

    const dashSpan = 9.2;
    final dashOffset = scroll;
    for (var i = 0; i < _dashes.length; i++) {
      final raw = -48 + (i * dashSpan - dashOffset) % 96;
      final x = raw < -48 ? raw + 96 : raw;
      _dashes[i].position = vm.Vector3(x, 0.03, -2.4);
    }

    for (var i = 0; i < _waves.length; i++) {
      final seed = _waveSeeds[i];
      final travel = scroll * seed.speed;
      final raw = -40 + (seed.x + 40 - travel) % 80;
      final x = raw < -40 ? raw + 80 : raw;
      _waves[i].position = vm.Vector3(x, -2.3, seed.z);
    }

    final cloudTravel = scroll * 0.06;
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

  Node _billRod(
    vm.Vector3 a,
    vm.Vector3 b,
    double radius,
    double flatten,
    Material material,
  ) {
    final node = _node(_bill, material);
    _placeRod(node, a, b, radius, flatten: flatten);
    return node;
  }

  void _placeRod(
    Node node,
    vm.Vector3 a,
    vm.Vector3 b,
    double radius, {
    double flatten = 1.0,
  }) {
    final delta = b - a;
    final length = math.max(delta.length, 0.001);
    node.position = (a + b) * 0.5;
    node.scale = vm.Vector3(radius * 2, length, radius * 2 * flatten);
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
