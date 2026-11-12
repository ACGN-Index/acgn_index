import 'package:acgn_index/features/viewer/widgets/video_progress_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pumpBar(
  WidgetTester tester, {
  required double value,
  required double buffered,
  bool enabled = true,
  ValueChanged<double>? onChangeStart,
  ValueChanged<double>? onChanged,
  ValueChanged<double>? onChangeEnd,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 300,
            child: VideoProgressBar(
              value: value,
              buffered: buffered,
              enabled: enabled,
              onChangeStart: onChangeStart,
              onChanged: onChanged,
              onChangeEnd: onChangeEnd,
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('点击进度条按比例回调', (tester) async {
    final started = <double>[];
    final changed = <double>[];
    final ended = <double>[];
    await _pumpBar(
      tester,
      value: 0.25,
      buffered: 0.5,
      onChangeStart: started.add,
      onChanged: changed.add,
      onChangeEnd: ended.add,
    );

    final topLeft = tester.getTopLeft(find.byType(VideoProgressBar));
    // 轨道左右各留 6px 滑块半径，点击 300px 的中点即 0.5。
    await tester.tapAt(topLeft + const Offset(150, 9));
    await tester.pump();

    expect(started.single, closeTo(0.5, 0.01));
    expect(changed.single, closeTo(0.5, 0.01));
    expect(ended.single, closeTo(0.5, 0.01));
  });

  testWidgets('拖动过程中持续回调并在松手时结束', (tester) async {
    final changed = <double>[];
    double? ended;
    await _pumpBar(
      tester,
      value: 0.1,
      buffered: 0.1,
      onChanged: changed.add,
      onChangeEnd: (value) => ended = value,
    );

    final topLeft = tester.getTopLeft(find.byType(VideoProgressBar));
    await tester.dragFrom(topLeft + const Offset(30, 9), const Offset(120, 0));
    await tester.pump();

    expect(changed, isNotEmpty);
    expect(changed.last, greaterThan(0.3));
    expect(ended, isNotNull);
    expect(ended!, closeTo(changed.last, 0.01));
  });

  testWidgets('禁用时不回调', (tester) async {
    var called = false;
    await _pumpBar(
      tester,
      value: 0,
      buffered: 0,
      enabled: false,
      onChangeStart: (_) => called = true,
      onChanged: (_) => called = true,
      onChangeEnd: (_) => called = true,
    );

    final topLeft = tester.getTopLeft(find.byType(VideoProgressBar));
    await tester.tapAt(topLeft + const Offset(150, 9));
    await tester.pump();

    expect(called, isFalse);
  });

  test('缓存区间变化会触发重绘', () {
    const bar = VideoProgressPainter(value: 0.2, buffered: 0.4, thumbRadius: 6, trackHeight: 3);
    const sameValueMoreBuffer = VideoProgressPainter(
      value: 0.2,
      buffered: 0.8,
      thumbRadius: 6,
      trackHeight: 3,
    );

    expect(sameValueMoreBuffer.shouldRepaint(bar), isTrue);
    expect(bar.shouldRepaint(bar), isFalse);
  });
}
