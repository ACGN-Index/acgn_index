import 'dart:async';

import 'package:acgn_index/core/logging/app_logger.dart';
import 'package:acgn_index/core/widgets/media_type_visuals.dart';
import 'package:acgn_index/data/providers.dart';
import 'package:acgn_index/domain/entities/content_source.dart';
import 'package:acgn_index/domain/entities/discover_feed.dart';
import 'package:acgn_index/domain/entities/work_view.dart';
import 'package:acgn_index/domain/repositories/content_source_repository.dart';
import 'package:acgn_index/l10n/generated/app_localizations.dart';
import 'package:cached_network_image_ce/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 详情页的「内容来源」：按来源分组检索同一作品的其它规则。
///
/// 交互参考 Kazumi 的播放来源面板：每个来源有独立的检索词、检索状态与结果，
/// 单个来源可以改词、换别名或重新检索；当前规则没有正文时默认展开。
class ContentSourceSection extends ConsumerStatefulWidget {
  const ContentSourceSection({required this.work, required this.onSelected, super.key});

  final WorkView work;

  /// 选中某个来源后的回调；由详情页在当前页内完成切换。
  final ValueChanged<DiscoverItem> onSelected;

  @override
  ConsumerState<ContentSourceSection> createState() => _ContentSourceSectionState();
}

class _ContentSourceSectionState extends ConsumerState<ContentSourceSection> {
  late final ContentSourceRepository _repository;
  late bool _sectionOpen;
  ContentSourceResult? _result;
  Object? _error;
  bool _loading = true;
  final Set<String> _collapsedGroups = <String>{};
  final Set<String> _busyGroups = <String>{};

  ContentSourceQuery get _query => ContentSourceQuery(
    type: widget.work.type,
    title: widget.work.title,
    aliases: widget.work.detail.aliases,
    excludeRuleId: widget.work.item.ruleId,
  );

  @override
  void initState() {
    super.initState();
    _repository = ref.read(contentSourceRepositoryProvider);
    _sectionOpen = !widget.work.canOpenChapter;
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final result = await _repository.search(_query);
      if (!mounted) {
        return;
      }
      setState(() {
        _result = result;
        _error = null;
        _loading = false;
      });
    } on Object catch (error, stackTrace) {
      AppLogger.of('detail').warning('内容来源检索失败：${widget.work.item.key}', error, stackTrace);
      if (!mounted) {
        return;
      }
      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  void _retryAll() {
    setState(() {
      _loading = true;
      _error = null;
    });
    unawaited(_load());
  }

  Future<void> _refreshProvider(ContentSourceGroup group, String keyword) async {
    if (_busyGroups.contains(group.ruleId)) {
      return;
    }
    setState(() => _busyGroups.add(group.ruleId));
    try {
      final updated = await _repository.refreshProvider(
        _query,
        ruleId: group.ruleId,
        keyword: keyword,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _busyGroups.remove(group.ruleId);
        final current = _result;
        if (updated != null && current != null) {
          _result = current.replaceGroup(updated);
          _collapsedGroups.remove(group.ruleId);
        }
      });
    } on Object catch (error, stackTrace) {
      AppLogger.of('detail').warning(
        '内容来源重新检索失败：${group.ruleId}/$keyword',
        error,
        stackTrace,
      );
      if (!mounted) {
        return;
      }
      setState(() => _busyGroups.remove(group.ruleId));
    }
  }

  Future<void> _changeKeyword(ContentSourceGroup group) async {
    final l10n = AppLocalizations.of(context);
    final keyword = await showDialog<String>(
      context: context,
      builder: (context) => _KeywordDialog(
        title: l10n.detailContentSourcesKeywordTitle,
        hint: l10n.detailContentSourcesKeywordHint,
        cancelLabel: l10n.ruleEditorCancel,
        applyLabel: l10n.detailContentSourcesApply,
        initialValue: group.keyword,
      ),
    );
    final trimmed = keyword?.trim() ?? '';
    if (trimmed.isEmpty || trimmed == group.keyword) {
      return;
    }
    await _refreshProvider(group, trimmed);
  }

