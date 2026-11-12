/// 弹幕库（弹弹play 兼容 API）的访问配置。
///
/// 凭证只保存在本机，不写入规则包，也不随规则导出。
class DanmakuLibraryConfig {
  const DanmakuLibraryConfig({
    this.baseUrl = defaultBaseUrl,
    this.appId = '',
    this.appSecret = '',
  });

  static const String defaultBaseUrl = 'https://api.dandanplay.net';

  /// 弹幕库服务地址；自建代理可填写自己的地址。
  final String baseUrl;

  final String appId;
  final String appSecret;

  bool get hasCredentials => appId.trim().isNotEmpty && appSecret.trim().isNotEmpty;

  /// 只有配置了凭证或换用自建地址时才值得发起请求；
  /// 否则直连弹弹play 会因为没有 AppId 被拒绝。
  bool get canQuery {
    final trimmed = baseUrl.trim();
    if (trimmed.isEmpty) {
      return false;
    }
    return hasCredentials || trimmed != defaultBaseUrl;
  }

  /// 落库时用的稳定标识，避免每次请求前重复解析。
  Uri get baseUri => Uri.parse(baseUrl.trim());

  DanmakuLibraryConfig copyWith({String? baseUrl, String? appId, String? appSecret}) =>
      DanmakuLibraryConfig(
        baseUrl: baseUrl ?? this.baseUrl,
        appId: appId ?? this.appId,
        appSecret: appSecret ?? this.appSecret,
      );

  @override
  bool operator ==(Object other) =>
      other is DanmakuLibraryConfig &&
      other.baseUrl == baseUrl &&
      other.appId == appId &&
      other.appSecret == appSecret;

  @override
  int get hashCode => Object.hash(baseUrl, appId, appSecret);
}

/// 弹幕库中的一部作品。
class DanmakuLibraryAnime {
  const DanmakuLibraryAnime({
    required this.animeId,
    required this.title,
    this.typeLabel = '',
    this.episodes = const <DanmakuLibraryEpisode>[],
  });

  final int animeId;
  final String title;

  /// 例如「TV动画」，仅用于展示。
  final String typeLabel;

  final List<DanmakuLibraryEpisode> episodes;
}

/// 弹幕库中的一集；[episodeId] 是拉取弹幕的编号。
class DanmakuLibraryEpisode {
  const DanmakuLibraryEpisode({required this.episodeId, required this.title});

  final int episodeId;
  final String title;
}
