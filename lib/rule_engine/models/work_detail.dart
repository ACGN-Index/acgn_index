import 'dart:convert';

/// `detail` 能力的求值结果。
///
/// [fields] 保留规则声明的原始求值结果，便于 `toc.fanOutFrom` 与 UI 扩展；
/// 常用字段通过只读访问器暴露。
class WorkDetail {
  const WorkDetail({
    required this.title,
    this.url,
    this.headers = const <String, String>{},
    this.fields = const <String, Object?>{},
  });

  final String title;

  /// 作品详情页绝对地址；规则未声明时为 null。
  final String? url;

  /// 展示封面等远程素材时需要携带的请求头。
  final Map<String, String> headers;

  final Map<String, Object?> fields;

  String? get cover => string('cover');
  String? get intro => string('intro');
  String? get author => string('author');
  String? get status => string('status');
  String? get rating => string('rating');
  String? get year => string('year');
  int? get episodeCount => integer('episodeCount');
  List<String> get tags => strings('tags');
  List<String> get aliases => strings('aliases');
  List<Map<String, String>> get volumes => objectList('volumes');

  String? string(String key) {
    final value = fields[key];
    if (value is List<Object?>) {
      for (final item in value) {
        final text = _scalar(item);
        if (text != null) {
          return text;
        }
      }
      return null;
    }
    return _scalar(value);
  }

  int? integer(String key) => _asInt(fields[key]);

  List<String> strings(String key) {
    final value = fields[key];
    if (value is List<Object?>) {
      return value.map(_scalar).whereType<String>().toList(growable: false);
    }
    final text = _scalar(value);
    return text == null ? const <String>[] : <String>[text];
  }

  List<Map<String, String>> objectList(String key) {
    final value = fields[key];
    if (value is! List<Object?>) {
      return const <Map<String, String>>[];
    }
    final result = <Map<String, String>>[];
    for (final item in value) {
      if (item is Map<Object?, Object?>) {
        result.add(
          <String, String>{
            for (final entry in item.entries) entry.key.toString(): entry.value?.toString() ?? '',
          },
        );
      }
    }
    return result;
  }
}

String? _scalar(Object? value) {
  if (value == null) {
    return null;
  }
  if (value is String) {
    final text = value.trim();
    return text.isEmpty ? null : text;
  }
  if (value is Map<Object?, Object?> || value is List<Object?>) {
    return jsonEncode(value);
  }
  final text = value.toString().trim();
  return text.isEmpty ? null : text;
}

int? _asInt(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  if (value is String) {
    return int.tryParse(value.trim());
  }
  if (value is List<Object?> && value.isNotEmpty) {
    return _asInt(value.first);
  }
  return null;
}