  Future<void> _pickAlias(ContentSourceGroup group) async {
    final aliases = widget.work.detail.aliases;
    if (aliases.isEmpty) {
      return;
    }
    final l10n = AppLocalizations.of(context);
    final alias = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(l10n.detailContentSourcesUseAlias),
        children: <Widget>[
          for (final candidate in aliases)
            SimpleDialogOption(
              onPressed: () => Navigator.of(context).pop(candidate),
              child: Text(candidate),
            ),
        ],
      ),
    );
    if (alias == null) {
      return;
    }
    await _refreshProvider(group, alias);
  }

  void _toggleGroup(String ruleId) {
    setState(() {
      if (!_collapsedGroups.remove(ruleId)) {
        _collapsedGroups.add(ruleId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final result = _result;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => setState(() => _sectionOpen = !_sectionOpen),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: <Widget>[
                      Text(l10n.detailContentSources, style: theme.textTheme.titleMedium),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _summary(l10n, result),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      Icon(
                        _sectionOpen ? Icons.expand_less : Icons.expand_more,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (_sectionOpen)
              IconButton(
                tooltip: l10n.detailContentSourcesRefresh,
                onPressed: _loading ? null : _retryAll,
                icon: const Icon(Icons.refresh, size: 20),
              ),
          ],
        ),
        if (_sectionOpen) ..._buildBody(l10n, result),
      ],
    );
  }

  String _summary(AppLocalizations l10n, ContentSourceResult? result) {
    if (_loading) {
      return l10n.detailContentSourcesSearching;
    }
    if (_error != null || result == null) {
      return l10n.detailContentSourcesLoadFailed;
    }
    return l10n.detailContentSourcesSummary(result.providerCount, result.resultCount);
  }

  List<Widget> _buildBody(AppLocalizations l10n, ContentSourceResult? result) {
    if (_loading) {
      return <Widget>[
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: LinearProgressIndicator(minHeight: 2),
        ),
      ];
    }
    if (_error != null || result == null) {
      return <Widget>[
        _MessageRow(
          text: l10n.detailContentSourcesLoadFailed,
          actionLabel: l10n.detailContentSourcesRetry,
          onAction: _retryAll,
        ),
      ];
    }
    if (result.providerCount == 0) {
      return <Widget>[_MessageRow(text: l10n.detailContentSourcesNoProvider)];
    }
    return <Widget>[
      const SizedBox(height: 4),
      for (final group in result.groups) _buildGroup(group, l10n),
    ];
  }

  Widget _buildGroup(ContentSourceGroup group, AppLocalizations l10n) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final expanded = !_collapsedGroups.contains(group.ruleId);
    final busy = _busyGroups.contains(group.ruleId);
    final status = switch (group.status) {
      ContentSourceStatus.ok => l10n.detailContentSourcesResultCount(group.items.length),
      ContentSourceStatus.noResult => l10n.detailContentSourcesStatusNoResult,
      ContentSourceStatus.failed => l10n.detailContentSourcesStatusFailed,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => _toggleGroup(group.ruleId),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(4, 10, 0, 10),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          group.ruleName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall,
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (busy)
                        const SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      else
                        Text(
                          status,
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: group.status == ContentSourceStatus.failed
                                ? colors.error
                                : colors.onSurfaceVariant,
                          ),
                        ),
                      const SizedBox(width: 4),
                      Icon(
                        expanded ? Icons.expand_less : Icons.expand_more,
                        size: 20,
                        color: colors.onSurfaceVariant,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            PopupMenuButton<_GroupAction>(
              tooltip: l10n.detailContentSourcesActions(group.ruleName),
              icon: const Icon(Icons.more_horiz, size: 20),
              onSelected: (action) {
                switch (action) {
                  case _GroupAction.changeKeyword:
                    unawaited(_changeKeyword(group));
                  case _GroupAction.refresh:
                    unawaited(_refreshProvider(group, group.keyword));
                  case _GroupAction.useAlias:
                    unawaited(_pickAlias(group));
                }
              },
              itemBuilder: (context) => <PopupMenuEntry<_GroupAction>>[
                PopupMenuItem<_GroupAction>(
                  value: _GroupAction.changeKeyword,
                  child: Text(l10n.detailContentSourcesChangeKeyword),
                ),
                PopupMenuItem<_GroupAction>(
                  value: _GroupAction.refresh,
                  child: Text(l10n.detailContentSourcesRefreshProvider),
                ),
                if (widget.work.detail.aliases.isNotEmpty)
                  PopupMenuItem<_GroupAction>(
                    value: _GroupAction.useAlias,
                    child: Text(l10n.detailContentSourcesUseAlias),
                  ),
              ],
            ),
          ],
        ),
        if (expanded) ...<Widget>[
          if (group.keyword != _query.title)
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 4),
              child: Text(
                l10n.detailContentSourcesKeywordUsed(group.keyword),
                style: theme.textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
              ),
            ),
          ..._buildGroupBody(group, l10n),
        ],
      ],
    );
  }

  List<Widget> _buildGroupBody(ContentSourceGroup group, AppLocalizations l10n) {
    switch (group.status) {
      case ContentSourceStatus.failed:
        return <Widget>[
          _MessageRow(
            text: l10n.detailContentSourcesFailedProvider,
            actionLabel: l10n.detailContentSourcesRetry,
            onAction: () => unawaited(_refreshProvider(group, group.keyword)),
          ),
        ];
      case ContentSourceStatus.noResult:
        return <Widget>[
          _MessageRow(
            text: l10n.detailContentSourcesEmpty,
            actionLabel: l10n.detailContentSourcesChangeKeyword,
            onAction: () => unawaited(_changeKeyword(group)),
            secondaryLabel: widget.work.detail.aliases.isEmpty
                ? null
                : l10n.detailContentSourcesUseAlias,
            onSecondary: widget.work.detail.aliases.isEmpty
                ? null
                : () => unawaited(_pickAlias(group)),
          ),
        ];
      case ContentSourceStatus.ok:
        return <Widget>[
          for (final item in group.items)
            _ContentSourceTile(item: item, onTap: () => widget.onSelected(item)),
        ];
    }
  }
}

