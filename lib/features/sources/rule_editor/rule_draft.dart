import 'dart:convert';

import 'package:flutter/foundation.dart';

/// 可视化编辑器直接操作的 JSON 文档。
///
/// 不使用 `RulePack` 作为编辑载体：这样未识别的字段、键顺序都能原样保留，
/// 在可视化与 JSON 模式之间来回切换时不会丢信息。
class RuleDraft extends ChangeNotifier {
  RuleDraft(this._json);

  /// 解析规则文本。顶层不是 JSON 对象时抛出 [FormatException]。
  factory RuleDraft.parse(String text) {
    final decoded = jsonDecode(text);
    if (decoded is! Map) {
      throw const FormatException('顶层必须是 JSON 对象');
    }
    return RuleDraft(<String, Object?>{
      for (final entry in decoded.entries) entry.key.toString(): entry.value,
    });
  }

  final Map<String, Object?> _json;

  Map<String, Object?> get json => _json;

  String toJsonText() => '${const JsonEncoder.withIndent('  ').convert(_json)}\n';

  /// 修改文档并通知界面刷新。
  void mutate(void Function(Map<String, Object?> json) action) {
    action(_json);
    notifyListeners();
  }
}

/// 读取任意 JSON 值并复制成 `Map<String, Object?>`；不是对象时返回 null。
Map<String, Object?>? asJsonMapOrNull(Object? value) {
  if (value is! Map) {
    return null;
  }
  return <String, Object?>{
    for (final entry in value.entries) entry.key.toString(): entry.value,
  };
}

/// 确保 [parent] 下 [key] 是对象并返回它，缺失时写入一个空对象。
Map<String, Object?> ensureJsonMap(Map<String, Object?> parent, String key) {
  final existing = asJsonMapOrNull(parent[key]);
  if (existing != null) {
    parent[key] = existing;
    return existing;
  }
  final created = <String, Object?>{};
  parent[key] = created;
  return created;
}

Map<String, Object?> deepCopyJsonMap(Map<String, Object?> json) =>
    asJsonMapOrNull(jsonDecode(jsonEncode(json))) ?? <String, Object?>{};

String readString(Map<String, Object?> json, String key) {
  final value = json[key];
  return value is String ? value : '';
}

int readInt(Map<String, Object?> json, String key, int fallback) {
  final value = json[key];
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  if (value is String) {
    return int.tryParse(value) ?? fallback;
  }
  return fallback;
}

bool readBool(Map<String, Object?> json, String key) => json[key] == true;

List<String> readStringList(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! List) {
    return const <String>[];
  }
  return value.whereType<String>().toList(growable: false);
}

Map<String, String> readStringMap(Map<String, Object?> json, String key) {
  final value = asJsonMapOrNull(json[key]);
  if (value == null) {
    return const <String, String>{};
  }
  final result = <String, String>{};
  for (final entry in value.entries) {
    final item = entry.value;
    if (item is String) {
      result[entry.key] = item;
    }
  }
  return result;
}

void writeString(
  Map<String, Object?> json,
  String key,
  String value, {
  bool keepEmpty = false,
}) {
  if (value.isEmpty && !keepEmpty) {
    json.remove(key);
  } else {
    json[key] = value;
  }
}

void writeBool(Map<String, Object?> json, String key, bool value) {
  if (value) {
    json[key] = true;
  } else {
    json.remove(key);
  }
}

/// 写入整数；等于 [defaultValue] 时移除，保持 JSON 精简。
void writeInt(
  Map<String, Object?> json,
  String key,
  int value, {
  int? defaultValue,
}) {
  if (defaultValue != null && value == defaultValue) {
    json.remove(key);
  } else {
    json[key] = value;
  }
}

void writeStringMap(
  Map<String, Object?> json,
  String key,
  Map<String, String> values,
) {
  if (values.isEmpty) {
    json.remove(key);
  } else {
    json[key] = values;
  }
}

