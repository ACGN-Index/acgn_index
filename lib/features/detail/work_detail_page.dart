import 'package:acgn_index/app/router/app_destinations.dart';
import 'package:acgn_index/app/window/window_title.dart';
import 'package:acgn_index/core/logging/app_logger.dart';
import 'package:acgn_index/core/utils/html_text.dart';
import 'package:acgn_index/core/widgets/empty_state_view.dart';
import 'package:acgn_index/core/widgets/media_type_visuals.dart';
import 'package:acgn_index/data/providers.dart';
import 'package:acgn_index/domain/entities/discover_feed.dart';
import 'package:acgn_index/domain/entities/viewer_launch.dart';
import 'package:acgn_index/domain/entities/work_view.dart';
import 'package:acgn_index/domain/repositories/work_repository.dart';
import 'package:acgn_index/features/detail/content_source_section.dart';
import 'package:acgn_index/l10n/generated/app_localizations.dart';
import 'package:acgn_index/rule_engine/models/toc_entry.dart';
import 'package:cached_network_image_ce/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// 作品详情：详情字段 + 分组目录，章节按需抓取后进入查看器。
class WorkDetailPage extends ConsumerStatefulWidget {
  const WorkDetailPage({this.item, super.key});

  final DiscoverItem? item;

  @override
  ConsumerState<WorkDetailPage> createState() => _WorkDetailPageState();
}

