import 'dart:async';

import 'package:acgn_index/app/router/app_destinations.dart';
import 'package:acgn_index/core/logging/app_logger.dart';
import 'package:acgn_index/core/widgets/empty_state_view.dart';
import 'package:acgn_index/core/widgets/media_type_visuals.dart';
import 'package:acgn_index/data/providers.dart';
import 'package:acgn_index/domain/entities/discover_feed.dart';
import 'package:acgn_index/domain/entities/rule_page_cursor.dart';
import 'package:acgn_index/domain/entities/work_search.dart';
import 'package:acgn_index/domain/repositories/work_search_repository.dart';
import 'package:acgn_index/features/discover/discover_grid.dart';
import 'package:acgn_index/features/discover/discover_work_card.dart';
import 'package:acgn_index/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// 跨规则搜索：输入关键词后并发检索所有启用的规则，结果按规则分组。
class SearchPage extends ConsumerStatefulWidget {
  const SearchPage({super.key});

  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends ConsumerState<SearchPage> {
  static const Duration _debounceDuration = Duration(milliseconds: 400);

  late final WorkSearchRepository _repository;
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final Set<String> _keys = <String>{};
  Timer? _debounce;

  String _keyword = '';
  List<WorkSearchGroup> _groups = const <WorkSearchGroup>[];
  List<RulePageCursor> _cursors = const <RulePageCursor>[];
  Object? _error;
  bool _loading = false;
  bool _loadingMore = false;
  bool _loadMoreFailed = false;

  /// 递增的请求号；防抖期间连续输入时用它丢弃过期响应。
  int _requestId = 0;

  @override
  void initState() {
    super.initState();
    _repository = ref.read(workSearchRepositoryProvider);
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    final keyword = value.trim();
    setState(() {});
    if (keyword.isEmpty) {
      _requestId++;
      _keys.clear();
      setState(() {
        _keyword = '';
        _groups = const <WorkSearchGroup>[];
        _cursors = const <RulePageCursor>[];
        _error = null;
        _loading = false;
        _loadingMore = false;
        _loadMoreFailed = false;
      });
      return;
    }
    _debounce = Timer(_debounceDuration, () => unawaited(_search(keyword)));
  }

  void _submitQuery(String value) {
    _debounce?.cancel();
    final keyword = value.trim();
    if (keyword.isEmpty) {
      return;
    }
    unawaited(_search(keyword));
  }

  void _clearQuery() {
    _controller.clear();
    _onQueryChanged('');
  }

  Future<void> _search(String keyword) async {
    final requestId = ++_requestId;
    _keys.clear();
    setState(() {
      _keyword = keyword;
      _groups = const <WorkSearchGroup>[];
      _cursors = const <RulePageCursor>[];
      _error = null;
      _loading = true;
      _loadingMore = false;
      _loadMoreFailed = false;
    });
    try {
      final page = await _repository.search(keyword);
      if (!mounted || requestId != _requestId) {
        return;
      }
      for (final group in page.groups) {
        for (final item in group.items) {
          _keys.add(item.key);
        }
      }
      setState(() {
        _groups = page.groups;
        _cursors = page.cursors;
        _loading = false;
      });
      _scheduleFillCheck();
    } on Object catch (error, stackTrace) {
      AppLogger.of('search').warning('搜索失败：$keyword', error, stackTrace);
      if (!mounted || requestId != _requestId) {
        return;
      }
      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  void _onScroll() {
    if (_scrollController.position.extentAfter > _loadMoreThreshold) {
      return;
    }
    unawaited(_loadMore());
  }

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
    if (_loading || _loadingMore || _cursors.isEmpty) {
      return;
    }
    // 失败后不自动重试同一游标，避免坏规则在触底时反复请求。
    if (_loadMoreFailed && !force) {
      return;
    }
    final requestId = _requestId;
    final keyword = _keyword;
    setState(() {
      _loadingMore = true;
      _loadMoreFailed = false;
    });
    try {
      final page = await _repository.loadMore(keyword, _cursors);
      if (!mounted || requestId != _requestId) {
        return;
      }
      var added = 0;
      final groups = List<WorkSearchGroup>.of(_groups);
      final indexById = <String, int>{
        for (var index = 0; index < groups.length; index++) groups[index].ruleId: index,
      };
      for (final group in page.groups) {
        final newItems = <DiscoverItem>[
          for (final item in group.items)
            if (_keys.add(item.key)) item,
        ];
        added += newItems.length;
        final index = indexById[group.ruleId];
        if (index == null) {
          groups.add(group);
          indexById[group.ruleId] = groups.length - 1;
        } else if (newItems.isNotEmpty) {
          groups[index] = groups[index].appendItems(newItems);
        }
      }
      setState(() {
        _loadingMore = false;
        _groups = List<WorkSearchGroup>.unmodifiable(groups);
        // 整页都是重复条目说明分页已失去意义，停止继续翻页。
        _cursors = added == 0 && page.groups.any((group) => group.items.isNotEmpty)
            ? const <RulePageCursor>[]
            : page.cursors;
      });
      if (added > 0) {
        _scheduleFillCheck();
      }
    } on Object catch (error, stackTrace) {
      AppLogger.of('search').warning('搜索加载更多失败：$keyword', error, stackTrace);
      if (!mounted || requestId != _requestId) {
        return;
      }
      setState(() {
        _loadingMore = false;
        _loadMoreFailed = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: TextField(
          controller: _controller,
          autofocus: true,
          textInputAction: TextInputAction.search,
          onChanged: _onQueryChanged,
          onSubmitted: _submitQuery,
          decoration: InputDecoration(
            hintText: l10n.discoverSearchHint,
            border: InputBorder.none,
          ),
        ),
        actions: <Widget>[
          if (_controller.text.isNotEmpty)
            IconButton(
              onPressed: _clearQuery,
              tooltip: l10n.searchClear,
              icon: const Icon(Icons.close),
            ),
        ],
      ),
      body: _buildBody(context, l10n),
    );
  }

  Widget _buildBody(BuildContext context, AppLocalizations l10n) {
    if (_keyword.isEmpty) {
      return EmptyStateView(
        icon: Icons.search,
        title: l10n.searchEmptyKeywordTitle,
        body: l10n.searchEmptyKeywordBody,
      );
    }
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return EmptyStateView(
        icon: Icons.cloud_off_outlined,
        title: l10n.searchErrorTitle,
        body: l10n.searchErrorBody,
        action: FilledButton.tonal(
          onPressed: () => _search(_keyword),
          child: Text(l10n.discoverRetry),
        ),
      );
    }
    if (_groups.isEmpty) {
      return EmptyStateView(
        icon: Icons.search_off_outlined,
        title: l10n.searchNoProviderTitle,
        body: l10n.searchNoProviderBody,
        action: FilledButton.tonal(
          onPressed: () => context.go(AppRoutes.sources),
          child: Text(l10n.discoverGoToSources),
        ),
      );
    }
    if (_groups.every((group) => group.status == WorkSearchStatus.failed)) {
      return EmptyStateView(
        icon: Icons.cloud_off_outlined,
        title: l10n.searchErrorTitle,
        body: l10n.searchErrorBody,
        action: FilledButton.tonal(
          onPressed: () => _search(_keyword),
          child: Text(l10n.discoverRetry),
        ),
      );
    }
    if (_groups.every((group) => !group.hasResults)) {
      return EmptyStateView(
        icon: Icons.movie_filter_outlined,
        title: l10n.searchNoResultTitle,
        body: l10n.searchNoResultBody,
        action: OutlinedButton(
          onPressed: () => _search(_keyword),
          child: Text(l10n.discoverRetry),
        ),
      );
    }
    return CustomScrollView(
      controller: _scrollController,
      slivers: <Widget>[
        for (final group in _groups) ...<Widget>[
          SliverToBoxAdapter(child: _GroupHeader(group: group)),
          if (group.hasResults)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              sliver: SliverLayoutBuilder(
                builder: (context, constraints) {
                  final metrics = DiscoverGridMetrics.forExtent(constraints.crossAxisExtent);
                  return SliverGrid(
                    gridDelegate: metrics.delegate,
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => DiscoverWorkCard(
                        item: group.items[index],
                        dense: metrics.dense,
                        onTap: () => context.push(AppRoutes.workDetail, extra: group.items[index]),
                      ),
                      childCount: group.items.length,
                    ),
                  );
                },
              ),
            ),
        ],
        SliverToBoxAdapter(child: _buildFooter(l10n)),
      ],
    );
  }

