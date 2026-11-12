import 'package:acgn_index/app/router/app_destinations.dart';
import 'package:acgn_index/core/logging/app_logger.dart';
import 'package:acgn_index/core/models/media_type.dart';
import 'package:acgn_index/core/widgets/empty_state_view.dart';
import 'package:acgn_index/core/widgets/media_type_visuals.dart';
import 'package:acgn_index/data/network/webview_cookie_store.dart';
import 'package:acgn_index/data/providers.dart';
import 'package:acgn_index/domain/entities/rule_source.dart';
import 'package:acgn_index/features/sources/delete_rule_dialog.dart';
import 'package:acgn_index/features/sources/rule_login/rule_login_providers.dart';
import 'package:acgn_index/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

enum _SourceAction { login, logout, delete }

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
    final hasLogin = source.pack.login != null;
    final loggedIn = ref.watch(loggedInRuleIdsProvider).asData?.value.contains(source.id) ?? false;
    return ListTile(
      leading: Icon(mediaTypeIcon(source.type)),
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
          if (loggedIn)
            Text(
              l10n.sourcesLoggedIn,
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.primary),
            ),
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Switch(
            value: source.enabled,
            onChanged: (value) =>
                ref.read(ruleSourceRepositoryProvider).setEnabled(source.id, value),
          ),
          if (hasLogin || !source.isBuiltin)
            PopupMenuButton<_SourceAction>(
              tooltip: l10n.sourcesMore,
              icon: const Icon(Icons.more_vert),
              onSelected: (action) async {
                switch (action) {
                  case _SourceAction.login:
                    await _login(context);
                  case _SourceAction.logout:
                    await _logout(context, ref, l10n);
                  case _SourceAction.delete:
                    await _delete(context, ref, l10n);
                }
              },
              itemBuilder: (context) => <PopupMenuEntry<_SourceAction>>[
                if (hasLogin)
                  PopupMenuItem<_SourceAction>(
                    value: _SourceAction.login,
                    child: Row(
                      children: <Widget>[
                        const Icon(Icons.login, size: 20),
                        const SizedBox(width: 12),
                        Text(loggedIn ? l10n.sourcesRelogin : l10n.sourcesLogin),
                      ],
                    ),
                  ),
                if (loggedIn)
                  PopupMenuItem<_SourceAction>(
                    value: _SourceAction.logout,
                    child: Row(
                      children: <Widget>[
                        const Icon(Icons.logout, size: 20),
                        const SizedBox(width: 12),
                        Text(l10n.sourcesLogout),
                      ],
                    ),
                  ),
                if (!source.isBuiltin)
                  PopupMenuItem<_SourceAction>(
                    value: _SourceAction.delete,
                    child: Row(
                      children: <Widget>[
                        const Icon(Icons.delete_outline, size: 20),
                        const SizedBox(width: 12),
                        Text(l10n.sourcesDelete),
                      ],
                    ),
                  ),
              ],
            ),
        ],
      ),
      onTap: () => context.push(AppRoutes.ruleEditor, extra: source),
      isThreeLine: source.notice.isNotEmpty || source.readOnly,
    );
  }

  Future<void> _login(BuildContext context) async {
    if (source.pack.login == null) {
      return;
    }
    await context.push<bool>(AppRoutes.ruleLogin, extra: source.pack);
  }

  Future<void> _logout(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.sourcesLogoutTitle),
        content: Text(l10n.sourcesLogoutBody(source.name)),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.ruleEditorCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.sourcesLogoutConfirm),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) {
      return;
    }
    try {
      await ref.read(ruleAuthRepositoryProvider).delete(source.id);
      if (ref.read(ruleLoginWebViewSupportedProvider)) {
        final login = source.pack.login;
        final uri = login != null && login.hasUrl
            ? Uri.tryParse(login.resolveUrl(source.baseUrl))
            : Uri.tryParse(source.baseUrl);
        if (uri != null) {
          await WebViewCookieStore.clear(uri);
        }
      }
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l10n.sourcesLoggedOut(source.name))));
    } on Object catch (error, stackTrace) {
      AppLogger.of('sources').severe('退出登录失败', error, stackTrace);
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l10n.sourcesLogoutFailed)));
    }
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, AppLocalizations l10n) async {
    final confirmed = await confirmDeleteRule(context, name: source.name);
    if (!confirmed || !context.mounted) {
      return;
    }
    try {
      await ref.read(ruleSourceRepositoryProvider).delete(source.id);
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l10n.sourcesDeleted(source.name))));
    } on Object catch (error, stackTrace) {
      AppLogger.of('sources').severe('删除规则失败', error, stackTrace);
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l10n.sourcesDeleteFailed)));
    }
  }

  String _labelFor(AppLocalizations l10n, MediaType type) => switch (type) {
    MediaType.anime => l10n.sourcesTypeAnime,
    MediaType.comic => l10n.sourcesTypeComic,
    MediaType.novel => l10n.sourcesTypeNovel,
  };
}
