/// 路面障碍类型。
enum ObstacleKind { rock, crate, log, banner }

extension ObstacleKindInfo on ObstacleKind {
  bool get overhead => this == ObstacleKind.banner;

  double get width {
    switch (this) {
      case ObstacleKind.rock:
        return 46;
      case ObstacleKind.crate:
        return 44;
      case ObstacleKind.log:
        return 62;
      case ObstacleKind.banner:
        return 64;
    }
  }

  /// 地面障碍的高度；悬空横幅时为厚度。
  double get height {
    switch (this) {
      case ObstacleKind.rock:
        return 40;
      case ObstacleKind.crate:
        return 56;
      case ObstacleKind.log:
        return 36;
      case ObstacleKind.banner:
        return 40;
    }
  }

  /// 悬空横幅下沿距地面的高度，其余类型为 0。
  double get clearance => overhead ? 68.0 : 0.0;

  double get thickness => overhead ? height : 0.0;

  String get label {
    switch (this) {
      case ObstacleKind.rock:
        return '礁石';
      case ObstacleKind.crate:
        return '木箱';
      case ObstacleKind.log:
        return '浮木';
      case ObstacleKind.banner:
        return '横幅';
    }
  }
}

/// 一个沿路面从右向左移动的障碍。
class Obstacle {
  final int id;
  final ObstacleKind kind;
  final double x;

  const Obstacle({
    required this.id,
    required this.kind,
    required this.x,
  });

  Obstacle moveBy(double dx) => Obstacle(id: id, kind: kind, x: x + dx);

  double get right => x + kind.width;

  bool get isOffscreen => right < -80;
}
