import 'package:acgn_index/core/constants/app_constants.dart';
import 'package:acgn_index/features/shell/presentation/shell_destination.dart';
import 'package:acgn_index/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// 应用外壳：窄屏用底部导航，宽屏改用侧边导航，分支导航栈不变。
///
/// 导航项由路由表注入，与 `StatefulShellRoute` 的分支同源，避免图标/文案
/// 与页面不符；注入的是 const 列表，build 时只做映射，不重复分配数据。
class AppShell extends StatelessWidget {
  const AppShell({required this.navigationShell, required this.destinations, super.key});

  final StatefulNavigationShell navigationShell;

  /// 顺序必须与分支顺序一致：下标既是 tab 下标也是分支下标。
  final List<ShellDestination> destinations;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    void onDestinationSelected(int index) => navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );

    // LayoutBuilder 会在窗口尺寸变化时重建，从而随宽度实时切换导航形态。
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= AppConstants.wideLayoutBreakpoint;
        if (!isWide) {
          return Scaffold(
            body: navigationShell,
            bottomNavigationBar: NavigationBar(
              selectedIndex: navigationShell.currentIndex,
              onDestinationSelected: onDestinationSelected,
              destinations: <Widget>[
                for (final destination in destinations)
                  NavigationDestination(
                    icon: Icon(destination.icon),
                    selectedIcon: Icon(destination.selectedIcon),
                    label: destination.label(l10n),
                  ),
              ],
            ),
          );
        }

        return Scaffold(
          body: Row(
            children: <Widget>[
              NavigationRail(
                selectedIndex: navigationShell.currentIndex,
                onDestinationSelected: onDestinationSelected,
                labelType: NavigationRailLabelType.all,
                destinations: <NavigationRailDestination>[
                  for (final destination in destinations)
                    NavigationRailDestination(
                      icon: Icon(destination.icon),
                      selectedIcon: Icon(destination.selectedIcon),
                      label: Text(destination.label(l10n)),
                    ),
                ],
              ),
              const VerticalDivider(width: 1),
              Expanded(child: navigationShell),
            ],
          ),
        );
      },
    );
  }
}
