import 'package:acgn_index/core/errors/app_exception.dart';

/// 把 `jsonDecode` 的返回值安全转换为规则引擎使用的 Map 类型。
Map<String, Object?> asJsonMap(Object? value, {String path = 'value'}) {
  if (value is Map<String, Object?>) {
    return value;
  }
  if (value is Map) {
    return value.map((Object? key, Object? value) => MapEntry(key.toString(), value));
  }
  throw RuleFormatException('$path 必须是 JSON 对象，实际为 ${value.runtimeType}');
}

/// 把任意值转换为 JSON 数组，用于列表型配置。
List<Object?> asJsonList(Object? value, {String path = 'value'}) {
  if (value is List<Object?>) {
    return value;
  }
  throw RuleFormatException('$path 必须是 JSON 数组，实际为 ${value.runtimeType}');
}

/// 规则 JSON 的类型安全读取辅助，避免全代码库散落 `as` 强转。
extension JsonMapReader on Map<String, Object?> {
  String? stringOrNull(String key) => switch (this[key]) {
    final String value => value,
    _ => null,
  };

  int? intOrNull(String key) => switch (this[key]) {
    final int value => value,
    final double value => value.toInt(),
    _ => null,
  };

  bool? boolOrNull(String key) => switch (this[key]) {
    final bool value => value,
    _ => null,
  };

  Map<String, Object?>? mapOrNull(String key) => switch (this[key]) {
    final Map<String, Object?> value => value,
    final Map<Object?, Object?> value => asJsonMap(value),
    _ => null,
  };

  List<Object?>? listOrNull(String key) => switch (this[key]) {
    final List<Object?> value => value,
    _ => null,
  };

  Map<String, String>? stringMapOrNull(String key) {
    final raw = mapOrNull(key);
    if (raw == null) {
      return null;
    }
    final result = <String, String>{};
    for (final entry in raw.entries) {
      final value = entry.value;
      if (value is! String) {
        throw RuleFormatException('$key.${entry.key} 必须是字符串');
      }
      result[entry.key] = value;
    }
    return result;
  }
}
