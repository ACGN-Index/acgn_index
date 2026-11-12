import 'dart:async';

import 'package:acgn_index/core/logging/app_logger.dart';
import 'package:acgn_index/core/utils/platform_info.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:window_manager/window_manager.dart';

/// 窗口标题的默认值：应用中文名。
const String appWindowTitle = '次元索引';

/// 窗口标题的分隔符：`作品名 - 集数`。
const String _titleSeparator = ' - ';

/// 拼出「名字 + 集数」形式的窗口标题，缺失的部分自动省略。
String composeWindowTitle(String name, String? chapter) {
  final title = name.trim();
  final detail = chapter?.trim() ?? '';
  if (title.isEmpty) {
    return detail.isEmpty ? appWindowTitle : detail;
  }
  if (detail.isEmpty || detail == title) {
    return title;
  }
  return '$title$_titleSeparator$detail';
}

/// 窗口标题的栈式管理：页面声明自己的标题，离开时回落到上层页面。
///
/// 详情页 → 查看器这类嵌套导航里，查看器退出后由本类负责恢复详情页标题。
class WindowTitleController {
  WindowTitleController({
    Future<void> Function(String title)? apply,
    this.defaultTitle = appWindowTitle,
  }) : _apply = apply ?? _applyToPlatformWindow;

  static final Logger _logger = AppLogger.of('window.title');

  final Future<void> Function(String title) _apply;
  final String defaultTitle;

  /// 按声明顺序记录各页面标题，最后一个即栈顶。
  final Map<Object, String> _titles = <Object, String>{};

  /// 当前生效的标题；没有页面声明时为 [defaultTitle]。
  String get currentTitle => _titles.isEmpty ? defaultTitle : _titles.values.last;

  /// 由 [owner] 声明或更新标题；只有栈顶变化时才真正写入窗口。
  void setTitle(Object owner, String title) {
    final isNew = !_titles.containsKey(owner);
    final isTop = _titles.isNotEmpty && _titles.keys.last == owner;
    _titles[owner] = title;
    if (isNew || isTop) {
      unawaited(_apply(currentTitle));
    }
  }

  /// 释放 [owner] 的声明，窗口标题回落到上层页面或应用名。
  void release(Object owner) {
    if (_titles.remove(owner) == null) {
      return;
    }
    unawaited(_apply(currentTitle));
  }

  static Future<void> _applyToPlatformWindow(String title) async {
    if (!isDesktopPlatform) {
      return;
    }
    try {
      WindowManager.instance.getCurrent()?.title = title;
    } on Object catch (error, stackTrace) {
      // 插件未就绪（例如纯 widget 测试）时不要让页面崩溃。
      _logger.fine('设置窗口标题失败：$title', error, stackTrace);
    }
  }
}

final Provider<WindowTitleController> windowTitleControllerProvider =
    Provider<WindowTitleController>((ref) => WindowTitleController());

/// 页面接管窗口标题：用 [claimWindowTitle] 声明，之后用 [setWindowTitle] 更新。
///
/// 页面销毁时自动释放声明，无需在页面里手动恢复默认标题。
mixin WindowTitleOwner<T extends StatefulWidget> on State<T> {
  WindowTitleController? _windowTitles;

  void claimWindowTitle(WindowTitleController controller, String title) {
    _windowTitles = controller;
    controller.setTitle(this, title);
  }

  void setWindowTitle(String title) => _windowTitles?.setTitle(this, title);

  @override
  void dispose() {
    _windowTitles?.release(this);
    super.dispose();
  }
}
