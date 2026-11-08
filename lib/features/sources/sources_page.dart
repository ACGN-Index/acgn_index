import 'package:acgn_index/app/router/app_destinations.dart';
import 'package:acgn_index/core/models/media_type.dart';
import 'package:acgn_index/core/widgets/empty_state_view.dart';
import 'package:acgn_index/data/providers.dart';
import 'package:acgn_index/domain/entities/rule_source.dart';
import 'package:acgn_index/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// 规则管理：内置规则集与已导入规则。
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
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push(AppRoutes.ruleEditor),
        tooltip: l10n.sourcesAddRule,
        child: const Icon(Icons.add),
      ),
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
          final builtin = sources.where((source) => source.isBuiltin).toList()
            ..sort((a, b) => a.priority.compareTo(b.priority));
          final imported = sources.where((source) => !source.isBuiltin).toList()
            ..sort((a, b) => a.name.compareTo(b.name));

          return ListView(
            children: <Widget>[
              if (builtin.isNotEmpty) ...<Widget>[
                _SectionHeader(label: l10n.sourcesBuiltinSection, count: builtin.length),
                for (final source in builtin) _SourceTile(source: source),
              ],
              if (imported.isNotEmpty) ...<Widget>[
                _SectionHeader(label: l10n.sourcesImportedSection, count: imported.length),
                for (final source in imported) _SourceTile(source: source),
              ],
              const SizedBox(height: 24),
            ],
          );
        },
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label, required this.count});

  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Row(
        children: <Widget>[
          Text(
            label,
            style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.primary),
          ),
          const SizedBox(width: 8),
          Text('$count', style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _SourceTile extends ConsumerWidget {
  const _SourceTile({required this.source});

  final RuleSource source;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return ListTile(
      leading: Icon(_iconFor(source.type)),
      title: Row(
        children: <Widget>[
          Flexible(child: Text(source.name, overflow: TextOverflow.ellipsis)),
          if (source.readOnly) ...<Widget>[
            const SizedBox(width: 6),
            Icon(Icons.lock_outline, size: 14, color: theme.colorScheme.outline),
          ],
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const SizedBox(height: 2),
          Text('${_labelFor(l10n, source.type)} · ${source.baseUrl}'),
          if (source.notice.isNotEmpty)
            Text(
              source.notice,
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
            ),
          if (source.readOnly)
            Text(
              l10n.sourcesReadOnly,
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
            ),
        ],
      ),
      trailing: Switch(
        value: source.enabled,
        onChanged: (value) => ref.read(ruleSourceRepositoryProvider).setEnabled(source.id, value),
      ),
      onTap: () => context.push(AppRoutes.ruleEditor, extra: source),
      isThreeLine: source.notice.isNotEmpty || source.readOnly,
    );
  }

  IconData _iconFor(MediaType type) => switch (type) {
    MediaType.anime => Icons.live_tv_outlined,
    MediaType.comic => Icons.auto_stories_outlined,
    MediaType.novel => Icons.menu_book_outlined,
  };

  String _labelFor(AppLocalizations l10n, MediaType type) => switch (type) {
    MediaType.anime => l10n.sourcesTypeAnime,
    MediaType.comic => l10n.sourcesTypeComic,
    MediaType.novel => l10n.sourcesTypeNovel,
  };
}
