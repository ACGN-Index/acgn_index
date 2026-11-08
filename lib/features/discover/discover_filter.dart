import 'package:acgn_index/core/models/media_type.dart';
import 'package:acgn_index/domain/entities/discover_feed.dart';
import 'package:acgn_index/domain/entities/rule_source.dart';
import 'package:acgn_index/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';

/// 发现页筛选：内容类型 + 规则来源。
@immutable
class DiscoverFilter {
  const DiscoverFilter({this.type, this.origin});

  final MediaType? type;
  final RuleSourceOrigin? origin;

  bool get isActive => type != null || origin != null;

  bool matches(DiscoverItem item) =>
      (type == null || item.type == type) && (origin == null || item.origin == origin);
}

Future<DiscoverFilter?> showDiscoverFilterSheet(
  BuildContext context,
  DiscoverFilter initial,
) => showModalBottomSheet<DiscoverFilter>(
  context: context,
  showDragHandle: true,
  useSafeArea: true,
  isScrollControlled: true,
  constraints: const BoxConstraints(maxWidth: 640),
  builder: (context) => _DiscoverFilterSheet(initial: initial),
);

class _DiscoverFilterSheet extends StatefulWidget {
  const _DiscoverFilterSheet({required this.initial});

  final DiscoverFilter initial;

  @override
  State<_DiscoverFilterSheet> createState() => _DiscoverFilterSheetState();
}

class _DiscoverFilterSheetState extends State<_DiscoverFilterSheet> {
  late MediaType? _type = widget.initial.type;
  late RuleSourceOrigin? _origin = widget.initial.origin;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        20 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(l10n.discoverFilterTitle, style: theme.textTheme.titleLarge),
          const SizedBox(height: 20),
          Text(l10n.discoverFilterType, style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              _chip(
                label: l10n.discoverFilterAll,
                selected: _type == null,
                onSelected: () => setState(() => _type = null),
              ),
              for (final type in MediaType.values)
                _chip(
                  label: _typeLabel(l10n, type),
                  selected: _type == type,
                  onSelected: () => setState(() => _type = type),
                ),
            ],
          ),
          const SizedBox(height: 20),
          Text(l10n.discoverFilterCategory, style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              _chip(
                label: l10n.discoverFilterAll,
                selected: _origin == null,
                onSelected: () => setState(() => _origin = null),
              ),
              _chip(
                label: l10n.discoverFilterBuiltin,
                selected: _origin == RuleSourceOrigin.builtin,
                onSelected: () => setState(() => _origin = RuleSourceOrigin.builtin),
              ),
              _chip(
                label: l10n.discoverFilterImported,
                selected: _origin == RuleSourceOrigin.imported,
                onSelected: () => setState(() => _origin = RuleSourceOrigin.imported),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: <Widget>[
              Expanded(
                child: OutlinedButton(
                  onPressed: () => setState(() {
                    _type = null;
                    _origin = null;
                  }),
                  child: Text(l10n.discoverFilterReset),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: () => Navigator.of(
                    context,
                  ).pop(DiscoverFilter(type: _type, origin: _origin)),
                  child: Text(l10n.discoverFilterApply),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _chip({
    required String label,
    required bool selected,
    required VoidCallback onSelected,
  }) => ChoiceChip(
    label: Text(label),
    selected: selected,
    onSelected: (_) => onSelected(),
  );

  String _typeLabel(AppLocalizations l10n, MediaType type) => switch (type) {
    MediaType.anime => l10n.sourcesTypeAnime,
    MediaType.comic => l10n.sourcesTypeComic,
    MediaType.novel => l10n.sourcesTypeNovel,
  };
}
