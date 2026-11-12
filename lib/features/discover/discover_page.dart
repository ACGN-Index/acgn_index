import 'dart:async';

import 'package:acgn_index/app/router/app_destinations.dart';
import 'package:acgn_index/core/logging/app_logger.dart';
import 'package:acgn_index/core/widgets/empty_state_view.dart';
import 'package:acgn_index/data/providers.dart';
import 'package:acgn_index/domain/entities/discover_feed.dart';
import 'package:acgn_index/domain/entities/rule_page_cursor.dart';
import 'package:acgn_index/domain/entities/rule_source.dart';
import 'package:acgn_index/domain/repositories/discover_feed_repository.dart';
import 'package:acgn_index/features/discover/discover_filter.dart';
import 'package:acgn_index/features/discover/discover_grid.dart';
import 'package:acgn_index/features/discover/discover_work_card.dart';
import 'package:acgn_index/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// 发现：聚合所有启用规则的搜索结果为作品网格。
class DiscoverPage extends ConsumerStatefulWidget {
  const DiscoverPage({super.key});

  @override
  ConsumerState<DiscoverPage> createState() => _DiscoverPageState();
}

class _DiscoverPageState extends ConsumerState<DiscoverPage> {
  late final DiscoverFeedRepository _repository;
  final ScrollController _scrollController = ScrollController();

  final Set<String> _keys = <String>{};
  List<DiscoverItem>? _items;
  List<DiscoverFailure> _failures = const <DiscoverFailure>[];
  List<RulePageCursor> _cursors = const <RulePageCursor>[];
  int _sourceCount = 0;
  int _searchableSourceCount = 0;
  Object? _error;
  bool _loadingMore = false;
  bool _loadMoreFailed = false;
  DiscoverFilter _filter = const DiscoverFilter();

