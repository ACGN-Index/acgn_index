import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 当前平台是否提供可用的内置 WebView。
bool isRuleLoginWebViewSupported() {
  if (kIsWeb) {
    return false;
  }
  return switch (defaultTargetPlatform) {
    TargetPlatform.android ||
    TargetPlatform.iOS ||
    TargetPlatform.macOS ||
    TargetPlatform.windows ||
    TargetPlatform.linux => true,
    TargetPlatform.fuchsia => false,
  };
}

/// 测试可覆盖为 false，避免在无插件环境构建 WebView。
final Provider<bool> ruleLoginWebViewSupportedProvider = Provider<bool>(
  (ref) => isRuleLoginWebViewSupported(),
);