class _WorkDetailPageState extends ConsumerState<WorkDetailPage>
    with WindowTitleOwner<WorkDetailPage> {
  late final WorkRepository _repository;
  late DiscoverItem? _item;
  Future<WorkView>? _work;
  String? _openingChapter;

  @override
  void initState() {
    super.initState();
    _repository = ref.read(workRepositoryProvider);
    _item = widget.item;
    final item = _item;
    _work = item == null ? null : _loadWork(item);
  }

  void _reload() {
    final item = _item;
    if (item == null) {
      return;
    }
    setState(() {
      _work = _loadWork(item);
    });
  }

  /// 「内容来源」选中的规则替换当前作品，仍停留在同一个详情页。
  void _selectSource(DiscoverItem item) {
    if (item.key == _item?.key) {
      return;
    }
    setState(() {
      _item = item;
      _work = _loadWork(item);
    });
  }

  Future<WorkView> _loadWork(DiscoverItem item) async {
    try {
      final work = await _repository.loadWork(item);
      if (mounted) {
        claimWindowTitle(ref.read(windowTitleControllerProvider), work.title);
      }
      return work;
    } on Object catch (error, stackTrace) {
      AppLogger.of('detail').warning('作品加载失败：${item.ruleId}/${item.id}', error, stackTrace);
      rethrow;
    }
  }

  Future<void> _openChapter(WorkView work, TocEntry chapter) async {
    if (!work.canOpenChapter) {
      _showMessage(AppLocalizations.of(context).detailNoContent);
      return;
    }
    setState(() => _openingChapter = chapter.key);
    try {
      final launch = await _repository.loadChapter(work, chapter);
      if (!mounted) {
        return;
      }
      await _launch(launch);
    } on Object catch (error, stackTrace) {
      AppLogger.of('detail')
          .warning('章节加载失败：${work.item.ruleId}/${chapter.key}', error, stackTrace);
      if (mounted) {
        _showMessage(AppLocalizations.of(context).detailChapterLoadFailed);
      }
    } finally {
      if (mounted) {
        setState(() => _openingChapter = null);
      }
    }
  }

  Future<void> _launch(ViewerLaunch launch) async {
    final l10n = AppLocalizations.of(context);
    switch (launch) {
      case final ComicViewerLaunch comic:
        await context.push(AppRoutes.comicViewer, extra: comic.content);
      case final NovelViewerLaunch novel:
        await context.push(AppRoutes.novelViewer, extra: novel.content);
      case final VideoViewerLaunch video:
        await context.push(AppRoutes.videoViewer, extra: video.content);
      case final FileViewerLaunch file:
        await Clipboard.setData(ClipboardData(text: file.url.toString()));
        if (mounted) {
          _showMessage(l10n.detailFileOnly(file.format));
        }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.detailTitle)),
      body: _item == null
          ? EmptyStateView(
              icon: Icons.link_off,
              title: l10n.detailMissingItem,
              body: l10n.viewerContentMissingBody,
            )
          : FutureBuilder<WorkView>(
              future: _work,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError || snapshot.data == null) {
                  return EmptyStateView(
                    icon: Icons.cloud_off_outlined,
                    title: l10n.detailLoadFailed,
                    body: l10n.detailLoadFailed,
                    action: FilledButton.tonal(
                      onPressed: _reload,
                      child: Text(l10n.discoverRetry),
                    ),
                  );
                }
                return _buildWork(context, snapshot.data!);
              },
            ),
    );
  }

  Widget _buildWork(BuildContext context, WorkView work) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final detail = work.detail;
    final info = <String>[
      if (detail.author case final String author) '${l10n.detailAuthor}：$author',
      if (detail.status case final String status) '${l10n.detailStatus}：$status',
      if (detail.year case final String year) '${l10n.detailYear}：$year',
      if (detail.rating case final String rating) '${l10n.detailRating}：$rating',
      if (detail.episodeCount case final int count) '${l10n.detailEpisodeCount}：$count',
    ];
    final intro = detail.intro;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: <Widget>[
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _Cover(work: work),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(work.title, style: theme.textTheme.titleLarge),
                  if (info.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 8),
                    for (final line in info)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          line,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                  ],
                  if (detail.tags.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: <Widget>[
                        for (final tag in detail.tags) Chip(label: Text(tag)),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        if (intro != null && intro.trim().isNotEmpty) ...<Widget>[
          const SizedBox(height: 20),
          Text(l10n.detailIntro, style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          SelectableText(htmlToPlainText(intro)),
        ],
        const SizedBox(height: 20),
        ContentSourceSection(
          key: ValueKey<String>(work.item.key),
          work: work,
          onSelected: _selectSource,
        ),
        const SizedBox(height: 24),
        Text(l10n.detailChapters, style: theme.textTheme.titleMedium),
        if (!work.canOpenChapter) ...<Widget>[
          const SizedBox(height: 8),
          _InfoBanner(text: l10n.detailNoContent),
        ],
        const SizedBox(height: 8),
        if (work.toc.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Text(
              l10n.detailNoToc,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          )
        else
          ..._buildToc(work),
      ],
    );
  }

  List<Widget> _buildToc(WorkView work) {
    final theme = Theme.of(context);
    final widgets = <Widget>[];
    for (final group in work.toc.groups) {
      if (group.title.isNotEmpty) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 4),
            child: Text(
              group.title,
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
          ),
        );
      }
      for (final entry in group.entries) {
        final subtitle = _chapterSubtitle(entry);
        final loading = _openingChapter == entry.key;
        widgets.add(
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 4),
            leading: const Icon(Icons.list_alt_outlined),
            title: Text(entry.title),
            subtitle: subtitle == null ? null : Text(subtitle),
            trailing: loading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : null,
            enabled: work.canOpenChapter && _openingChapter == null,
            onTap: work.canOpenChapter && _openingChapter == null
                ? () => _openChapter(work, entry)
                : null,
          ),
        );
      }
    }
    return widgets;
  }

  String? _chapterSubtitle(TocEntry entry) {
    final parts = <String>[
      if (entry.order case final int order) '#$order',
      if (entry.airdate case final String airdate) airdate,
      if (entry.duration case final String duration) duration,
    ];
    return parts.isEmpty ? null : parts.join(' · ');
  }
}

class _Cover extends StatelessWidget {
  const _Cover({required this.work});

  final WorkView work;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = mediaTypeColors(work.type, theme.colorScheme);
    final placeholder = Container(
      width: 104,
      height: 148,
      color: colors.background,
      child: Icon(mediaTypeIcon(work.type), size: 40, color: colors.foreground),
    );
    final cover = work.detail.cover ?? work.item.cover;
    if (cover == null || cover.isEmpty) {
      return ClipRRect(borderRadius: BorderRadius.circular(12), child: placeholder);
    }
    final headers = work.detail.headers.isEmpty ? work.item.coverHeaders : work.detail.headers;
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: CachedNetworkImage(
        imageUrl: cover,
        httpHeaders: headers.isEmpty ? null : headers,
        width: 104,
        height: 148,
        fit: BoxFit.cover,
        memCacheWidth: 320,
        placeholder: (context, url) => placeholder,
        errorBuilder: (context, error, stackTrace) => placeholder,
      ),
    );
  }
}

class _InfoBanner extends StatelessWidget {
  const _InfoBanner({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: <Widget>[
          Icon(
            Icons.info_outline,
            size: 18,
            color: theme.colorScheme.onSecondaryContainer,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSecondaryContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
