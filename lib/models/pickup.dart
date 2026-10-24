/// 可拾取物：小鱼与两种道具。
enum PickupKind { fish, shield, magnet }

extension PickupKindInfo on PickupKind {
  bool get isPowerUp => this != PickupKind.fish;

  double get radius {
    switch (this) {
      case PickupKind.fish:
        return 14;
      case PickupKind.shield:
      case PickupKind.magnet:
        return 20;
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

/// 世界中的小鱼/道具，[y] 为中心距地面的高度。
class Pickup {
  final int id;
  final PickupKind kind;
  final double x;
  final double y;
  final double phase;

  const Pickup({
    required this.id,
    required this.kind,
    required this.x,
    required this.y,
    this.phase = 0,
  });

  Pickup moveBy(double dx, {double? dy}) => Pickup(
        id: id,
        kind: kind,
        x: x + dx,
        y: dy ?? y,
        phase: phase,
      );

  bool get isOffscreen => x < -80;
}