enum _GroupAction { changeKeyword, refresh, useAlias }

/// 检索词输入框：由对话框自己持有控制器，避免关闭动画期间被提前释放。
class _KeywordDialog extends StatefulWidget {
  const _KeywordDialog({
    required this.title,
    required this.hint,
    required this.cancelLabel,
    required this.applyLabel,
    required this.initialValue,
  });

  final String title;
  final String hint;
  final String cancelLabel;
  final String applyLabel;
  final String initialValue;

  @override
  State<_KeywordDialog> createState() => _KeywordDialogState();
}

class _KeywordDialogState extends State<_KeywordDialog> {
  late final TextEditingController _controller = TextEditingController(text: widget.initialValue);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() => Navigator.of(context).pop(_controller.text);

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: TextField(
      controller: _controller,
      autofocus: true,
      textInputAction: TextInputAction.done,
      decoration: InputDecoration(hintText: widget.hint),
      onSubmitted: (_) => _submit(),
    ),
    actions: <Widget>[
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: Text(widget.cancelLabel),
      ),
      FilledButton(onPressed: _submit, child: Text(widget.applyLabel)),
    ],
  );
}

class _ContentSourceTile extends StatelessWidget {
  const _ContentSourceTile({required this.item, required this.onTap});

  final DiscoverItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = mediaTypeColors(item.type, theme.colorScheme);
    final placeholder = ColoredBox(
      color: colors.background,
      child: Center(
        child: Icon(mediaTypeIcon(item.type), size: 22, color: colors.foreground),
      ),
    );
    final cover = item.cover;
    final subtitle = item.subtitle;
    final subtitleText = subtitle == null || subtitle.trim().isEmpty
        ? item.ruleName
        : '${item.ruleName} · $subtitle';
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: 44,
          height: 62,
          child: cover == null || cover.isEmpty
              ? placeholder
              : CachedNetworkImage(
                  imageUrl: cover,
                  httpHeaders: item.coverHeaders.isEmpty ? null : item.coverHeaders,
                  fit: BoxFit.cover,
                  memCacheWidth: 200,
                  placeholder: (context, url) => placeholder,
                  errorBuilder: (context, error, stackTrace) => placeholder,
                ),
        ),
      ),
      title: Text(item.title, maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: Text(subtitleText, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}

class _MessageRow extends StatelessWidget {
  const _MessageRow({
    required this.text,
    this.actionLabel,
    this.onAction,
    this.secondaryLabel,
    this.onSecondary,
  });

  final String text;
  final String? actionLabel;
  final VoidCallback? onAction;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          if (actionLabel case final String label)
            TextButton(onPressed: onAction, child: Text(label)),
          if (secondaryLabel case final String label)
            TextButton(onPressed: onSecondary, child: Text(label)),
        ],
      ),
    );
  }
}
