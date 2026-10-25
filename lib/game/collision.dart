import '../models/obstacle.dart';
import '../models/pickup.dart';
import '../models/rider_motion.dart';
import '../utils/constants.dart';
import 'world_layout.dart';

/// 碰撞盒内缩量，判定比美术略宽容。
const double _hitInset = 0.4;

/// 鹈鹕是否撞上某个障碍。
///
/// 三个轴都参与判定：先看沿骑行方向与深度的包围盒是否重叠，
/// 地面障碍再看车轮离地高度；悬空横幅则看身体上沿与横幅下沿的关系，
/// 因此站立必撞、俯身可通过、跳得足够高也能从上方越过。
bool riderHitsObstacle(
  Obstacle obstacle,
  RiderMotion rider, {
  double riderX = WorldLayout.riderX,
  double riderZ = WorldLayout.riderZ,
}) {
  final left = riderX - AppConstants.riderHalfWidth;
  final right = riderX + AppConstants.riderHalfWidth;
  if (obstacle.right < left + _hitInset || obstacle.x > right - _hitInset) {
    return false;
  }

  final depthGap = (obstacle.z - riderZ).abs();
  final depthReach =
      AppConstants.riderHalfDepth + obstacle.kind.depth / 2 - _hitInset;
  if (depthGap > depthReach) return false;

  final kind = obstacle.kind;
  if (kind.overhead) {
    final bandBottom = kind.clearance;
    final bandTop = bandBottom + kind.thickness;
    return rider.top > bandBottom + _hitInset &&
        rider.height < bandTop - _hitInset;
  }
  return rider.height < kind.height - _hitInset;
}

/// 拾取判定：以鹈鹕身体中心为球心，拾取物半径为宽容范围。
bool pickupReached(
  Pickup pickup,
  RiderMotion rider, {
  double riderX = WorldLayout.riderX,
  double riderZ = WorldLayout.riderZ,
}) {
  final centerHeight = rider.height + rider.bodyHeight / 2;
  final dx = pickup.x - riderX;
  final dy = pickup.y - centerHeight;
  final dz = pickup.z - riderZ;
  final reach = pickup.kind.radius + AppConstants.pickupForgiveness;
  return dx * dx + dy * dy + dz * dz <= reach * reach;
}
