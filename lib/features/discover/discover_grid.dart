import 'dart:math' as math;

import 'package:flutter/material.dart';

/// 作品网格的度量：列数、单列宽度与对应的 [SliverGridDelegate]。
///
/// 发现页与搜索页共用同一套列宽策略，避免两处网格在窗口缩放时列数不一致。
@immutable
class DiscoverGridMetrics {
  const DiscoverGridMetrics._({required this.columns, required this.cardWidth});

  factory DiscoverGridMetrics.forExtent(double crossAxisExtent) {
    final columns = math.max(
      _minColumns,
      math.min(_maxColumns, (crossAxisExtent / _targetCardWidth).round()),
    );
    final cardWidth = (crossAxisExtent - spacing * (columns - 1)) / columns;
    return DiscoverGridMetrics._(columns: columns, cardWidth: cardWidth);
  }

  /// 网格间距，横纵相同。
  static const double spacing = 8;

  /// 三列窄屏等列宽较小的场景，卡片收起内边距与字号。
  static const double _denseCardWidth = 136;

  /// 每列的目标宽度，决定不同窗口宽度下的列数。
  static const double _targetCardWidth = 170;

  static const int _minColumns = 3;
  static const int _maxColumns = 10;

  final int columns;
  final double cardWidth;

  bool get dense => cardWidth < _denseCardWidth;

  SliverGridDelegateWithFixedCrossAxisCount get delegate =>
      SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        childAspectRatio: 0.62,
        crossAxisSpacing: spacing,
        mainAxisSpacing: spacing,
      );
}
