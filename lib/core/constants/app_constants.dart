/// 全局常量。用户可见文案一律走 l10n，不要放这里。
abstract final class AppConstants {
  static const String appName = 'ACGN Index';

  /// 必须与 `pubspec.yaml` 的 `version:` 前缀保持一致，
  /// `test/app/version_consistency_test.dart` 会校验。
  static const String appVersion = '0.1.0';

  static const String repositoryUrl = 'https://github.com/ACGN-Index/ACGN-Index';
  static const String license = 'GPL-3.0';
  static const String databaseName = 'acgn_index';

  /// 规则包文件后缀，导出/导入时使用。
  static const String rulePackExtension = 'acgn.json';

  static const Duration requestTimeout = Duration(seconds: 15);

  /// JS 表达式默认执行上限，超时视为规则错误而不是拖垮 UI。
  static const Duration scriptTimeout = Duration(seconds: 3);

  /// 宽度达到该值（Material 3 expanded 断点）时，主导航由底部栏切换为侧边栏。
  static const double wideLayoutBreakpoint = 840;

  static const String defaultUserAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/128.0.0.0 Safari/537.36';
}
