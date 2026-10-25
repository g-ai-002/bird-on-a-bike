import 'package:bird_on_a_bike/game/world_layout.dart';
import 'package:bird_on_a_bike/utils/constants.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('世界坐标约定', () {
    test('1 米等于 10 个世界单位', () {
      expect(WorldLayout.unitsPerMeter, 10);
    });

    test('屏幕投影与 2D 设计位置一致', () {
      expect(WorldLayout.screenX(0), AppConstants.worldWidth / 2);
      expect(WorldLayout.screenX(WorldLayout.riderX), 190);
      expect(WorldLayout.screenY(0), AppConstants.groundY);
      expect(WorldLayout.screenY(9.6), AppConstants.groundY - 96);
    });

    test('生成位置在骑行者前方', () {
      expect(WorldLayout.obstacleSpawnX, greaterThan(WorldLayout.riderX + 40));
      expect(WorldLayout.fishSpawnX, greaterThan(WorldLayout.obstacleSpawnX));
      expect(WorldLayout.powerUpSpawnX, greaterThan(WorldLayout.fishSpawnX));
      expect(WorldLayout.riderX, greaterThan(AppConstants.cullX));
    });

    test('深度摆位幅度小于骑行线的判定半径', () {
      expect(
        AppConstants.depthSpread,
        lessThan(AppConstants.riderHalfDepth * 2),
      );
      expect(WorldLayout.riderZ, 0);
    });
  });
}
