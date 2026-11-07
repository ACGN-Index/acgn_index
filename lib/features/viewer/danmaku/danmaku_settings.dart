import 'package:acgn_index/domain/entities/danmaku_comment.dart';
import 'package:flutter/foundation.dart';

/// 弹幕展示参数，同时供引擎排版与画笔渲染使用，保证测量宽度与绘制一致。
@immutable
class DanmakuSettings {
  const DanmakuSettings({
    this.enabled = true,
    this.opacity = 1.0,
    this.fontScale = 1.0,
    this.displayArea = 0.6,
    this.showScroll = true,
    this.showTop = true,
    this.showBottom = true,
  });

  static const double baseFontSize = 18;

  /// 弹幕总开关；关闭后引擎会跳过时间轴上的弹幕。
  final bool enabled;

  /// 0.2 ~ 1.0
  final double opacity;

  /// 0.6 ~ 1.6
  final double fontScale;

  /// 弹幕最多占据视频高度的比例（0.25 ~ 1.0）。
  final double displayArea;

  final bool showScroll;
  final bool showTop;
  final bool showBottom;

  double get fontSize => baseFontSize * fontScale;

  /// 轨道高度 = 字号 + 行间距，引擎按它计算轨道数，画笔按它定位。
  double get laneHeight => fontSize * 1.6;

  bool accepts(DanmakuMode mode) => switch (mode) {
    DanmakuMode.scroll => showScroll,
    DanmakuMode.top => showTop,
    DanmakuMode.bottom => showBottom,
  };

  DanmakuSettings copyWith({
    bool? enabled,
    double? opacity,
    double? fontScale,
    double? displayArea,
    bool? showScroll,
    bool? showTop,
    bool? showBottom,
  }) => DanmakuSettings(
    enabled: enabled ?? this.enabled,
    opacity: opacity ?? this.opacity,
    fontScale: fontScale ?? this.fontScale,
    displayArea: displayArea ?? this.displayArea,
    showScroll: showScroll ?? this.showScroll,
    showTop: showTop ?? this.showTop,
    showBottom: showBottom ?? this.showBottom,
  );

  @override
  bool operator ==(Object other) =>
      other is DanmakuSettings &&
      other.enabled == enabled &&
      other.opacity == opacity &&
      other.fontScale == fontScale &&
      other.displayArea == displayArea &&
      other.showScroll == showScroll &&
      other.showTop == showTop &&
      other.showBottom == showBottom;

  @override
  int get hashCode => Object.hash(
    enabled,
    opacity,
    fontScale,
    displayArea,
    showScroll,
    showTop,
    showBottom,
  );
}
