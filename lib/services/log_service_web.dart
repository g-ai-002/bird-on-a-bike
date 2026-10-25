import 'package:flutter/foundation.dart';

/// 日志服务（Web）：浏览器没有可写目录，日志只保留在内存环形缓冲中。
class LogService {
  static LogService? _instance;
  static final List<String> _earlyBuffer = [];
  final List<String> _buffer = [];
  bool _initialized = false;
  DateTime Function() _now = DateTime.now;

  static const int _maxBufferLines = 2000;
  static const int _maxEarlyLines = 500;

  LogService._();

  static Future<void> init({DateTime Function()? clock}) async {
    _instance ??= LogService._();
    final inst = _instance!;
    if (clock != null) inst._now = clock;
    inst._initialized = true;
    // 补写初始化前的早期日志，并保留在内存缓冲中
    if (_earlyBuffer.isNotEmpty) {
      inst._buffer.addAll(_earlyBuffer);
      _earlyBuffer.clear();
    }
    inst._write('INFO', '==== LogService 已初始化, 日志文件: 内存模式（Web） ====');
  }

  /// 仅用于测试：重置单例与早期缓冲
  static void reset() {
    _instance = null;
    _earlyBuffer.clear();
  }

  /// Web 端没有日志文件，路径固定为空串
  static String get logFilePath => '';

  static void info(String message) => _log('INFO', message);

  static void warning(String message) => _log('WARN', message);

  static void error(String message, [Object? error, StackTrace? stack]) {
    final msg = error != null ? '$message | $error' : message;
    _log('ERROR', msg);
    if (stack != null) {
      _log('ERROR', stack.toString());
    }
  }

  static void _log(String level, String message) {
    final inst = _instance;
    if (inst == null || !inst._initialized) {
      final line = _formatLine(DateTime.now(), level, message);
      _earlyBuffer.add(line);
      if (_earlyBuffer.length > _maxEarlyLines) {
        _earlyBuffer.removeAt(0);
      }
      return;
    }
    inst._write(level, message);
  }

  static String _formatLine(DateTime now, String level, String message) {
    final ts = '${_pad(now.hour)}:${_pad(now.minute)}:${_pad(now.second)}.'
        '${now.millisecond.toString().padLeft(3, '0')}';
    return '[$ts][$level] $message';
  }

  static String _pad(int n) => n.toString().padLeft(2, '0');

  void _write(String level, String message) {
    final line = _formatLine(_now(), level, message);
    _buffer.add(line);
    if (_buffer.length > _maxBufferLines) {
      _buffer.removeAt(0);
    }
    debugPrint(line);
  }

  /// 最近日志（内存缓冲，含尚未初始化时产生的早期日志）
  static List<String> getRecentLogs([int lines = 200]) {
    final inst = _instance;
    final all = <String>[
      ..._earlyBuffer,
      if (inst != null) ...inst._buffer,
    ];
    if (all.length <= lines) {
      return all;
    }
    return all.sublist(all.length - lines);
  }
}
