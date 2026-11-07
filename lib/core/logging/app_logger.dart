import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';

/// 统一日志入口。
///
/// 约定：生产代码禁止 `print`，一律通过 `AppLogger.of('feature')` 记录；
/// 输出 cookie、token 等敏感值前必须调用 [redact]。
abstract final class AppLogger {
  static bool _initialized = false;

  static void init({Level level = Level.INFO}) {
    if (_initialized) {
      return;
    }
    _initialized = true;
    Logger.root.level = level;
    Logger.root.onRecord.listen((record) {
      final buffer = StringBuffer()
        ..write('[${record.level.name}] ')
        ..write(record.loggerName.isEmpty ? 'app' : record.loggerName)
        ..write(': ')
        ..write(record.message);
      if (record.error != null) {
        buffer.write(' | error: ${record.error}');
      }
      debugPrint(buffer.toString());
      if (record.stackTrace != null) {
        debugPrint(record.stackTrace.toString());
      }
    });
  }

  static Logger of(String name) => Logger(name);

  /// 保留少量字符便于比对，同时避免敏感信息落盘。
  static String redact(String? value) {
    if (value == null || value.isEmpty) {
      return '<empty>';
    }
    if (value.length <= 8) {
      return '***';
    }
    return '${value.substring(0, 4)}***';
  }
}
