import 'package:acgn_index/core/widgets/empty_state_view.dart';
import 'package:acgn_index/data/providers.dart';
import 'package:acgn_index/domain/entities/rule_source.dart';
import 'package:acgn_index/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 规则管理：已安装规则源列表（导入/编辑/调试在 M2 提供）。
class SourcesPage extends ConsumerStatefulWidget {
  const SourcesPage({super.key});

  @override
  ConsumerState<SourcesPage> createState() => _SourcesPageState();
}

class _SourcesPageState extends ConsumerState<SourcesPage> {
  late final Stream<List<RuleSource>> _sources = ref.read(ruleSourceRepositoryProvider).watchAll();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.navSources)),
      body: StreamBuilder<List<RuleSource>>(
        stream: _sources,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(l10n.sourcesLoadFailed, textAlign: TextAlign.center),
              ),
            );
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final sources = snapshot.data ?? const <RuleSource>[];
          if (sources.isEmpty) {
            return EmptyStateView(
              icon: Icons.tune_outlined,
              title: l10n.sourcesEmptyTitle,
              body: l10n.sourcesEmptyBody,
            );
          }
          return ListView.separated(
            itemCount: sources.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final source = sources[index];
              return ListTile(
                leading: const Icon(Icons.article_outlined),
                title: Text(source.name),
                subtitle: Text(source.baseUrl),
                trailing: Text(source.version),
              );
            },
          );
        },
      ),
    );
  }
}
