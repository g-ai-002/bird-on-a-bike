import '../utils/constants.dart';

/// 路面障碍类型；尺寸与位置全部使用世界单位。
enum ObstacleKind { rock, crate, log, banner }

extension ObstacleKindInfo on ObstacleKind {
  bool get overhead => this == ObstacleKind.banner;

  /// 沿骑行方向的长度。
  double get width {
    switch (this) {
      case ObstacleKind.rock:
        return 4.6;
      case ObstacleKind.crate:
        return 4.4;
      case ObstacleKind.log:
        return 6.2;
      case ObstacleKind.banner:
        return 6.4;
    }
  }

  /// 地面障碍的高度；悬空横幅时为厚度。
  double get height {
    switch (this) {
      case ObstacleKind.rock:
        return 4.0;
      case ObstacleKind.crate:
        return 5.6;
      case ObstacleKind.log:
        return 3.6;
      case ObstacleKind.banner:
        return 4.0;
    }
  }

  /// 沿路面深度方向的厚度，用于深度碰撞盒。
  double get depth {
    switch (this) {
      case ObstacleKind.rock:
        return 2.0;
      case ObstacleKind.crate:
        return 1.6;
      case ObstacleKind.log:
        return 2.4;
      case ObstacleKind.banner:
        return 1.8;
    }
  }

  /// 悬空横幅下沿距地面的高度，其余类型为 0。
  double get clearance => overhead ? 6.8 : 0.0;

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
///
/// [x] 是沿骑行方向的前缘坐标，[z] 是它所在的路面深度。
/// 规则层每帧原地推进实体，避免在渲染循环里反复分配对象；
/// 需要快照时请自行复制坐标，不要把实体当作不可变值使用。
class Obstacle {
  Obstacle({
    required this.id,
    required this.kind,
    required this.x,
    this.z = 0,
  });

  final int id;
  final ObstacleKind kind;

  /// 沿骑行方向的前缘坐标，由 [moveBy] 原地推进。
  double x;

  final double z;

  /// 原地平移并返回自身，方便链式判断是否已移出画面。
  Obstacle moveBy(double dx) {
    x += dx;
    return this;
  }

  double get right => x + kind.width;

  double get centerX => x + kind.width / 2;

  double get centerY => kind.overhead
      ? kind.clearance + kind.height / 2
      : kind.height / 2;

  bool get isOffscreen => right < AppConstants.cullX;
}
