import 'package:acgn_index/core/logging/app_logger.dart';
import 'package:acgn_index/core/utils/platform_info.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:window_manager/window_manager.dart';

/// 窗口 / 全屏切换的抽象；测试里覆盖成假实现，避免触碰真实窗口。
///
/// 只负责「真全屏」；宽屏下的「窗口全屏」是收起侧栏的纯 UI 行为，不经过这里。
abstract interface class PlayerWindowController {
  bool get isDesktop;

  Future<void> enterFullscreen();

  Future<void> exitFullscreen();
}

final Provider<PlayerWindowController> playerWindowControllerProvider =
    Provider<PlayerWindowController>((ref) => PlatformPlayerWindowController());

/// 桌面用 window_manager，移动端继续用 SystemChrome。
class PlatformPlayerWindowController implements PlayerWindowController {
  static final Logger _logger = AppLogger.of('viewer.window');

  @override
  bool get isDesktop => isDesktopPlatform;

  @override
  Future<void> enterFullscreen() async {
    if (isDesktop) {
      await _guard('进入全屏', () async => WindowManager.instance.getCurrent()?.isFullScreen = true);
      return;
    }
    await _guard('进入全屏', () => SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky));
  }

  @override
  Future<void> exitFullscreen() async {
    if (isDesktop) {
      await _guard('退出全屏', () async => WindowManager.instance.getCurrent()?.isFullScreen = false);
      return;
    }
    await _guard('退出全屏', () => SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge));
  }

  Future<void> _guard(String action, Future<void> Function() body) async {
    try {
      await body();
    } on Object catch (error, stackTrace) {
      // 插件未初始化（例如纯 widget 测试）时不要让播放器崩溃。
      _logger.warning('$action失败', error, stackTrace);
    }
  }
}
