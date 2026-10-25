/// 鹈鹕的纵向运动状态：与渲染无关的纯物理模型（世界单位）。
///
/// [height] 是车轮底部离地高度，[velocity] 向上为正；10 单位 = 1 米。
class RiderMotion {
  static const double gravity = 210;
  static const double jumpVelocity = 66;
  static const double doubleJumpVelocity = 58;
  static const double jumpCutFactor = 0.45;
  static const double duckGravityScale = 2.3;
  static const int maxJumps = 2;

  /// 站立/俯身时的碰撞盒高度（略小于美术高度，判定更宽容）。
  static const double standingHeight = 9.6;
  static const double duckHeight = 6.0;

  final double height;
  final double velocity;
  final int jumps;
  final bool ducking;

  const RiderMotion({
    this.height = 0,
    this.velocity = 0,
    this.jumps = 0,
    this.ducking = false,
  });

  static const RiderMotion grounded = RiderMotion();

  bool get airborne => height > 0.0001 || velocity > 0;

  bool get canJump => jumps < maxJumps;

  double get bodyHeight => ducking ? duckHeight : standingHeight;

  /// 碰撞盒顶部离地高度。
  double get top => height + bodyHeight;

  RiderMotion copyWith({
    double? height,
    double? velocity,
    int? jumps,
    bool? ducking,
  }) {
    return RiderMotion(
      height: height ?? this.height,
      velocity: velocity ?? this.velocity,
      jumps: jumps ?? this.jumps,
      ducking: ducking ?? this.ducking,
    );
  }

  /// 起跳：地面跳与空中二段跳使用不同冲量；俯身时起跳会先站起。
  RiderMotion jump() {
    if (!canJump) return this;
    final impulse = jumps == 0 ? jumpVelocity : doubleJumpVelocity;
    return copyWith(
      velocity: impulse,
      jumps: jumps + 1,
      ducking: false,
    );
  }

  /// 松开跳跃键时截断上升速度，实现可变跳跃高度。
  RiderMotion cutJump() {
    if (velocity <= 0) return this;
    return copyWith(velocity: velocity * jumpCutFactor);
  }

  RiderMotion withDucking(bool value) {
    if (ducking == value) return this;
    return copyWith(ducking: value);
  }

  /// 推进一帧；俯身会加速下坠，落地后重置跳跃次数。
  RiderMotion step(double dt) {
    if (dt <= 0) return this;
    final g = ducking ? gravity * duckGravityScale : gravity;
    var v = velocity - g * dt;
    var h = height + v * dt;
    var jumpsLeft = jumps;
    if (h <= 0) {
      h = 0;
      v = 0;
      jumpsLeft = 0;
    }
    return RiderMotion(
      height: h,
      velocity: v,
      jumps: jumpsLeft,
      ducking: ducking,
    );
  }
}
