import 'dart:math' as math;

import 'package:acgn_index/app/router/app_destinations.dart';
import 'package:acgn_index/core/logging/app_logger.dart';
import 'package:acgn_index/core/widgets/empty_state_view.dart';
import 'package:acgn_index/data/providers.dart';
import 'package:acgn_index/domain/entities/discover_feed.dart';
import 'package:acgn_index/domain/entities/rule_source.dart';
import 'package:acgn_index/domain/repositories/discover_feed_repository.dart';
import 'package:acgn_index/features/discover/discover_filter.dart';
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
  late Future<DiscoverFeed> _feed;
  DiscoverFilter _filter = const DiscoverFilter();

  @override
  void initState() {
    super.initState();
    _repository = ref.read(discoverFeedRepositoryProvider);
    _feed = _repository.load();
  }

  Future<void> _reload() async {
    final future = _repository.load();
    if (mounted) {
      setState(() {
        _feed = future;
      });
    }
    try {
      await future;
    } on Object catch (error, stackTrace) {
      AppLogger.of('discover').warning('发现页加载失败', error, stackTrace);
    }
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
            onPressed: _reload,
            tooltip: l10n.discoverRefresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: FutureBuilder<DiscoverFeed>(
        future: _feed,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
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
          return _buildFeed(context, snapshot.data ?? DiscoverFeed.empty);
        },
      ),
    );
  }

  Widget _buildFeed(BuildContext context, DiscoverFeed feed) {
    final l10n = AppLocalizations.of(context);
    if (feed.sourceCount == 0) {
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
    if (feed.searchableSourceCount == 0) {
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
    if (feed.items.isEmpty) {
      if (feed.hasFailures) {
        return EmptyStateView(
          icon: Icons.cloud_off_outlined,
          title: l10n.discoverErrorTitle,
          body: l10n.discoverPartialFailure(feed.failures.length),
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
    final items = feed.items.where(_filter.matches).toList(growable: false);
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
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: <Widget>[
          if (feed.hasFailures)
            SliverToBoxAdapter(
              child: _FailureBanner(
                count: feed.failures.length,
                onRetry: _reload,
              ),
            ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
            sliver: SliverLayoutBuilder(
              builder: (context, constraints) {
                final columns = _gridColumnsFor(constraints.crossAxisExtent);
                final itemWidth =
                    (constraints.crossAxisExtent - _gridSpacing * (columns - 1)) / columns;
                return SliverGrid(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    childAspectRatio: 0.62,
                    crossAxisSpacing: _gridSpacing,
                    mainAxisSpacing: _gridSpacing,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => DiscoverWorkCard(
                      item: items[index],
                      dense: itemWidth < _denseCardWidth,
                      onTap: () => context.push(AppRoutes.workDetail, extra: items[index]),
                    ),
                    childCount: items.length,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Set<String>? _enabledIds(List<RuleSource>? sources) =>
      sources?.where((source) => source.enabled).map((source) => source.id).toSet();

  bool _sameIds(Set<String> left, Set<String> right) =>
      left.length == right.length && left.containsAll(right);
}

const double _gridSpacing = 8;

/// 卡片窄于该宽度时收起内边距与字号，保证窄屏三列也能读。
const double _denseCardWidth = 136;

/// 网格每列的目标宽度，决定不同窗口宽度下的列数。
const double _gridTargetCardWidth = 170;

const int _gridMinColumns = 3;
const int _gridMaxColumns = 10;

/// 按可用宽度计算作品网格列数：窄屏（手机）至少 3 列，宽屏随宽度增长。
int _gridColumnsFor(double crossAxisExtent) {
  final columns = (crossAxisExtent / _gridTargetCardWidth).round();
  return math.max(_gridMinColumns, math.min(_gridMaxColumns, columns));
}

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