  Widget _buildFooter(AppLocalizations l10n) {
    final theme = Theme.of(context);
    if (_loadMoreFailed) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
        child: Column(
          children: <Widget>[
            Text(
              l10n.discoverLoadMoreFailed,
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error),
            ),
            TextButton(
              onPressed: () => _loadMore(force: true),
              child: Text(l10n.discoverRetry),
            ),
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
}

/// 距列表底部多少像素时开始预加载下一页。
const double _loadMoreThreshold = 600;

/// 单条规则的结果分组标题：类型图标 + 规则名 + 状态。
class _GroupHeader extends StatelessWidget {
  const _GroupHeader({required this.group});

  final WorkSearchGroup group;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final colors = theme.colorScheme;
    final status = switch (group.status) {
      WorkSearchStatus.ok => l10n.searchGroupResultCount(group.items.length),
      WorkSearchStatus.noResult => l10n.searchGroupNoResult,
      WorkSearchStatus.failed => l10n.searchGroupFailed,
    };
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      child: Row(
        children: <Widget>[
          Icon(mediaTypeIcon(group.type), size: 18, color: colors.onSurfaceVariant),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              group.ruleName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleSmall,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            status,
            style: theme.textTheme.labelMedium?.copyWith(
              color: group.status == WorkSearchStatus.failed
                  ? colors.error
                  : colors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
