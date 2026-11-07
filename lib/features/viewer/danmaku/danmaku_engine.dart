import 'dart:math' as math;
import 'dart:ui';

import 'package:acgn_index/domain/entities/danmaku_comment.dart';
import 'package:acgn_index/features/viewer/danmaku/danmaku_settings.dart';
import 'package:flutter/foundation.dart';

/// 一条正在展示的弹幕；由 [DanmakuEngine] 创建并逐帧更新 [x]。
class DanmakuRenderItem {
  DanmakuRenderItem({
    required this.comment,
    required this.lane,
    required this.width,
    required this.startedAt,
    required this.velocity,
  });

  final DanmakuComment comment;
  final int lane;
  final double width;
  final Duration startedAt;

  /// 滚动弹幕的速度（px/s）；顶部/底部弹幕为 0。
  final double velocity;

  /// 当前帧的左边缘位置。
  double x = 0;
}

/// 弹幕时间轴与轨道分配。
///
/// 与 Widget 解耦，可脱离界面单测；滚动弹幕使用恒定速度，
/// 所有弹幕速度一致，因此后出现的弹幕不会追尾前面的弹幕，
/// 轨道是否可用只需看前一条是否已完全进入屏幕。
class DanmakuEngine extends ChangeNotifier {
  DanmakuEngine({List<DanmakuComment> comments = const <DanmakuComment>[]}) {
    setComments(comments);
  }

  /// 滚动弹幕横穿整个屏幕所需时间。
  static const Duration scrollDuration = Duration(seconds: 8);

  /// 顶部/底部弹幕的停留时间。
  static const Duration staticDuration = Duration(seconds: 4);

  /// 同轨道相邻弹幕的最小水平间距。
  static const double laneGap = 24;

  List<DanmakuComment> _comments = const <DanmakuComment>[];
  final List<DanmakuRenderItem> _active = <DanmakuRenderItem>[];
  int _cursor = 0;
  Duration _position = Duration.zero;
  Size _viewport = Size.zero;
  DanmakuSettings _settings = const DanmakuSettings();
  double Function(DanmakuComment comment)? _measure;

  /// 当前可见弹幕，供画笔逐帧读取；不要在外部修改。
  List<DanmakuRenderItem> get activeItems => _active;

  Duration get position => _position;

  /// 切换弹幕列表（例如切换分集），时间轴回到起点。
  void setComments(List<DanmakuComment> comments) {
    _comments = List<DanmakuComment>.of(comments)..sort((a, b) => a.position.compareTo(b.position));
    _active.clear();
    _cursor = 0;
    _position = Duration.zero;
    notifyListeners();
  }

  /// 跳转时间轴；正在展示的弹幕全部清除，交由后续 update 重新投放。
  void seek(Duration position) {
    _position = position;
    _active.clear();
    _cursor = _cursorAtOrAfter(position);
  }

  /// 推进到 [position]：投放到期弹幕、更新位置、回收离屏弹幕。
  void update({
    required Duration position,
    required Size viewport,
    required DanmakuSettings settings,
    required double Function(DanmakuComment comment) measureTextWidth,
  }) {
    _measure = measureTextWidth;
    _settings = settings;
    if (viewport.isEmpty) {
      return;
    }
    _viewport = viewport;

    final drift = position - _position;
    if (drift.isNegative || drift > const Duration(seconds: 1)) {
      seek(position);
    }
    _position = position;

    if (!settings.enabled) {
      _active.clear();
      _cursor = _cursorAfter(position);
      notifyListeners();
      return;
    }

    for (final item in _active) {
      item.x = _xAt(item, position, viewport);
    }
    _active.removeWhere((item) => _isFinished(item, position, viewport));

    while (_cursor < _comments.length && _comments[_cursor].position <= position) {
      final comment = _comments[_cursor];
      _cursor++;
      if (!settings.accepts(comment.mode)) {
        continue;
      }
      _spawn(comment, viewport, settings);
    }
    notifyListeners();
  }

  /// 立即展示一条弹幕：用户发送的弹幕不受时间轴限制。
  void addComment({
    required DanmakuComment comment,
    double Function(DanmakuComment comment)? measureTextWidth,
  }) {
    final measure = measureTextWidth ?? _measure;
    if (_viewport.isEmpty || measure == null) {
      return;
    }
    _measure = measure;
    _spawn(comment, _viewport, _settings, force: true);
    notifyListeners();
  }

