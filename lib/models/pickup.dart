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
class Pickup {
  final int id;
  final PickupKind kind;
  final double x;
  final double y;
  final double z;
  final double phase;

  const Pickup({
    required this.id,
    required this.kind,
    required this.x,
    required this.y,
    this.z = 0,
    this.phase = 0,
  });

  Pickup moveBy(double dx, {double? dy, double? dz}) => Pickup(
        id: id,
        kind: kind,
        x: x + dx,
        y: dy ?? y,
        z: dz ?? z,
        phase: phase,
      );

  bool get isOffscreen => x < AppConstants.cullX;
}
