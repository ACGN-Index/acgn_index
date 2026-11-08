import 'package:acgn_index/core/models/media_type.dart';
import 'package:acgn_index/core/widgets/media_type_visuals.dart';
import 'package:acgn_index/domain/entities/discover_feed.dart';
import 'package:acgn_index/l10n/generated/app_localizations.dart';
import 'package:cached_network_image_ce/cached_network_image.dart';
import 'package:flutter/material.dart';

/// 发现页作品卡片：封面 + 底部作品名，点击进入详情。
class DiscoverWorkCard extends StatelessWidget {
  const DiscoverWorkCard({required this.item, this.onTap, super.key});

  final DiscoverItem item;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final colors = mediaTypeColors(item.type, theme.colorScheme);
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
                  _Cover(item: item, colors: colors),
                  Positioned(
                    top: 8,
                    left: 8,
                    child: _Badge(
                      label: _typeLabel(l10n, item.type),
                      background: colors.background,
                      foreground: colors.foreground,
                    ),
                  ),
                  if (item.adult)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: _Badge(
                        label: l10n.discoverAdultBadge,
                        background: theme.colorScheme.errorContainer,
                        foreground: theme.colorScheme.onErrorContainer,
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Text(
                item.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
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
  const _Cover({required this.item, required this.colors});

  final DiscoverItem item;
  final MediaTypeColors colors;

  @override
  Widget build(BuildContext context) {
    final cover = item.cover;
    if (cover == null || cover.isEmpty) {
      return _Placeholder(colors: colors, type: item.type);
    }
    return CachedNetworkImage(
      imageUrl: cover,
      httpHeaders: item.coverHeaders,
      fit: BoxFit.cover,
      memCacheWidth: 400,
      placeholder: (context, url) => _Placeholder(colors: colors, type: item.type),
      errorBuilder: (context, error, stackTrace) => _Placeholder(colors: colors, type: item.type),
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.colors, required this.type});

  final MediaTypeColors colors;
  final MediaType type;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: colors.background,
    child: Center(
      child: Icon(mediaTypeIcon(type), size: 40, color: colors.foreground),
    ),
  );
}

class _Badge extends StatelessWidget {
  const _Badge({
    required this.label,
    required this.background,
    required this.foreground,
  });

  final String label;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
