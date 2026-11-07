import 'package:acgn_index/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';

/// 主导航项在 UI 侧需要的信息：图标与文案。
///
/// 单独抽出来是为了让 `features/shell` 只依赖这个值对象，
/// 具体的路由路径与页面由组合根 `lib/app` 提供（见 `AppDestination`）。
@immutable
class ShellDestination {
  const ShellDestination({
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });

  /// 未选中时展示的图标。
  final IconData icon;

  /// 选中时展示的图标。
  final IconData selectedIcon;

  /// 从 l10n 取文案，保持 widget 内不硬编码中文。
  final String Function(AppLocalizations l10n) label;
}
