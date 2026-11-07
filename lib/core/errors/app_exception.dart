/// 应用层异常基类。
///
/// 使用 `sealed` 强制调用方穷举处理，避免把底层异常原样透传给 UI。
sealed class AppException implements Exception {
  const AppException(this.message, {this.cause, this.stackTrace});

  final String message;
  final Object? cause;
  final StackTrace? stackTrace;

  @override
  String toString() => '$runtimeType: $message';
}

/// 规则包结构非法：解析失败、字段缺失或类型不符。
final class RuleFormatException extends AppException {
  const RuleFormatException(super.message, {super.cause, super.stackTrace});
}

/// 网络请求失败（超时、非 2xx、DNS 等）。
final class NetworkException extends AppException {
  const NetworkException(super.message, {super.cause, super.stackTrace});
}

/// 本地存储失败（数据库、文件）。
final class StorageException extends AppException {
  const StorageException(super.message, {super.cause, super.stackTrace});
}

/// 规则声明了当前版本不支持的能力或字段。
final class UnsupportedCapabilityException extends AppException {
  const UnsupportedCapabilityException(super.message, {super.cause, super.stackTrace});
}