  /// 代际号：刷新会自增，用来丢弃刷新之前发出的分页响应。
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _repository = ref.read(discoverFeedRepositoryProvider);
    _scrollController.addListener(_onScroll);
    unawaited(_reload());
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  /// 重新加载第一页；已有内容时保留旧内容，避免刷新失败把整页清空。
  Future<void> _reload() async {
    final generation = ++_generation;
    try {
      final feed = await _repository.load();
      if (!mounted || generation != _generation) {
        return;
      }
      setState(() {
        _items = feed.items;
        _keys
          ..clear()
          ..addAll(feed.items.map((item) => item.key));
        _failures = feed.failures;
        _cursors = feed.cursors;
        _sourceCount = feed.sourceCount;
        _searchableSourceCount = feed.searchableSourceCount;
        _error = null;
        _loadingMore = false;
        _loadMoreFailed = false;
      });
      _scheduleFillCheck();
    } on Object catch (error, stackTrace) {
      AppLogger.of('discover').warning('发现页加载失败', error, stackTrace);
      if (!mounted || generation != _generation) {
        return;
      }
      if (_items == null) {
        setState(() => _error = error);
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).discoverLoadFailed)),
      );
    }
  }

  void _onScroll() {
    if (_scrollController.position.extentAfter > _loadMoreThreshold) {
      return;
    }
    unawaited(_loadMore());
  }

  /// 内容不足一屏时滚动事件不会触发，这里在布局结束后主动补一页。
  void _scheduleFillCheck() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) {
        return;
      }
      if (_scrollController.position.extentAfter <= _loadMoreThreshold) {
        unawaited(_loadMore());
      }
    });
  }

  Future<void> _loadMore({bool force = false}) async {
    if (_loadingMore || _cursors.isEmpty) {
      return;
    }
    // 失败后不自动重试同一游标，避免坏规则在触底时反复请求。
    if (_loadMoreFailed && !force) {
      return;
    }
    setState(() {
      _loadingMore = true;
      _loadMoreFailed = false;
    });
    final generation = _generation;
    try {
      final chunk = await _repository.loadMore(_cursors);
      if (!mounted || generation != _generation) {
        return;
      }
      var added = 0;
      final items = List<DiscoverItem>.of(_items ?? const <DiscoverItem>[]);
      for (final item in chunk.items) {
        if (_keys.add(item.key)) {
          items.add(item);
          added++;
        }
      }
      setState(() {
        _loadingMore = false;
        _items = items;
        _failures = _mergeFailures(_failures, chunk.failures);
        // 全是重复条目说明该规则的分页已失去意义，直接停止翻页。
        _cursors = added == 0 && chunk.items.isNotEmpty ? const <RulePageCursor>[] : chunk.cursors;
      });
      if (added > 0) {
        _scheduleFillCheck();
      }
    } on Object catch (error, stackTrace) {
      AppLogger.of('discover').warning('发现页加载更多失败', error, stackTrace);
      if (!mounted || generation != _generation) {
        return;
      }
      setState(() {
        _loadingMore = false;
        _loadMoreFailed = true;
      });
    }
  }

  List<DiscoverFailure> _mergeFailures(
    List<DiscoverFailure> current,
    List<DiscoverFailure> next,
  ) {
    if (next.isEmpty) {
      return current;
    }
    final byRule = <String, DiscoverFailure>{
      for (final failure in current) failure.ruleId: failure,
      for (final failure in next) failure.ruleId: failure,
    };
    return List<DiscoverFailure>.unmodifiable(byRule.values);
  }

  Future<void> _openFilter() async {
    final result = await showDiscoverFilterSheet(context, _filter);
    if (result != null && mounted) {
      setState(() => _filter = result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    ref.listen<AsyncValue<List<RuleSource>>>(ruleSourcesProvider, (previous, next) {
      final previousIds = _enabledIds(previous?.value);
      final nextIds = _enabledIds(next.value);
      if (previousIds != null && nextIds != null && !_sameIds(previousIds, nextIds)) {
        _reload();
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: Tooltip(
          message: l10n.discoverFilterTitle,
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: _openFilter,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(l10n.navDiscover),
                  const SizedBox(width: 2),
                  const Icon(Icons.arrow_drop_down, size: 22),
                ],
              ),
            ),
          ),
        ),
        actions: <Widget>[
          IconButton(
            onPressed: () => context.push(AppRoutes.search),
            tooltip: l10n.discoverSearchHint,
            icon: const Icon(Icons.search),
          ),
        ],
      ),
      body: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final items = _items;
    if (items == null) {
      if (_error != null) {
        return EmptyStateView(
          icon: Icons.cloud_off_outlined,
          title: l10n.discoverErrorTitle,
          body: l10n.discoverLoadFailed,
          action: FilledButton.tonal(
            onPressed: _reload,
            child: Text(l10n.discoverRetry),
          ),
        );
      }
      return const Center(child: CircularProgressIndicator());
    }
    return _buildFeed(context, items);
  }

  Widget _buildFeed(BuildContext context, List<DiscoverItem> feedItems) {
    final l10n = AppLocalizations.of(context);
    if (_sourceCount == 0) {
      return EmptyStateView(
        icon: Icons.explore_outlined,
        title: l10n.discoverEmptyTitle,
        body: l10n.discoverEmptyBody,
        action: FilledButton.tonal(
          onPressed: () => context.go(AppRoutes.sources),
          child: Text(l10n.discoverGoToSources),
        ),
      );
    }
    if (_searchableSourceCount == 0) {
      return EmptyStateView(
        icon: Icons.search_off_outlined,
        title: l10n.discoverNoSearchableTitle,
        body: l10n.discoverNoSearchableBody,
        action: FilledButton.tonal(
          onPressed: () => context.go(AppRoutes.sources),
          child: Text(l10n.discoverGoToSources),
        ),
      );
    }
    if (feedItems.isEmpty) {
      if (_failures.isNotEmpty) {
        return EmptyStateView(
          icon: Icons.cloud_off_outlined,
          title: l10n.discoverErrorTitle,
          body: l10n.discoverPartialFailure(_failures.length),
          action: FilledButton.tonal(
            onPressed: _reload,
            child: Text(l10n.discoverRetry),
          ),
        );
      }
      return EmptyStateView(
        icon: Icons.movie_filter_outlined,
        title: l10n.discoverNoItemsTitle,
        body: l10n.discoverNoItemsBody,
        action: FilledButton.tonal(
          onPressed: _reload,
          child: Text(l10n.discoverRetry),
        ),
      );
    }
    final items = feedItems.where(_filter.matches).toList(growable: false);
    if (items.isEmpty) {
      return EmptyStateView(
        icon: Icons.filter_alt_off_outlined,
        title: l10n.discoverNoMatchTitle,
        body: l10n.discoverNoMatchBody,
        action: OutlinedButton(
          onPressed: () => setState(() => _filter = const DiscoverFilter()),
          child: Text(l10n.discoverResetFilter),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _reload,
      child: CustomScrollView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: <Widget>[
          if (_failures.isNotEmpty)
            SliverToBoxAdapter(
              child: _FailureBanner(
                count: _failures.length,
                onRetry: _reload,
              ),
            ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
            sliver: SliverLayoutBuilder(
              builder: (context, constraints) {
                final metrics = DiscoverGridMetrics.forExtent(constraints.crossAxisExtent);
                return SliverGrid(
                  gridDelegate: metrics.delegate,
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => DiscoverWorkCard(
                      item: items[index],
                      dense: metrics.dense,
                      onTap: () => context.push(AppRoutes.workDetail, extra: items[index]),
                    ),
                    childCount: items.length,
                  ),
                );
              },
            ),
          ),
          SliverToBoxAdapter(child: _buildFooter(l10n)),
        ],
      ),
    );
  }

  /// 底部翻页状态：加载中 / 加载失败可重试 / 已经到底。
  Widget _buildFooter(AppLocalizations l10n) {
    final theme = Theme.of(context);
    if (_loadMoreFailed) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
        child: Column(
          children: <Widget>[
            Text(
              l10n.discoverLoadMoreFailed,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
            TextButton(onPressed: () => _loadMore(force: true), child: Text(l10n.discoverRetry)),
          ],
        ),
      );
    }
    if (_loadingMore) {
      return const Padding(
        padding: EdgeInsets.fromLTRB(12, 0, 12, 24),
        child: Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }
    // 还有下一页时不在底部常驻转圈：滚动到阈值会自动触发，避免持续动画。
    if (_cursors.isNotEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
      child: Center(
        child: Text(
          l10n.discoverNoMore,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }

  Set<String>? _enabledIds(List<RuleSource>? sources) =>
      sources?.where((source) => source.enabled).map((source) => source.id).toSet();

  bool _sameIds(Set<String> left, Set<String> right) =>
      left.length == right.length && left.containsAll(right);
}

/// 距离列表底部多少像素时开始预加载下一页。
const double _loadMoreThreshold = 600;

class _FailureBanner extends StatelessWidget {
  const _FailureBanner({required this.count, required this.onRetry});

  final int count;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      padding: const EdgeInsets.fromLTRB(12, 6, 6, 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: <Widget>[
          Icon(
            Icons.warning_amber_rounded,
            size: 18,
            color: theme.colorScheme.onErrorContainer,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              l10n.discoverPartialFailure(count),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onErrorContainer,
              ),
            ),
          ),
          TextButton(
            onPressed: onRetry,
            style: TextButton.styleFrom(
              foregroundColor: theme.colorScheme.onErrorContainer,
            ),
            child: Text(l10n.discoverRetry),
          ),
        ],
      ),
    );
  }
}
