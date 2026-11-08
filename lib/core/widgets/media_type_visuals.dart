import 'package:acgn_index/core/models/media_type.dart';
import 'package:flutter/material.dart';

/// 内容类型对应的图标，规则页与发现页共用。
IconData mediaTypeIcon(MediaType type) => switch (type) {
  MediaType.anime => Icons.live_tv_outlined,
  MediaType.comic => Icons.auto_stories_outlined,
  MediaType.novel => Icons.menu_book_outlined,
};

/// 内容类型对应的容器配色。
class MediaTypeColors {
  const MediaTypeColors({required this.background, required this.foreground});

  final Color background;
  final Color foreground;
}

MediaTypeColors mediaTypeColors(MediaType type, ColorScheme scheme) => switch (type) {
  MediaType.anime => MediaTypeColors(
    background: scheme.primaryContainer,
    foreground: scheme.onPrimaryContainer,
  ),
  MediaType.comic => MediaTypeColors(
    background: scheme.secondaryContainer,
    foreground: scheme.onSecondaryContainer,
  ),
  MediaType.novel => MediaTypeColors(
    background: scheme.tertiaryContainer,
    foreground: scheme.onTertiaryContainer,
  ),
};
