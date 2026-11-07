import 'package:acgn_index/features/discover/presentation/discover_page.dart';
import 'package:acgn_index/features/library/presentation/library_page.dart';
import 'package:acgn_index/features/settings/presentation/settings_page.dart';
import 'package:acgn_index/features/shell/presentation/app_shell.dart';
import 'package:acgn_index/features/sources/presentation/sources_page.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// 路由路径常量，避免字符串散落在页面间跳转处。
abstract final class AppRoutes {
  static const String library = '/library';
  static const String discover = '/discover';
  static const String sources = '/sources';
  static const String settings = '/settings';
}

/// 应用路由。四个主 tab 各自维护独立导航栈。
final Provider<GoRouter> appRouterProvider = Provider<GoRouter>((ref) {
  final router = createAppRouter();
  ref.onDispose(router.dispose);
  return router;
});

/// 每次调用都返回全新实例，测试据此隔离导航状态。
GoRouter createAppRouter() => GoRouter(
  initialLocation: AppRoutes.library,
  routes: <RouteBase>[
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) => AppShell(navigationShell: navigationShell),
      branches: <StatefulShellBranch>[
        StatefulShellBranch(
          routes: <RouteBase>[
            GoRoute(path: AppRoutes.library, builder: (context, state) => const LibraryPage()),
          ],
        ),
        StatefulShellBranch(
          routes: <RouteBase>[
            GoRoute(path: AppRoutes.discover, builder: (context, state) => const DiscoverPage()),
          ],
        ),
        StatefulShellBranch(
          routes: <RouteBase>[
            GoRoute(path: AppRoutes.sources, builder: (context, state) => const SourcesPage()),
          ],
        ),
        StatefulShellBranch(
          routes: <RouteBase>[
            GoRoute(path: AppRoutes.settings, builder: (context, state) => const SettingsPage()),
          ],
        ),
      ],
    ),
  ],
);