  void _spawn(
    DanmakuComment comment,
    Size viewport,
    DanmakuSettings settings, {
    bool force = false,
  }) {
    final measure = _measure;
    if (measure == null) {
      return;
    }
    final width = measure(comment);
    final laneCount = _laneCount(viewport, settings);
    if (laneCount <= 0) {
      return;
    }
    final lane = switch (comment.mode) {
      DanmakuMode.scroll => _scrollLane(viewport, laneCount, force: force),
      DanmakuMode.top => _staticLane(laneCount, comment.mode, force: force),
      DanmakuMode.bottom => _staticLane(laneCount, comment.mode, force: force),
    };
    if (lane == null) {
      return;
    }
    final item = DanmakuRenderItem(
      comment: comment,
      lane: lane,
      width: width,
      startedAt: _position,
      velocity: comment.mode == DanmakuMode.scroll
          ? viewport.width / (scrollDuration.inMilliseconds / 1000)
          : 0,
    );
    item.x = _xAt(item, _position, viewport);
    _active.add(item);
  }

  int _laneCount(Size viewport, DanmakuSettings settings) {
    if (settings.laneHeight <= 0) {
      return 0;
    }
    return math.max(1, (viewport.height * settings.displayArea / settings.laneHeight).floor());
  }

  int? _scrollLane(Size viewport, int laneCount, {required bool force}) {
    for (var lane = 0; lane < laneCount; lane++) {
      if (_laneAvailableForScroll(lane, viewport)) {
        return lane;
      }
    }
    if (!force) {
      return null;
    }
    // 用户弹幕优先展示：挑最靠左的轨道，接受少量重叠。
    var bestLane = 0;
    var bestTail = double.infinity;
    for (var lane = 0; lane < laneCount; lane++) {
      final tail = _laneTail(lane);
      if (tail < bestTail) {
        bestTail = tail;
        bestLane = lane;
      }
    }
    return bestLane;
  }

  bool _laneAvailableForScroll(int lane, Size viewport) {
    for (final item in _active) {
      if (item.lane != lane) {
        continue;
      }
      if (item.comment.mode != DanmakuMode.scroll) {
        return false;
      }
      if (item.x + item.width + laneGap > viewport.width) {
        return false;
      }
    }
    return true;
  }

  double _laneTail(int lane) {
    var tail = 0.0;
    for (final item in _active) {
      if (item.lane == lane) {
        tail = math.max(tail, item.x + item.width);
      }
    }
    return tail;
  }

  int? _staticLane(int laneCount, DanmakuMode mode, {required bool force}) {
    for (var i = 0; i < laneCount; i++) {
      final lane = mode == DanmakuMode.top ? i : laneCount - 1 - i;
      final occupied = _active.any(
        (item) => item.lane == lane && item.comment.mode != DanmakuMode.scroll,
      );
      if (!occupied) {
        return lane;
      }
    }
    if (!force) {
      return null;
    }
    return mode == DanmakuMode.top ? 0 : laneCount - 1;
  }

  double _xAt(DanmakuRenderItem item, Duration position, Size viewport) {
    if (item.comment.mode != DanmakuMode.scroll) {
      return (viewport.width - item.width) / 2;
    }
    final elapsedMicros = (position - item.startedAt).inMicroseconds;
    return viewport.width - item.velocity * (elapsedMicros / Duration.microsecondsPerSecond);
  }

  bool _isFinished(DanmakuRenderItem item, Duration position, Size viewport) {
    if (item.comment.mode == DanmakuMode.scroll) {
      return item.x + item.width <= 0;
    }
    return position - item.startedAt >= staticDuration;
  }

  /// 第一个出现时间不早于 [position] 的弹幕下标。
  int _cursorAtOrAfter(Duration position) {
    var low = 0;
    var high = _comments.length;
    while (low < high) {
      final mid = (low + high) >> 1;
      if (_comments[mid].position < position) {
        low = mid + 1;
      } else {
        high = mid;
      }
    }
    return low;
  }

  /// 第一个出现时间晚于 [position] 的弹幕下标。
  int _cursorAfter(Duration position) {
    var low = 0;
    var high = _comments.length;
    while (low < high) {
      final mid = (low + high) >> 1;
      if (_comments[mid].position <= position) {
        low = mid + 1;
      } else {
        high = mid;
      }
    }
    return low;
  }
}
