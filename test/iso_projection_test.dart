import 'package:bird_on_a_bike/game/iso_projection.dart';
import 'package:bird_on_a_bike/game/world_layout.dart';
import 'package:bird_on_a_bike/models/obstacle.dart';
import 'package:bird_on_a_bike/utils/constants.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('固定机位 2.5D 投影', () {
    test('基准点与地面重合', () {
      expect(IsoProjection.project(0, 0, 0), const Offset(400, 380));
      expect(IsoProjection.project(0, 0, 0).dy, AppConstants.groundY);
      expect(
        IsoProjection.project(0, 0, 0).dx,
        AppConstants.worldWidth / 2,
      );
    });

    test('高度只影响纵向，1 米等于 100 像素', () {
      final ground = IsoProjection.project(0, 0, 0);
      final high = IsoProjection.project(0, 9.6, 0);
      expect(high.dx, ground.dx);
      expect(high.dy, ground.dy - 96);
      expect(IsoProjection.travelPixels(1), 100);
    });

    test('深度越远越靠右上，绘制顺序越靠前', () {
      final near = IsoProjection.project(0, 0, -1);
      final far = IsoProjection.project(0, 0, 1);
      expect(far.dx, greaterThan(near.dx));
      expect(far.dy, lessThan(near.dy));
      expect(
        far.dx - near.dx,
        IsoProjection.depthSlantX * 2,
      );
      expect(
        near.dy - far.dy,
        IsoProjection.depthSlantY * 2,
      );
      expect(
        IsoProjection.depthOrder(-1),
        greaterThan(IsoProjection.depthOrder(1)),
      );
    });

    test('路面与海岸的屏幕边界', () {
      expect(
        IsoProjection.roadFarY,
        AppConstants.groundY - IsoProjection.roadFarZ * IsoProjection.depthSlantY,
      );
      expect(IsoProjection.roadFarY, greaterThan(IsoProjection.horizonY));
      expect(IsoProjection.seaEdgeY, greaterThan(IsoProjection.horizonY));
      expect(IsoProjection.seaEdgeY, lessThan(IsoProjection.roadFarY));
      expect(IsoProjection.roadNearY, greaterThan(AppConstants.groundY));
    });

    test('单向单车道窄于路面，仍能容纳障碍的深度摆位', () {
      final maxHalfDepth = ObstacleKind.values
              .map((kind) => kind.depth)
              .reduce((a, b) => a > b ? a : b) /
          2;
      expect(IsoProjection.laneHalfZ, lessThan(IsoProjection.roadFarZ));
      expect(IsoProjection.laneEdgeZ, lessThan(IsoProjection.laneHalfZ));
      expect(
        AppConstants.depthSpread + maxHalfDepth,
        lessThan(IsoProjection.laneEdgeZ),
      );
    });

    test('沿路精灵只有整块移出画布才不可见', () {
      // 半个草丛还压在左边框上，仍需绘制到完全离开为止。
      final leftEdge = IsoProjection.project(-57, 0, 8.6);
      expect(IsoProjection.isGroundSpriteVisible(leftEdge, 10), isTrue);

      final offLeft = IsoProjection.project(-63, 0, 8.6);
      expect(offLeft.dx + 10, lessThan(0));
      expect(IsoProjection.isGroundSpriteVisible(offLeft, 10), isFalse);

      final offRight = IsoProjection.project(31, 0, 8.6);
      expect(
        offRight.dx - 10,
        greaterThan(AppConstants.worldWidth),
      );
      expect(IsoProjection.isGroundSpriteVisible(offRight, 10), isFalse);
    });
  });

  group('WorldLayout 兼容旧屏幕特效', () {
    test('深度参数可省略，等价于骑行线', () {
      expect(
        WorldLayout.screenPoint(WorldLayout.riderX, 0),
        IsoProjection.project(WorldLayout.riderX, 0, WorldLayout.riderZ),
      );
      expect(
        WorldLayout.screenX(WorldLayout.riderX, 1),
        IsoProjection.project(WorldLayout.riderX, 0, 1).dx,
      );
      expect(
        WorldLayout.screenY(5, -1),
        IsoProjection.project(0, 5, -1).dy,
      );
    });
  });
}
