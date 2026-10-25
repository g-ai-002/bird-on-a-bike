import 'file_system_service.dart';
import 'log_service.dart';

/// 初始化日志：IO 平台落盘到用户目录下的 logs/。
Future<void> initLogging() async {
  await LogService.init(logRoot: FileSystemService.instance.getLogRoot);
}
