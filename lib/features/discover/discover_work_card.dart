import 'package:acgn_index/core/models/media_type.dart';
import 'package:acgn_index/core/widgets/media_type_visuals.dart';
import 'package:acgn_index/domain/entities/discover_feed.dart';
import 'package:acgn_index/l10n/generated/app_localizations.dart';
import 'package:cached_network_image_ce/cached_network_image.dart';
import 'package:flutter/material.dart';

/// 发现页作品卡片：封面 + 底部作品名，点击进入详情。
class DiscoverWorkCard extends StatelessWidget {
  const DiscoverWorkCard({
    required this.item,
    this.onTap,
    this.dense = false,
    super.key,
  });

  final DiscoverItem item;
  final VoidCallback? onTap;

  /// 三列窄屏等列宽较小的场景，收紧内边距与字号。
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final colors = mediaTypeColors(item.type, theme.colorScheme);
    final titleStyle = dense
        ? theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600)
        : theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600);
    return Card.outlined(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: <Widget>[
                  _Cover(item: item, colors: colors, dense: dense),
                  Positioned(
                    top: dense ? 4 : 8,
                    left: dense ? 4 : 8,
                    child: _Badge(
                      label: _typeLabel(l10n, item.type),
                      background: colors.background,
                      foreground: colors.foreground,
                      compact: dense,
                    ),
                  ),
                  if (item.adult)
                    Positioned(
                      top: dense ? 4 : 8,
                      right: dense ? 4 : 8,
                      child: _Badge(
                        label: l10n.discoverAdultBadge,
                        background: theme.colorScheme.errorContainer,
                        foreground: theme.colorScheme.onErrorContainer,
                        compact: dense,
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: dense
                  ? const EdgeInsets.fromLTRB(6, 6, 6, 8)
                  : const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Text(
                item.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: titleStyle,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _typeLabel(AppLocalizations l10n, MediaType type) => switch (type) {
    MediaType.anime => l10n.sourcesTypeAnime,
    MediaType.comic => l10n.sourcesTypeComic,
    MediaType.novel => l10n.sourcesTypeNovel,
  };
}

class _Cover extends StatelessWidget {
  const _Cover({required this.item, required this.colors, required this.dense});

  final DiscoverItem item;
  final MediaTypeColors colors;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final cover = item.cover;
    if (cover == null || cover.isEmpty) {
      return _Placeholder(colors: colors, type: item.type, dense: dense);
    }
    return CachedNetworkImage(
      imageUrl: cover,
      httpHeaders: item.coverHeaders,
      fit: BoxFit.cover,
      memCacheWidth: 400,
      placeholder: (context, url) => _Placeholder(colors: colors, type: item.type, dense: dense),
      errorBuilder: (context, error, stackTrace) =>
          _Placeholder(colors: colors, type: item.type, dense: dense),
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({
    required this.colors,
    required this.type,
    required this.dense,
  });

  final MediaTypeColors colors;
  final MediaType type;
  final bool dense;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: colors.background,
    child: Center(
      child: Icon(
        mediaTypeIcon(type),
        size: dense ? 28 : 40,
        color: colors.foreground,
      ),
    ),
  );
}

class _Badge extends StatelessWidget {
  const _Badge({
    required this.label,
    required this.background,
    required this.foreground,
    this.compact = false,
  });

  final String label;
  final Color background;
  final Color foreground;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: compact
          ? const EdgeInsets.symmetric(horizontal: 4, vertical: 1)
          : const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: foreground,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
