import 'dart:convert';

import 'package:acgn_index/core/errors/app_exception.dart';
import 'package:acgn_index/domain/entities/danmaku_comment.dart';
import 'package:acgn_index/domain/entities/danmaku_library.dart';
import 'package:acgn_index/domain/repositories/danmaku_library_repository.dart';
import 'package:acgn_index/rule_engine/network/rule_http_client.dart';
import 'package:crypto/crypto.dart';

/// 基于弹弹play 开放弹幕网络（API v2）的弹幕库实现。
///
/// 搜索与弹幕接口都需要 `X-AppId` 鉴权：配置了 AppSecret 时使用签名模式
/// （`base64(sha256(appId + timestamp + path + appSecret))`），
/// 未配置时按匿名请求发送，便于对接无需鉴权的自建代理。
class DandanplayDanmakuRepository implements DanmakuLibraryRepository {
  DandanplayDanmakuRepository({
    required RuleHttpClient httpClient,
    DateTime Function()? clock,
  }) : _http = httpClient,
       _clock = clock ?? DateTime.now;

  final RuleHttpClient _http;
  final DateTime Function() _clock;

  @override
  Future<List<DanmakuLibraryAnime>> searchEpisodes({
    required String keyword,
    required DanmakuLibraryConfig config,
  }) async {
    final trimmed = keyword.trim();
    if (trimmed.isEmpty) {
      return const <DanmakuLibraryAnime>[];
    }
    final payload = await _getJson(
      _endpoint(config, '/api/v2/search/episodes', <String, String>{'anime': trimmed}),
      config,
    );
    final animes = payload['animes'];
    if (animes is! List) {
      return const <DanmakuLibraryAnime>[];
    }
    return animes
        .whereType<Map<String, dynamic>>()
        .map(_parseAnime)
        .whereType<DanmakuLibraryAnime>()
        .toList(growable: false);
  }

  @override
  Future<List<DanmakuComment>> fetchComments({
    required int episodeId,
    required DanmakuLibraryConfig config,
  }) async {
    final payload = await _getJson(
      _endpoint(
        config,
        '/api/v2/comment/$episodeId',
        <String, String>{'withRelated': 'true', 'chConvert': '1'},
      ),
      config,
    );
    final comments = payload['comments'];
    if (comments is! List) {
      return const <DanmakuComment>[];
    }
    return comments
        .whereType<Map<String, dynamic>>()
        .map(_parseComment)
        .whereType<DanmakuComment>()
        .toList(growable: false);
  }

  Uri _endpoint(
    DanmakuLibraryConfig config,
    String path, [
    Map<String, String>? query,
  ]) {
    final base = config.baseUri;
    var prefix = base.path;
    while (prefix.endsWith('/')) {
      prefix = prefix.substring(0, prefix.length - 1);
    }
    return base.replace(path: '$prefix$path', queryParameters: query);
  }

  Future<Map<String, dynamic>> _getJson(Uri uri, DanmakuLibraryConfig config) async {
    final headers = <String, String>{'Accept': 'application/json'};
    if (config.hasCredentials) {
      final timestamp = _clock().toUtc().millisecondsSinceEpoch ~/ 1000;
      headers['X-AppId'] = config.appId.trim();
      headers['X-Timestamp'] = '$timestamp';
      headers['X-Signature'] = dandanplaySignature(
        appId: config.appId.trim(),
        timestamp: timestamp,
        path: uri.path.toLowerCase(),
        appSecret: config.appSecret.trim(),
      );
    }
    final response = await _http.send(RuleHttpRequest(uri: uri, headers: headers));
    if (!response.isSuccess) {
      throw NetworkException('弹幕库请求失败：HTTP ${response.statusCode}');
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(response.body);
    } on FormatException catch (error, stackTrace) {
      throw NetworkException('弹幕库响应不是合法 JSON', cause: error, stackTrace: stackTrace);
    }
    if (decoded is! Map<String, dynamic>) {
      throw const NetworkException('弹幕库响应格式不正确');
    }
    final errorCode = decoded['errorCode'];
    if (errorCode is num && errorCode != 0) {
      throw NetworkException('弹幕库返回错误：${decoded['errorMessage'] ?? errorCode}');
    }
    return decoded;
  }

  DanmakuLibraryAnime? _parseAnime(Map<String, dynamic> json) {
    final animeId = json['animeId'];
    final title = json['animeTitle'];
    if (animeId is! num || title is! String || title.isEmpty) {
      return null;
    }
    final episodes = json['episodes'];
    return DanmakuLibraryAnime(
      animeId: animeId.toInt(),
      title: title,
      typeLabel: json['typeDescription'] is String ? json['typeDescription'] as String : '',
      episodes: episodes is! List
          ? const <DanmakuLibraryEpisode>[]
          : episodes
                .whereType<Map<String, dynamic>>()
                .map(_parseEpisode)
                .whereType<DanmakuLibraryEpisode>()
                .toList(growable: false),
    );
  }

  DanmakuLibraryEpisode? _parseEpisode(Map<String, dynamic> json) {
    final episodeId = json['episodeId'];
    if (episodeId is! num) {
      return null;
    }
    final title = json['episodeTitle'];
    return DanmakuLibraryEpisode(
      episodeId: episodeId.toInt(),
      title: title is String && title.isNotEmpty ? title : '第 ${episodeId.toInt()} 集',
    );
  }

  DanmakuComment? _parseComment(Map<String, dynamic> json) {
    final raw = json['p'];
    final text = json['m'];
    if (raw is! String || text is! String || text.trim().isEmpty) {
      return null;
    }
    final parts = raw.split(',');
    final seconds = double.tryParse(parts.first);
    if (seconds == null) {
      return null;
    }
    final modeValue = parts.length > 1 ? int.tryParse(parts[1]) : null;
    final colorValue = parts.length > 2 ? int.tryParse(parts[2]) : null;
    return DanmakuComment(
      position: Duration(microseconds: (seconds * Duration.microsecondsPerSecond).round()),
      text: text,
      mode: switch (modeValue) {
        4 => DanmakuMode.bottom,
        5 => DanmakuMode.top,
        _ => DanmakuMode.scroll,
      },
      color: 0xFF000000 | ((colorValue ?? 0xFFFFFF) & 0xFFFFFF),
    );
  }
}

/// 弹弹play 签名：`base64(sha256(appId + timestamp + path + appSecret))`。
String dandanplaySignature({
  required String appId,
  required int timestamp,
  required String path,
  required String appSecret,
}) {
  final digest = sha256.convert(utf8.encode('$appId$timestamp$path$appSecret'));
  return base64Encode(digest.bytes);
}
