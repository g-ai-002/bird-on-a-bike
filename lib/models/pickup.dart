import '../utils/constants.dart';

/// 可拾取物：小鱼与两种道具；尺寸与坐标使用世界单位。
enum PickupKind { fish, shield, magnet }

extension PickupKindInfo on PickupKind {
  bool get isPowerUp => this != PickupKind.fish;

  double get radius {
    switch (this) {
      case PickupKind.fish:
        return 1.4;
      case PickupKind.shield:
      case PickupKind.magnet:
        return 2.0;
    }
  }

  String get label {
    switch (this) {
      case PickupKind.fish:
        return '小鱼';
      case PickupKind.shield:
        return '护盾';
      case PickupKind.magnet:
        return '磁铁';
    }
  }
}

/// 世界中的小鱼/道具，[y] 为中心离地高度，[z] 为路面深度。
/// 坐标由规则层原地推进，避免每帧复制实体对象。
class Pickup {
  Pickup({
    required this.id,
    required this.kind,
    required this.x,
    required this.y,
    this.z = 0,
    this.phase = 0,
  });

  final int id;
  final PickupKind kind;

  /// 沿骑行方向的位置，由 [moveBy] 原地推进。
  double x;

  /// 中心离地高度，磁铁吸附时会改变。
  double y;

  /// 路面深度，磁铁吸附时会改变。
  double z;

  final double phase;

  /// 原地平移并返回自身；[dy] / [dz] 为绝对坐标而不是增量。
  Pickup moveBy(double dx, {double? dy, double? dz}) {
    x += dx;
    if (dy != null) y = dy;
    if (dz != null) z = dz;
    return this;
  }

  bool get isOffscreen => x < AppConstants.cullX;
}
