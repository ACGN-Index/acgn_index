import 'package:acgn_index/app/router/app_destinations.dart';
import 'package:acgn_index/domain/entities/comic_content.dart';
import 'package:acgn_index/domain/entities/novel_content.dart';
import 'package:acgn_index/domain/entities/rule_source.dart';
import 'package:acgn_index/domain/entities/video_content.dart';
import 'package:acgn_index/features/shell/app_shell.dart';
import 'package:acgn_index/features/sources/rule_editor_page.dart';
import 'package:acgn_index/features/viewer/comic_viewer_page.dart';
import 'package:acgn_index/features/viewer/novel_viewer_page.dart';
import 'package:acgn_index/features/viewer/video_viewer_page.dart';
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
  initialLocation: AppRoutes.discover,
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
    // 查看器为全屏页：不带底部导航，内容通过 `extra` 传入。
    GoRoute(
      path: AppRoutes.ruleEditor,
      builder: (context, state) => RuleEditorPage(source: _extraAs<RuleSource>(state)),
    ),
    GoRoute(
      path: AppRoutes.videoViewer,
      builder: (context, state) => VideoViewerPage(content: _extraAs<VideoViewerContent>(state)),
    ),
    GoRoute(
      path: AppRoutes.comicViewer,
      builder: (context, state) => ComicViewerPage(content: _extraAs<ComicViewerContent>(state)),
    ),
    GoRoute(
      path: AppRoutes.novelViewer,
      builder: (context, state) => NovelViewerPage(content: _extraAs<NovelViewerContent>(state)),
    ),
  ],
);

/// 类型不符或未传 `extra` 时返回 null，由页面展示「缺少内容参数」提示。
T? _extraAs<T extends Object>(GoRouterState state) {
  final extra = state.extra;
  return extra is T ? extra : null;
}
