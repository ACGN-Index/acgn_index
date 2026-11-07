import 'package:acgn_index/app/router/app_destinations.dart';
import 'package:acgn_index/features/shell/presentation/app_shell.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

export 'app_destinations.dart' show AppRoutes;

/// 应用路由。主 tab 由 [appDestinations] 统一描述，各自维护独立导航栈。
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
      builder: (context, state, navigationShell) =>
          AppShell(navigationShell: navigationShell, destinations: appDestinations),
      branches: <StatefulShellBranch>[
        // 分支顺序与导航项顺序同源，下标即 tab 下标。
        for (final destination in appDestinations)
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: destination.route,
                builder: (context, state) => destination.pageBuilder(context),
              ),
            ],
          ),
      ],
    ),
  ],
);
