import '../models/obstacle.dart';
import '../models/pickup.dart';
import '../models/rider_motion.dart';
import '../utils/constants.dart';

/// 碰撞盒横向内缩，判定比美术略宽容。
const double _hitInset = 4;

/// 鹈鹕是否撞上某个障碍。
///
/// 地面障碍看车轮底部高度；悬空横幅看身体上沿与横幅下沿的关系，
/// 因此站立必撞、俯身可通过、跳得足够高也能从上方越过。
bool riderHitsObstacle(
  Obstacle obstacle,
  RiderMotion rider, {
  double riderX = AppConstants.riderX,
}) {
  final left = riderX - AppConstants.riderHalfWidth;
  final right = riderX + AppConstants.riderHalfWidth;
  if (obstacle.right < left + _hitInset || obstacle.x > right - _hitInset) {
    return false;
  }

  final kind = obstacle.kind;
  if (kind.overhead) {
    final bandBottom = kind.clearance;
    final bandTop = bandBottom + kind.thickness;
    return rider.top > bandBottom + 3 && rider.height < bandTop - 3;
  }
  return rider.height < kind.height - _hitInset;
}

/// 拾取判定：以鹈鹕身体中心为圆心，拾取物半径为宽容范围。
bool pickupReached(
  Pickup pickup,
  RiderMotion rider, {
  double riderX = AppConstants.riderX,
}) {
  final centerHeight = rider.height + rider.bodyHeight / 2;
  final dx = pickup.x - riderX;
  final dy = pickup.y - centerHeight;
  final reach = pickup.kind.radius + AppConstants.pickupForgiveness;
  return dx * dx + dy * dy <= reach * reach;
}