void writeStringList(
  Map<String, Object?> json,
  String key,
  List<String> values,
) {
  if (values.isEmpty) {
    json.remove(key);
  } else {
    json[key] = values;
  }
}

/// 去掉字段规则里"未设置"的键，保留取值来源（即使是空字符串，校验器会提示）。
Map<String, Object?> pruneFieldRule(Map<String, Object?> source) {
  final result = <String, Object?>{...source};
  for (final key in const <String>['attr', 'regex', 'template', 'prefix', 'suffix']) {
    if (readString(result, key).isEmpty) {
      result.remove(key);
    }
  }
  for (final key in const <String>['html', 'multiple', 'absolute', 'htmlToText']) {
    if (!readBool(result, key)) {
      result.remove(key);
    }
  }
  if (readInt(result, 'group', 1) == 1) {
    result.remove('group');
  }
  final fallback = asJsonMapOrNull(result['fallback']);
  if (fallback == null) {
    result.remove('fallback');
  } else {
    final pruned = pruneFieldRule(fallback);
    if (pruned.isEmpty) {
      result.remove('fallback');
    } else {
      result['fallback'] = pruned;
    }
  }
  final items = asJsonMapOrNull(result['items']);
  if (items == null) {
    result.remove('items');
  } else {
    result['items'] = pruneFieldRule(items);
  }
  final fields = asJsonMapOrNull(result['fields']);
  if (fields == null || fields.isEmpty) {
    result.remove('fields');
  } else {
    result['fields'] = <String, Object?>{
      for (final entry in fields.entries)
        entry.key: pruneFieldRule(asJsonMapOrNull(entry.value) ?? <String, Object?>{}),
    };
  }
  return result;
}

/// 启用一个能力时写入的初始结构，尽量贴近该内容类型的常见用法。
Map<String, Object?> defaultCapabilityJson(String capability, {String? contentMode}) {
  return switch (capability) {
    'search' => <String, Object?>{
      'url': '',
      'fields': <String, Object?>{
        'id': <String, Object?>{'selector': ''},
        'title': <String, Object?>{'selector': ''},
      },
    },
    'detail' => <String, Object?>{
      'url': '',
      'fields': <String, Object?>{
        'title': <String, Object?>{'selector': ''},
      },
    },
    'toc' => <String, Object?>{
      'url': '',
      'list': <String, Object?>{'selector': ''},
      'fields': <String, Object?>{
        'id': <String, Object?>{'selector': ''},
        'title': <String, Object?>{'selector': ''},
      },
    },
    'content' => <String, Object?>{'url': '', 'mode': ?contentMode},
    _ => <String, Object?>{'url': ''},
  };
}

/// 各能力推荐的字段名，仅用于"添加字段"时的候选。
const Map<String, List<String>> kCapabilityFieldSuggestions = <String, List<String>>{
  'search': <String>[
    'id',
    'title',
    'cover',
    'author',
    'subtitle',
    'url',
    'status',
    'tags',
    'volumes',
  ],
  'detail': <String>[
    'title',
    'cover',
    'intro',
    'author',
    'status',
    'tags',
    'rating',
    'year',
    'episodeCount',
    'volumes',
    'aliases',
  ],
  'toc': <String>[
    'id',
    'title',
    'url',
    'order',
    'group',
    'duration',
    'airdate',
    'extra',
  ],
  'content': <String>[
    'mode',
    'url',
    'urls',
    'images',
    'body',
    'paragraphs',
    'title',
    'format',
    'size',
    'checksum',
    'type',
    'quality',
    'referer',
    'danmakuUrl',
  ],
};

/// 按内容类型给出 `content.mode` 的默认值。
String? defaultContentMode(String mediaType) => switch (mediaType) {
  'anime' => 'video',
  'comic' => 'images',
  'novel' => 'text',
  _ => null,
};
