import 'package:acgn_index/core/logging/app_logger.dart';
import 'package:acgn_index/core/utils/cookie_utils.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

/// 读取 / 清理 WebView 中保存的站点 Cookie。
class WebViewCookieStore {
  const WebViewCookieStore._();

  /// 优先通过 CookieManager 读取（包含 HttpOnly Cookie），
  /// 失败或缺失时再尝试 `document.cookie`。
  static Future<Map<String, String>> read(
    Uri url, {
    InAppWebViewController? controller,
  }) async {
    final result = <String, String>{};
    try {
      final cookies = await CookieManager.instance().getCookies(
        url: WebUri(url.toString()),
        webViewController: controller,
      );
      for (final cookie in cookies) {
        result[cookie.name.toString()] = cookie.value.toString();
      }
    } on Object catch (error, stackTrace) {
      AppLogger.of('rule-login').warning('读取 WebView Cookie 失败', error, stackTrace);
    }
    if (controller != null) {
      try {
        final raw = await controller.evaluateJavascript(source: 'document.cookie');
        if (raw is String) {
          for (final entry in parseCookieHeader(raw).entries) {
            result.putIfAbsent(entry.key, () => entry.value);
          }
        }
      } on Object catch (error, stackTrace) {
        AppLogger.of('rule-login').warning('读取 document.cookie 失败', error, stackTrace);
      }
    }
    return result;
  }

  /// 尽力清理该地址下的 WebView Cookie；失败只记录日志。
  static Future<void> clear(Uri url) async {
    try {
      await CookieManager.instance().deleteCookies(url: WebUri(url.toString()));
    } on Object catch (error, stackTrace) {
      AppLogger.of('rule-login').warning('清理 WebView Cookie 失败', error, stackTrace);
    }
  }
}
