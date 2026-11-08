import 'dart:convert';

import 'package:acgn_index/core/constants/app_constants.dart';
import 'package:acgn_index/rule_engine/models/capability_rule.dart';
import 'package:acgn_index/rule_engine/models/rule_pack.dart';

/// 取单个标量：数组取第一个非空值，Map/List 转 JSON 文本。
String? scalarValue(Object? value) {
  if (value == null) {
    return null;
  }
  if (value is List<Object?>) {
    for (final item in value) {
      final text = scalarValue(item);
      if (text != null) {
        return text;
      }
    }
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

int? intValue(Object? value) {
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
    return intValue(value.first);
  }
  return null;
}

List<String> stringValues(Object? value) {
  if (value == null) {
    return const <String>[];
  }
  if (value is List<Object?>) {
    return value.map(scalarValue).whereType<String>().toList(growable: false);
  }
  final text = scalarValue(value);
  return text == null ? const <String>[] : <String>[text];
}

/// 把相对地址解析为绝对地址；已带 scheme 时原样返回。
String? absoluteUrl(Uri pageUri, String? value) {
  final text = value?.trim();
  if (text == null || text.isEmpty) {
    return null;
  }
  final parsed = Uri.tryParse(text);
  if (parsed != null && parsed.hasScheme) {
    return text;
  }
  return pageUri.resolve(text).toString();
}

Uri? absoluteUri(Uri pageUri, String? value) {
  final text = absoluteUrl(pageUri, value);
  return text == null ? null : Uri.tryParse(text);
}

bool isTruthyValue(Object? value) {
  if (value == null) {
    return false;
  }
  if (value is bool) {
    return value;
  }
  if (value is num) {
    return value != 0;
  }
  if (value is String) {
    final normalized = value.trim().toLowerCase();
    return normalized.isNotEmpty && normalized != 'false' && normalized != '0';
  }
  if (value is List<Object?>) {
    return value.isNotEmpty;
  }
  return true;
}

/// 构造图片 / 视频 / 文件请求头：默认 UA + 规则包 headers + 能力 headers + Referer。
Map<String, String> mediaHeaders(
  RulePack pack,
  CapabilityRule capability, {
  Uri? pageUri,
  String? referer,
}) {
  final headers = <String, String>{'User-Agent': AppConstants.defaultUserAgent};

  void merge(Map<String, String> source) {
    for (final entry in source.entries) {
      final normalized = entry.key.toLowerCase();
      if (normalized == 'accept' || normalized == 'content-type') {
        continue;
      }
      final existing = headers.keys.where((key) => key.toLowerCase() == normalized).firstOrNull;
      headers[existing ?? entry.key] = entry.value;
    }
  }

  merge(pack.request.headers);
  merge(capability.headers);
  final refererText = referer?.trim();
  if (refererText != null && refererText.isNotEmpty) {
    final parsed = Uri.tryParse(refererText);
    headers['Referer'] = parsed != null && parsed.hasScheme
        ? refererText
        : pageUri?.resolve(refererText).toString() ?? refererText;
  }
  return headers;
}
