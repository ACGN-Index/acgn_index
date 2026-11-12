import 'package:acgn_index/app/window/window_title.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('composeWindowTitle', () {
    test('名字与集数用分隔符连接', () {
      expect(composeWindowTitle('葬送的芙莉莲', '第 1 集'), '葬送的芙莉莲 - 第 1 集');
    });

    test('缺少集数时只显示名字，并去掉首尾空白', () {
      expect(composeWindowTitle(' 葬送的芙莉莲 ', null), '葬送的芙莉莲');
      expect(composeWindowTitle('葬送的芙莉莲', '   '), '葬送的芙莉莲');
    });

    test('名字与集数相同时不重复拼接', () {
      expect(composeWindowTitle('第一话', '第一话'), '第一话');
    });

    test('缺少名字时退回集数或应用名', () {
      expect(composeWindowTitle('', '第 1 集'), '第 1 集');
      expect(composeWindowTitle('  ', null), appWindowTitle);
    });
  });

  group('WindowTitleController', () {
    late List<String> applied;
    late WindowTitleController controller;

    setUp(() {
      applied = <String>[];
      controller = WindowTitleController(apply: (title) async => applied.add(title));
    });

    test('栈顶页面决定窗口标题，释放后回落到上层页面', () {
      final detail = Object();
      final viewer = Object();

      controller.setTitle(detail, '测试作品');
      expect(applied.last, '测试作品');

      controller.setTitle(viewer, '测试作品 - 第 1 集');
      expect(applied.last, '测试作品 - 第 1 集');

      controller.release(viewer);
      expect(applied.last, '测试作品');
      expect(controller.currentTitle, '测试作品');

      controller.release(detail);
      expect(applied.last, appWindowTitle);
      expect(controller.currentTitle, appWindowTitle);
    });

    test('栈顶页面更新标题会立即写入窗口', () {
      final detail = Object();
      final viewer = Object();

      controller.setTitle(detail, '测试作品');
      controller.setTitle(viewer, '测试作品 - 第 1 集');
      controller.setTitle(viewer, '测试作品 - 第 2 集');

      expect(controller.currentTitle, '测试作品 - 第 2 集');
      expect(applied.last, '测试作品 - 第 2 集');
    });

    test('非栈顶页面更新标题不会覆盖当前页面', () {
      final detail = Object();
      final viewer = Object();

      controller.setTitle(detail, '测试作品');
      controller.setTitle(viewer, '测试作品 - 第 1 集');
      final appliedBefore = List<String>.of(applied);

      controller.setTitle(detail, '另一个名字');

      expect(applied, appliedBefore);
      expect(controller.currentTitle, '测试作品 - 第 1 集');

      controller.release(viewer);
      expect(controller.currentTitle, '另一个名字');
    });

    test('重复释放同一页面不会再次写入窗口', () {
      final viewer = Object();
      controller.setTitle(viewer, '测试作品');
      final appliedBefore = List<String>.of(applied);

      controller.release(viewer);
      controller.release(viewer);

      expect(applied, <String>[...appliedBefore, appWindowTitle]);
    });
  });
}
