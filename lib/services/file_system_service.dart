/// 文件系统服务：按平台选择实现——IO 平台使用 path_provider，Web 平台降级为空实现。
library;

export 'file_system_service_io.dart'
    if (dart.library.js_interop) 'file_system_service_web.dart';
