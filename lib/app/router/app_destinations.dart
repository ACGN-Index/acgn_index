import 'package:acgn_index/features/discover/discover_page.dart';
import 'package:acgn_index/features/library/library_page.dart';
import 'package:acgn_index/features/settings/settings_page.dart';
import 'package:acgn_index/features/shell/shell_destination.dart';
import 'package:acgn_index/features/sources/sources_page.dart';
import 'package:acgn_index/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';

/// 路由路径常量，避免字符串散落在页面间跳转处。
abstract final class AppRoutes {
  static const String library = '/library';
  static const String discover = '/discover';
  static const String sources = '/sources';
  static const String settings = '/settings';

  /// 查看器是全屏页，挂在根路由上而不是主导航分支里。
  static const String videoViewer = '/viewer/video';
  static const String comicViewer = '/viewer/comic';
  static const String novelViewer = '/viewer/novel';
}

/// 一个主导航项：同时描述该 tab 的路由/页面与导航栏的图标、文案。
///
/// 路由表与导航栏都只读 [appDestinations]，因此两侧不会出现
/// 「图标换了但路由没换」的不一致；顺序即 tab 顺序，亦即分支下标。
@immutable
class AppDestination extends ShellDestination {
  const AppDestination({
    required super.icon,
    required super.selectedIcon,
    required super.label,
    required this.route,
    required this.pageBuilder,
  });

  /// tab 的根路径，同时作为该分支内 [GoRoute] 的 `path`。
  final String route;

  /// tab 页面构建器；由分支内的 [GoRoute] 调用。
  final WidgetBuilder pageBuilder;
}

/// 唯一的 tab 定义表：顺序 = 底部/侧边导航顺序 = [StatefulShellBranch] 下标。
///
/// 常量列表，不会随 build 重新分配；原地调整顺序即可同步导航栏与路由。
const List<AppDestination> appDestinations = <AppDestination>[
  AppDestination(
    route: AppRoutes.discover,
    pageBuilder: _buildDiscoverPage,
    icon: Icons.explore_outlined,
    selectedIcon: Icons.explore,
    label: _discoverLabel,
  ),
  AppDestination(
    route: AppRoutes.library,
    pageBuilder: _buildLibraryPage,
    icon: Icons.bookmark_outline,
    selectedIcon: Icons.bookmark,
    label: _libraryLabel,
  ),
  AppDestination(
    route: AppRoutes.sources,
    pageBuilder: _buildSourcesPage,
    icon: Icons.tune_outlined,
    selectedIcon: Icons.tune,
    label: _sourcesLabel,
  ),
  AppDestination(
    route: AppRoutes.settings,
    pageBuilder: _buildSettingsPage,
    icon: Icons.person_outline,
    selectedIcon: Icons.person,
    label: _settingsLabel,
  ),
];

// 用顶层函数（而非闭包）承接页面与文案，才能让 appDestinations 保持 const。
Widget _buildDiscoverPage(BuildContext context) => const DiscoverPage();
Widget _buildLibraryPage(BuildContext context) => const LibraryPage();
Widget _buildSourcesPage(BuildContext context) => const SourcesPage();
Widget _buildSettingsPage(BuildContext context) => const SettingsPage();

String _discoverLabel(AppLocalizations l10n) => l10n.navDiscover;
String _libraryLabel(AppLocalizations l10n) => l10n.navLibrary;
String _sourcesLabel(AppLocalizations l10n) => l10n.navSources;
String _settingsLabel(AppLocalizations l10n) => l10n.navSettings;
