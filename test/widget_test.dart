import 'package:bird_on_a_bike/models/difficulty.dart';
import 'package:bird_on_a_bike/pages/home_page.dart';
import 'package:bird_on_a_bike/providers/game_provider.dart';
import 'package:bird_on_a_bike/providers/settings_provider.dart';
import 'package:bird_on_a_bike/widgets/pelican_badge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'fakes/fake_storage.dart';

Widget buildTestApp(FakeStorageService storage) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => SettingsProvider(storage)),
      ChangeNotifierProvider(
        create: (_) => GameProvider(storage, audioEnabled: false),
      ),
    ],
    child: const MaterialApp(home: HomePage()),
  );
}

void main() {
  testWidgets('主页展示标题、插画与入口', (tester) async {
    final storage = FakeStorageService.create();
    await tester.pumpWidget(buildTestApp(storage));

    expect(find.text('鹈鹕骑单车'), findsWidgets);
    expect(find.text('开始骑行'), findsOneWidget);
    expect(find.text('排行榜'), findsOneWidget);
    expect(find.byType(PelicanBadge), findsOneWidget);
    expect(find.text('最高分'), findsOneWidget);
  });

  testWidgets('Provider 初始状态', (tester) async {
    final storage = FakeStorageService.create();
    await tester.pumpWidget(buildTestApp(storage));

    final game = tester.element(find.byType(HomePage)).read<GameProvider>();
    expect(game.isIdle, isTrue);
    expect(game.state.score, 0);

    final settings =
        tester.element(find.byType(HomePage)).read<SettingsProvider>();
    expect(settings.darkMode, isFalse);
    expect(settings.muted, isFalse);
    expect(settings.difficulty, Difficulty.normal);
  });

  testWidgets('静音与难度设置会持久化', (tester) async {
    final storage = FakeStorageService.create();
    await tester.pumpWidget(buildTestApp(storage));

    final settings =
        tester.element(find.byType(HomePage)).read<SettingsProvider>();
    await settings.setMuted(true);
    await settings.setDifficulty(Difficulty.hard);

    expect(settings.muted, isTrue);
    expect(storage.muted, isTrue);
    expect(settings.difficulty, Difficulty.hard);
    expect(storage.difficulty, Difficulty.hard);
  });

  testWidgets('深色模式切换会持久化并刷新界面', (tester) async {
    final storage = FakeStorageService.create();
    await tester.pumpWidget(buildTestApp(storage));

    final settings =
        tester.element(find.byType(HomePage)).read<SettingsProvider>();
    await settings.toggleDarkMode(true);
    await tester.pump();

    expect(settings.darkMode, isTrue);
    expect(storage.darkMode, isTrue);
  });

  testWidgets('最高分与最远距离来自 GameProvider', (tester) async {
    final storage = FakeStorageService.create();
    await storage.setHighScore(88);
    await storage.setBestDistance(345);
    await tester.pumpWidget(buildTestApp(storage));

    expect(find.text('88'), findsOneWidget);
    expect(find.text('345 m'), findsOneWidget);
  });
}
