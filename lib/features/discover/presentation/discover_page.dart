import 'package:acgn_index/core/widgets/empty_state_view.dart';
import 'package:acgn_index/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';

/// 发现：跨规则源的搜索与榜单（M2 接入）。
class DiscoverPage extends StatelessWidget {
  const DiscoverPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.navDiscover)),
      body: EmptyStateView(
        icon: Icons.explore_outlined,
        title: l10n.discoverEmptyTitle,
        body: l10n.discoverEmptyBody,
      ),
    );
  }
}
