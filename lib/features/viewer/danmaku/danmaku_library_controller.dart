import 'package:acgn_index/core/errors/app_exception.dart';
import 'package:acgn_index/core/logging/app_logger.dart';
import 'package:acgn_index/data/providers.dart';
import 'package:acgn_index/domain/entities/danmaku_comment.dart';
import 'package:acgn_index/domain/entities/danmaku_library.dart';
import 'package:acgn_index/features/viewer/danmaku/danmaku_library_config.dart';
import 'package:acgn_index/features/viewer/danmaku/danmaku_library_matcher.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

enum DanmakuLibraryStatus { idle, searching, ready, loading, failed }

/// 弹幕库面板与自动匹配共用的状态。
@immutable
class DanmakuLibraryState {
  const DanmakuLibraryState({
    this.status = DanmakuLibraryStatus.idle,
    this.configured = false,
    this.query = '',
    this.animes = const <DanmakuLibraryAnime>[],
    this.anime,
    this.episode,
    this.commentCount = 0,
    this.errorMessage,
  });

  final DanmakuLibraryStatus status;

  /// 是否已配置到可以请求弹幕库（凭证或自建地址）。
  final bool configured;

  final String query;
  final List<DanmakuLibraryAnime> animes;

  /// 自动匹配或手动选中的作品 / 剧集。
  final DanmakuLibraryAnime? anime;
  final DanmakuLibraryEpisode? episode;

  final int commentCount;
  final String? errorMessage;

  bool get isLoading =>
      status == DanmakuLibraryStatus.searching || status == DanmakuLibraryStatus.loading;

  DanmakuLibraryState copyWith({
    DanmakuLibraryStatus? status,
    bool? configured,
    String? query,
    List<DanmakuLibraryAnime>? animes,
    DanmakuLibraryAnime? anime,
    DanmakuLibraryEpisode? episode,
    int? commentCount,
    String? errorMessage,
  }) => DanmakuLibraryState(
    status: status ?? this.status,
    configured: configured ?? this.configured,
    query: query ?? this.query,
    animes: animes ?? this.animes,
    anime: anime ?? this.anime,
    episode: episode ?? this.episode,
    commentCount: commentCount ?? this.commentCount,
    errorMessage: errorMessage,
  );
}

final NotifierProvider<DanmakuLibraryController, DanmakuLibraryState> danmakuLibraryProvider =
    NotifierProvider<DanmakuLibraryController, DanmakuLibraryState>(
      DanmakuLibraryController.new,
      isAutoDispose: true,
    );

/// 弹幕库索引：自动匹配、手动搜索与按集拉取，结果在会话内按 episodeId 缓存。
class DanmakuLibraryController extends Notifier<DanmakuLibraryState> {
  static final Logger _logger = AppLogger.of('viewer.danmaku.library');

  final Map<int, List<DanmakuComment>> _cache = <int, List<DanmakuComment>>{};

  @override
  DanmakuLibraryState build() => const DanmakuLibraryState();

  /// 进入播放器时按「作品 + 章节」自动匹配；失败只记日志。
  Future<List<DanmakuComment>> autoMatch({
    required String workTitle,
    required String episodeTitle,
  }) async {
    final config = await _readConfig();
    state = state.copyWith(configured: config.canQuery);
    if (!config.canQuery) {
      return const <DanmakuComment>[];
    }
    state = state.copyWith(
      status: DanmakuLibraryStatus.searching,
      query: workTitle,
    );
    try {
      final animes = await ref
          .read(danmakuLibraryRepositoryProvider)
          .searchEpisodes(keyword: workTitle, config: config);
      final anime = pickAnime(animes, workTitle);
      if (anime == null) {
        state = state.copyWith(status: DanmakuLibraryStatus.ready, animes: animes);
        return const <DanmakuComment>[];
      }
      final episode = pickEpisode(anime.episodes, number: parseEpisodeNumber(episodeTitle));
      if (episode == null) {
        state = state.copyWith(status: DanmakuLibraryStatus.ready, animes: animes);
        return const <DanmakuComment>[];
      }
      return await _loadComments(config, animes, anime, episode);
    } on AppException catch (error, stackTrace) {
      _logger.warning('弹幕库自动匹配失败', error, stackTrace);
      state = state.copyWith(
        status: DanmakuLibraryStatus.failed,
        errorMessage: error.message,
      );
      return const <DanmakuComment>[];
    } on Object catch (error, stackTrace) {
      _logger.severe('弹幕库自动匹配异常', error, stackTrace);
      state = state.copyWith(status: DanmakuLibraryStatus.failed);
      return const <DanmakuComment>[];
    }
  }

  /// 面板里按关键词重新搜索。
  Future<void> search(String keyword) async {
    final trimmed = keyword.trim();
    final config = await _readConfig();
    state = state.copyWith(configured: config.canQuery, query: trimmed);
    if (trimmed.isEmpty || !config.canQuery) {
      return;
    }
    state = state.copyWith(status: DanmakuLibraryStatus.searching);
    try {
      final animes = await ref
          .read(danmakuLibraryRepositoryProvider)
          .searchEpisodes(keyword: trimmed, config: config);
      state = state.copyWith(status: DanmakuLibraryStatus.ready, animes: animes);
    } on AppException catch (error, stackTrace) {
      _logger.warning('弹幕库搜索失败', error, stackTrace);
      state = state.copyWith(
        status: DanmakuLibraryStatus.failed,
        errorMessage: error.message,
      );
    } on Object catch (error, stackTrace) {
      _logger.severe('弹幕库搜索异常', error, stackTrace);
      state = state.copyWith(status: DanmakuLibraryStatus.failed);
    }
  }

  /// 手动选定剧集并拉取弹幕。
  Future<List<DanmakuComment>> useEpisode(
    DanmakuLibraryAnime anime,
    DanmakuLibraryEpisode episode,
  ) async {
    final config = await _readConfig();
    if (!config.canQuery) {
      return const <DanmakuComment>[];
    }
    state = state.copyWith(status: DanmakuLibraryStatus.loading);
    try {
      return await _loadComments(config, state.animes, anime, episode);
    } on AppException catch (error, stackTrace) {
      _logger.warning('拉取弹幕失败', error, stackTrace);
      state = state.copyWith(
        status: DanmakuLibraryStatus.failed,
        errorMessage: error.message,
      );
      return const <DanmakuComment>[];
    } on Object catch (error, stackTrace) {
      _logger.severe('拉取弹幕异常', error, stackTrace);
      state = state.copyWith(status: DanmakuLibraryStatus.failed);
      return const <DanmakuComment>[];
    }
  }

  Future<List<DanmakuComment>> _loadComments(
    DanmakuLibraryConfig config,
    List<DanmakuLibraryAnime> animes,
    DanmakuLibraryAnime anime,
    DanmakuLibraryEpisode episode,
  ) async {
    final cached = _cache[episode.episodeId];
    final comments =
        cached ??
        await ref
            .read(danmakuLibraryRepositoryProvider)
            .fetchComments(episodeId: episode.episodeId, config: config);
    _cache[episode.episodeId] = comments;
    state = state.copyWith(
      status: DanmakuLibraryStatus.ready,
      animes: animes,
      anime: anime,
      episode: episode,
      commentCount: comments.length,
    );
    return comments;
  }

  Future<DanmakuLibraryConfig> _readConfig() => ref.read(danmakuLibraryConfigProvider.future);
}
