import 'dart:math';

import '../models/difficulty.dart';
import '../models/obstacle.dart';
import '../models/pickup.dart';
import '../utils/constants.dart';

/// 相邻障碍的时间间隔（秒），难度越高越密集。
double obstacleGapSeconds(Random random, Difficulty difficulty) {
  return (1.05 + random.nextDouble() * 0.75) * difficulty.spawnScale;
}

/// 悬空横幅需要更长的反应时间，额外放大间隔。
double obstacleGapForKind(double baseGap, ObstacleKind kind) {
  return kind.overhead ? baseGap * 1.45 : baseGap;
}

/// 鱼群的出现间隔。
double fishGapSeconds(Random random) => 1.3 + random.nextDouble() * 1.2;

/// 道具的出现间隔。
double powerUpGapSeconds(Random random) => 17 + random.nextDouble() * 8;

/// 障碍种类抽取：横幅占少数，其余在地面障碍中均分。
ObstacleKind pickObstacleKind(Random random) {
  if (random.nextDouble() < 0.18) return ObstacleKind.banner;
  switch (random.nextInt(3)) {
    case 0:
      return ObstacleKind.rock;
    case 1:
      return ObstacleKind.crate;
    default:
      return ObstacleKind.log;
  }
}

PickupKind pickPowerUpKind(Random random) {
  return random.nextBool() ? PickupKind.shield : PickupKind.magnet;
}

/// 实体在路面深度上的摆位：骑行线以及其两侧各一档。
double pickDepth(Random random) {
  const offsets = <double>[
    -AppConstants.depthSpread,
    0,
    AppConstants.depthSpread,
  ];
  return offsets[random.nextInt(offsets.length)];
}

/// 生成 1~3 条鱼，可能排成一条水平线或一道小弧线。
///
/// 高度范围从贴近地面到二段跳可及的位置，鼓励玩家主动起跳；
/// 同一串鱼共用一个路面深度。
List<Pickup> fishPattern({
  required int startId,
  required double x,
  double z = 0,
  required Random random,
}) {
  final count = 1 + random.nextInt(3);
  final baseY = 3.4 + random.nextDouble() * 10;
  final arc = count > 1 && random.nextBool();
  const spacing = 3.6;
  final pickups = <Pickup>[];
  for (var i = 0; i < count; i++) {
    final t = count == 1 ? 0.0 : i / (count - 1);
    final arcOffset = arc ? sin(pi * t) * 2.6 : 0.0;
    pickups.add(
      Pickup(
        id: startId + i,
        kind: PickupKind.fish,
        x: x + spacing * i,
        y: baseY + arcOffset,
        z: z,
        phase: random.nextDouble() * pi * 2,
      ),
    );
  }
  return pickups;
}
