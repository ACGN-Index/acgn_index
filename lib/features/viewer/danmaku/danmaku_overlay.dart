import 'package:acgn_index/domain/entities/danmaku_comment.dart';
import 'package:acgn_index/features/viewer/danmaku/danmaku_engine.dart';
import 'package:acgn_index/features/viewer/danmaku/danmaku_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// 弹幕层：用 Ticker 驱动时间轴，把可见弹幕画在视频上方。
///
/// 只负责绘制，不拦截手势；播放器控制层叠在它之上。
class DanmakuOverlay extends StatefulWidget {
  const DanmakuOverlay({
    required this.engine,
    required this.settings,
    required this.position,
    required this.playing,
    super.key,
  });

  final DanmakuEngine engine;
  final DanmakuSettings settings;

  /// 播放器上报的当前位置，用于校正本地时钟。
  final Duration position;
  final bool playing;

  @override
  State<DanmakuOverlay> createState() => _DanmakuOverlayState();
}

class _DanmakuOverlayState extends State<DanmakuOverlay> with SingleTickerProviderStateMixin {
  final DanmakuTextMetrics _metrics = DanmakuTextMetrics();
  late final Ticker _ticker;
  late Duration _localPosition;
  Duration _lastTick = Duration.zero;
  Size _viewport = Size.zero;

  @override
  void initState() {
    super.initState();
    _localPosition = widget.position;
    _ticker = createTicker(_onTick);
    widget.engine.seek(_localPosition);
    if (widget.playing) {
      _ticker.start();
    }
  }

  @override
  void didUpdateWidget(DanmakuOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    final layoutChanged =
        oldWidget.settings.fontScale != widget.settings.fontScale ||
        oldWidget.settings.displayArea != widget.settings.displayArea;
    if (oldWidget.engine != widget.engine || layoutChanged) {
      widget.engine.seek(_localPosition);
      _refresh();
    }
    final drift = widget.position - _localPosition;
    if (drift.abs() > const Duration(milliseconds: 400)) {
      _localPosition = widget.position;
      widget.engine.seek(_localPosition);
      _refresh();
    }
    if (widget.playing && !_ticker.isActive) {
      _lastTick = Duration.zero;
      _ticker.start();
    } else if (!widget.playing && _ticker.isActive) {
      _ticker.stop();
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    _metrics.dispose();
    super.dispose();
  }

  void _onTick(Duration elapsed) {
    final delta = elapsed - _lastTick;
    _lastTick = elapsed;
    _localPosition += delta;
    _refresh();
  }

  void _refresh() {
    if (_viewport.isEmpty) {
      return;
    }
    widget.engine.update(
      position: _localPosition,
      viewport: _viewport,
      settings: widget.settings,
      measureTextWidth: (comment) => _metrics.measure(comment, widget.settings),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        if (size != _viewport) {
          _viewport = size;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              _refresh();
            }
          });
        }
        return IgnorePointer(
          child: CustomPaint(
            painter: _DanmakuPainter(
              engine: widget.engine,
              settings: widget.settings,
              metrics: _metrics,
            ),
            child: const SizedBox.expand(),
          ),
        );
      },
    );
  }
}

/// 弹幕文字测量与绘制缓存；测量宽度和绘制样式必须来自同一套参数。
class DanmakuTextMetrics {
  static const int _maxCacheEntries = 400;

  final Map<String, TextPainter> _cache = <String, TextPainter>{};

  TextPainter painterFor(DanmakuComment comment, DanmakuSettings settings) {
    final key =
        '${comment.text}|${comment.bold}|${settings.fontSize}|'
        '${comment.color}|${settings.opacity}';
    final cached = _cache[key];
    if (cached != null) {
      return cached;
    }
    if (_cache.length >= _maxCacheEntries) {
      _cache.clear();
    }
    final painter = TextPainter(
      text: TextSpan(
        text: comment.text,
        style: TextStyle(
          fontSize: settings.fontSize,
          fontWeight: comment.bold ? FontWeight.bold : FontWeight.normal,
          color: Color(comment.color).withValues(alpha: settings.opacity),
          shadows: const <Shadow>[
            Shadow(color: Color(0x99000000), blurRadius: 2, offset: Offset(0, 1)),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    _cache[key] = painter;
    return painter;
  }

  double measure(DanmakuComment comment, DanmakuSettings settings) =>
      painterFor(comment, settings).width;

  void dispose() => _cache.clear();
}

class _DanmakuPainter extends CustomPainter {
  _DanmakuPainter({required this.engine, required this.settings, required this.metrics})
    : super(repaint: engine);

  final DanmakuEngine engine;
  final DanmakuSettings settings;
  final DanmakuTextMetrics metrics;

  @override
  void paint(Canvas canvas, Size size) {
    for (final item in engine.activeItems) {
      final painter = metrics.painterFor(item.comment, settings);
      final laneTop = item.lane * settings.laneHeight;
      final top = laneTop + (settings.laneHeight - painter.height) / 2;
      painter.paint(canvas, Offset(item.x, top < 0 ? 0 : top));
    }
  }

  @override
  bool shouldRepaint(_DanmakuPainter oldDelegate) =>
      oldDelegate.engine != engine || oldDelegate.settings != settings;
}
