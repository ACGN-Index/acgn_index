import 'package:acgn_index/app/router/app_router.dart';
import 'package:acgn_index/core/widgets/empty_state_view.dart';
import 'package:acgn_index/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// 收藏：收藏的作品与阅读进度（M2 接入规则引擎后填充）。
class LibraryPage extends StatelessWidget {
  const LibraryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.navLibrary)),
      body: EmptyStateView(
        icon: Icons.bookmark_outline,
        title: l10n.libraryEmptyTitle,
        body: l10n.libraryEmptyBody,
        action: FilledButton.tonal(
          onPressed: () => context.go(AppRoutes.discover),
          child: Text(l10n.navDiscover),
        ),
      ),
    );
  }
}
