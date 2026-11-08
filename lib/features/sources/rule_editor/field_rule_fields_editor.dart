import 'package:acgn_index/features/sources/rule_editor/editor_controls.dart';
import 'package:acgn_index/features/sources/rule_editor/field_rule_editor_page.dart';
import 'package:acgn_index/features/sources/rule_editor/rule_draft.dart';
import 'package:acgn_index/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';

/// 字段名 → 字段规则的编辑列表，用于 `fields` 与对象数组的子字段。
class EditorFieldRuleMapField extends StatelessWidget {
  const EditorFieldRuleMapField({
    required this.value,
    required this.onChanged,
    this.label,
    this.helper,
    this.suggestions = const <String>[],
    this.keyPrefix = 'field',
    super.key,
  });

  final Map<String, Object?> value;
  final ValueChanged<Map<String, Object?>> onChanged;
  final String? label;
  final String? helper;

  /// "添加字段"时的候选名，通常来自 [kCapabilityFieldSuggestions]。
  final List<String> suggestions;

  /// 列表项 key 前缀，便于测试定位。
  final String keyPrefix;

  Future<void> _addField(BuildContext context, AppLocalizations l10n) async {
    final name = await showDialog<String>(
      context: context,
      builder: (context) => _AddFieldDialog(suggestions: suggestions, existing: value.keys.toSet()),
    );
    if (name == null || !context.mounted) {
      return;
    }
    final edited = await pushFieldRuleEditor(
      context,
      title: l10n.fieldRuleTitleNamed(name),
      rule: <String, Object?>{'selector': ''},
    );
    if (!context.mounted) {
      return;
    }
    onChanged(<String, Object?>{
      ...value,
      name: edited ?? <String, Object?>{'selector': ''},
    });
  }

  void _updateField(String name, Map<String, Object?>? updated) {
    final next = <String, Object?>{...value};
    if (updated == null) {
      next.remove(name);
    } else {
      next[name] = updated;
    }
    onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (label != null) Text(label!, style: theme.textTheme.labelLarge),
        if (helper != null) ...<Widget>[
          const SizedBox(height: 6),
          Text(
            helper!,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
        if (value.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              l10n.ruleFieldFieldsEmpty,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        for (final entry in value.entries)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: EditorFieldRuleTile(
              label: entry.key,
              editorTitle: l10n.fieldRuleTitleNamed(entry.key),
              fieldKey: ValueKey<String>('$keyPrefix.${entry.key}'),
              value: asJsonMapOrNull(entry.value),
              onChanged: (updated) => _updateField(entry.key, updated),
            ),
          ),
        const SizedBox(height: 8),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton.icon(
            onPressed: () => _addField(context, l10n),
            icon: const Icon(Icons.add),
            label: Text(l10n.ruleAddField),
          ),
        ),
      ],
    );
  }
}

class _AddFieldDialog extends StatefulWidget {
  const _AddFieldDialog({required this.suggestions, required this.existing});

  final List<String> suggestions;
  final Set<String> existing;

  @override
  State<_AddFieldDialog> createState() => _AddFieldDialogState();
}

class _AddFieldDialogState extends State<_AddFieldDialog> {
  final TextEditingController _controller = TextEditingController();
  bool _duplicate = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _controller.text.trim();
    if (name.isEmpty) {
      return;
    }
    if (widget.existing.contains(name)) {
      setState(() => _duplicate = true);
      return;
    }
    Navigator.of(context).pop(name);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final available = widget.suggestions
        .where((name) => !widget.existing.contains(name))
        .toList(growable: false);
    return AlertDialog(
      title: Text(l10n.ruleAddFieldTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 12,
          children: <Widget>[
            TextField(
              controller: _controller,
              autofocus: true,
              autocorrect: false,
              enableSuggestions: false,
              decoration: InputDecoration(
                labelText: l10n.ruleFieldCustomName,
                hintText: l10n.ruleFieldCustomNameHint,
                errorText: _duplicate ? l10n.ruleFieldNameExists : null,
                border: const OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (_) {
                if (_duplicate) {
                  setState(() => _duplicate = false);
                }
              },
              onSubmitted: (_) => _submit(),
            ),
            if (available.isNotEmpty) ...<Widget>[
              Text(l10n.ruleFieldSuggestions, style: theme.textTheme.labelLarge),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  for (final name in available)
                    ActionChip(
                      label: Text(name),
                      onPressed: () => setState(() => _controller.text = name),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.ruleEditorCancel),
        ),
        FilledButton(onPressed: _submit, child: Text(l10n.ruleAddRow)),
      ],
    );
  }
}
