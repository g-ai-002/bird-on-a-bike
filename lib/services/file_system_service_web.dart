/// 文件系统服务（Web）：浏览器没有可写的本地目录，所有能力降级为空实现。
class FileSystemService {
  FileSystemService._(this.appDirName);

  static final FileSystemService instance = FileSystemService._('BirdOnABike');

  /// 应用数据目录名（Web 端不使用）
  final String appDirName;

  /// Web 端无法落盘，日志目录路径固定为空串
  Future<String> getLogRootPath() async => '';

  /// Web 端不支持打开系统文件管理器
  Future<bool> openDirectory(String path) async => false;
}
