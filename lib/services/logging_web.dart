import 'log_service.dart';

/// 初始化日志：Web 平台无法写文件，只保留内存日志。
Future<void> initLogging() async {
  await LogService.init();
}
