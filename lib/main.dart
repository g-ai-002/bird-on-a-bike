import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';

import 'pages/home_page.dart';
import 'providers/game_provider.dart';
import 'providers/settings_provider.dart';
import 'services/audio_service.dart';
import 'services/file_system_service.dart';
import 'services/log_service.dart';
import 'services/storage_service.dart';
import 'theme/app_theme.dart';
import 'utils/constants.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (Platform.isWindows) {
    try {
      await windowManager.ensureInitialized();
      const opts = WindowOptions(
        size: Size(960, 660),
        minimumSize: Size(640, 480),
        center: true,
        skipTaskbar: false,
        titleBarStyle: TitleBarStyle.normal,
        title: AppConstants.appName,
      );
      windowManager.waitUntilReadyToShow(opts, () async {
        await windowManager.show();
        await windowManager.focus();
      });
    } catch (e) {
      LogService.warning('窗口管理器初始化失败: $e');
    }
  }

  final storage = await StorageService.instance;
  await LogService.init(logRoot: FileSystemService.instance.getLogRoot);
  LogService.info('应用启动: ${AppConstants.appName} v${AppConstants.version}');

  // 菜单等页面跟随设备方向；进入游玩页后由 GamePage 锁定横屏。
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
    DeviceOrientation.portraitUp,
  ]);

  AudioService().setMuted(storage.muted);
  runApp(BirdOnABikeApp(storage: storage));
  WidgetsBinding.instance.addPostFrameCallback((_) {
    AudioService().prewarm();
    AudioService().startBgm();
  });
}

class BirdOnABikeApp extends StatelessWidget {
  final StorageService storage;
  const BirdOnABikeApp({super.key, required this.storage});

  @override
  Widget build(BuildContext context) {
    final fontFamily = Platform.isWindows ? 'Microsoft YaHei UI' : null;
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SettingsProvider(storage)),
        ChangeNotifierProvider(create: (_) => GameProvider(storage)),
      ],
      child: Consumer<SettingsProvider>(
        builder: (context, settings, _) {
          return MaterialApp(
            title: AppConstants.appName,
            debugShowCheckedModeBanner: false,
            theme: buildLightTheme(fontFamily: fontFamily),
            darkTheme: buildDarkTheme(fontFamily: fontFamily),
            themeMode: settings.darkMode ? ThemeMode.dark : ThemeMode.light,
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [Locale('zh', 'CN')],
            locale: const Locale('zh', 'CN'),
            home: const HomePage(),
          );
        },
      ),
    );
  }
}
