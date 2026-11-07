import 'dart:ui';

import 'package:acgn_index/domain/entities/danmaku_comment.dart';
import 'package:acgn_index/features/viewer/danmaku/danmaku_engine.dart';
import 'package:acgn_index/features/viewer/danmaku/danmaku_settings.dart';
import 'package:flutter_test/flutter_test.dart';

const Size _viewport = Size(1000, 400);
const DanmakuSettings _settings = DanmakuSettings();

double _measure(DanmakuComment comment) => comment.text.length * 10;

void _update(
  DanmakuEngine engine,
  Duration position, {
  DanmakuSettings settings = _settings,
}) {
  engine.update(
    position: position,
    viewport: _viewport,
    settings: settings,
    measureTextWidth: _measure,
  );
}

/// 按 100ms 步进推进，模拟播放器的连续回调。
void _advance(DanmakuEngine engine, Duration from, Duration to) {
  var cursor = from;
  while (cursor < to) {
    cursor += const Duration(milliseconds: 100);
    _update(engine, cursor);
  }
}

void main() {
  test('到达出现时间前不展示弹幕', () {
    final engine = DanmakuEngine(
      comments: <DanmakuComment>[
        const DanmakuComment(position: Duration(seconds: 1), text: 'ab'),
      ],
    );

    _update(engine, Duration.zero);
    expect(engine.activeItems, isEmpty);

    _update(engine, const Duration(seconds: 1));
    expect(engine.activeItems, hasLength(1));
    expect(engine.activeItems.single.x, _viewport.width);
  });

  test('同一时刻的滚动弹幕分配到不同轨道', () {
    final engine = DanmakuEngine(
      comments: <DanmakuComment>[
        const DanmakuComment(position: Duration.zero, text: 'a'),
        const DanmakuComment(position: Duration.zero, text: 'b'),
        const DanmakuComment(position: Duration.zero, text: 'c'),
      ],
    );

    _update(engine, Duration.zero);

    expect(
      engine.activeItems.map((item) => item.lane).toList(),
      <int>[0, 1, 2],
    );
  });

  test('轨道数量受显示区域限制，超出后丢弃', () {
    final engine = DanmakuEngine(
      comments: <DanmakuComment>[
        for (var i = 0; i < 20; i++) DanmakuComment(position: Duration.zero, text: 'comment$i'),
      ],
    );

    _update(engine, Duration.zero);

    final laneCount = (_viewport.height * _settings.displayArea / _settings.laneHeight).floor();
    expect(engine.activeItems, hasLength(laneCount));
  });

  test('前一条滚动弹幕完全进入屏幕后轨道可复用', () {
    final engine = DanmakuEngine(
      comments: <DanmakuComment>[
        const DanmakuComment(position: Duration.zero, text: 'a'),
        const DanmakuComment(position: Duration(seconds: 2), text: 'b'),
      ],
    );

    _advance(engine, Duration.zero, const Duration(seconds: 2));

    final second = engine.activeItems.last;
    expect(second.comment.text, 'b');
    expect(second.lane, 0);
  });

  test('顶部弹幕自上而下、底部弹幕自下而上分配轨道', () {
    final engine = DanmakuEngine(
      comments: <DanmakuComment>[
        const DanmakuComment(position: Duration.zero, text: 't1', mode: DanmakuMode.top),
        const DanmakuComment(position: Duration.zero, text: 't2', mode: DanmakuMode.top),
        const DanmakuComment(position: Duration.zero, text: 'b1', mode: DanmakuMode.bottom),
      ],
    );

    _update(engine, Duration.zero);

    final laneCount = (_viewport.height * _settings.displayArea / _settings.laneHeight).floor();
    final lanes = <String, int>{
      for (final item in engine.activeItems) item.comment.text: item.lane,
    };
    expect(lanes['t1'], 0);
    expect(lanes['t2'], 1);
    expect(lanes['b1'], laneCount - 1);
  });

  test('滚动弹幕离开屏幕后被回收', () {
    final engine = DanmakuEngine(
      comments: <DanmakuComment>[
        const DanmakuComment(position: Duration.zero, text: 'a'),
      ],
    );

    _advance(engine, Duration.zero, const Duration(seconds: 9));

    expect(engine.activeItems, isEmpty);
  });

  test('关闭弹幕时不投放，重新打开后不补发历史弹幕', () {
    final engine = DanmakuEngine(
      comments: <DanmakuComment>[
        const DanmakuComment(position: Duration(seconds: 1), text: 'a'),
        const DanmakuComment(position: Duration(seconds: 3), text: 'b'),
      ],
    );

    _update(engine, const Duration(seconds: 2), settings: _settings.copyWith(enabled: false));
    expect(engine.activeItems, isEmpty);

    _update(engine, const Duration(seconds: 2), settings: _settings.copyWith(enabled: true));
    expect(engine.activeItems, isEmpty);

    _update(engine, const Duration(seconds: 3));
    expect(engine.activeItems.single.comment.text, 'b');
  });

  test('seek 后从新位置继续投放', () {
    final engine = DanmakuEngine(
      comments: <DanmakuComment>[
        const DanmakuComment(position: Duration(seconds: 1), text: 'a'),
        const DanmakuComment(position: Duration(seconds: 5), text: 'b'),
      ],
    );

    _advance(engine, Duration.zero, const Duration(seconds: 2));
    expect(engine.activeItems.single.comment.text, 'a');

    engine.seek(const Duration(seconds: 4));
    _update(engine, const Duration(seconds: 4));
    expect(engine.activeItems, isEmpty);

    _advance(engine, const Duration(seconds: 4), const Duration(seconds: 5));
    expect(engine.activeItems.single.comment.text, 'b');
  });

  test('用户发送的弹幕在轨道占满时仍然展示', () {
    final engine = DanmakuEngine(
      comments: <DanmakuComment>[
        for (var i = 0; i < 20; i++) DanmakuComment(position: Duration.zero, text: 'comment$i'),
      ],
    );
    _update(engine, Duration.zero);
    final before = engine.activeItems.length;

    engine.addComment(
      comment: const DanmakuComment(position: Duration.zero, text: 'mine'),
      measureTextWidth: _measure,
    );

    expect(engine.activeItems, hasLength(before + 1));
    expect(engine.activeItems.last.comment.text, 'mine');
  });
}
