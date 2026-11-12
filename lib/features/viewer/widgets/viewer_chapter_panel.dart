import 'package:acgn_index/domain/entities/viewer_chapter_source.dart';
import 'package:acgn_index/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';

/// 播放器里的选集面板：播放线路 + 整部作品的章节列表。
///
/// 窄屏放在视频下方的滚动区，宽屏放进右侧栏，全屏时放进底部弹层。
class ViewerChapterPanel extends StatelessWidget {
  const ViewerChapterPanel({
    required this.chapters,
    required this.currentChapterKey,
    required this.onSelectChapter,
    this.lines = const <String>[],
    this.currentLineIndex = 0,
    this.onSelectLine,
    this.header,
    this.loading = false,
    this.scrollable = true,
    this.padding = const EdgeInsets.fromLTRB(16, 12, 16, 24),
    super.key,
  });

  final List<ViewerChapterRef> chapters;
  final String? currentChapterKey;
  final ValueChanged<ViewerChapterRef> onSelectChapter;

  /// 当前章节的多条线路；只有一条时隐藏。
  final List<String> lines;
  final int currentLineIndex;
  final ValueChanged<int>? onSelectLine;

  final Widget? header;
  final bool loading;
  final bool scrollable;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final leading = <Widget>[
      if (loading)
        const Padding(
          padding: EdgeInsets.only(bottom: 8),
          child: LinearProgressIndicator(minHeight: 2),
        ),
      if (header != null) Padding(padding: const EdgeInsets.only(bottom: 12), child: header),
      if (lines.length > 1) ...<Widget>[
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(l10n.viewerPlaybackLine, style: theme.textTheme.titleSmall),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              for (var i = 0; i < lines.length; i++)
                ChoiceChip(
                  label: Text(lines[i]),
                  selected: i == currentLineIndex,
                  onSelected: (_) => onSelectLine?.call(i),
                ),
            ],
          ),
        ),
      ],
      Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Text(l10n.viewerEpisodeCount(chapters.length), style: theme.textTheme.titleSmall),
      ),
    ];
    final rows = _buildRows();
    final itemCount = leading.length + rows.length;

    return ListView.builder(
      shrinkWrap: !scrollable,
      physics: scrollable ? null : const NeverScrollableScrollPhysics(),
      padding: padding,
      itemCount: itemCount,
      itemBuilder: (context, index) {
        if (index < leading.length) {
          return leading[index];
        }
        return _buildRow(context, rows[index - leading.length]);
      },
    );
  }

  Widget _buildRow(BuildContext context, _PanelRow row) => switch (row) {
    _GroupRow(:final title) => Padding(
      padding: const EdgeInsets.fromLTRB(4, 12, 4, 8),
      child: Text(title, style: Theme.of(context).textTheme.labelLarge),
    ),
    _ChapterRow(:final chapter) => ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12),
      selected: chapter.key == currentChapterKey,
      title: Text(chapter.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: chapter.key == currentChapterKey
          ? Text(
              AppLocalizations.of(context).viewerCurrentEpisode,
              style: Theme.of(context).textTheme.labelSmall,
            )
          : null,
      onTap: () => onSelectChapter(chapter),
    ),
  };

  List<_PanelRow> _buildRows() {
    final rows = <_PanelRow>[];
    String? group;
    for (final chapter in chapters) {
      final title = chapter.groupTitle;
      if (title != null && title.isNotEmpty && title != group) {
        group = title;
        rows.add(_GroupRow(title));
      }
      rows.add(_ChapterRow(chapter));
    }
    return rows;
  }
}

sealed class _PanelRow {
  const _PanelRow();
}

final class _GroupRow extends _PanelRow {
  const _GroupRow(this.title);

  final String title;
}

final class _ChapterRow extends _PanelRow {
  const _ChapterRow(this.chapter);

  final ViewerChapterRef chapter;
}
