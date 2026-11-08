import 'package:acgn_index/features/sources/rule_editor/editor_controls.dart';
import 'package:acgn_index/features/sources/rule_editor/field_rule_fields_editor.dart';
import 'package:acgn_index/features/sources/rule_editor/rule_draft.dart';
import 'package:acgn_index/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';

/// 打开字段规则编辑页；用户取消时返回 null。
Future<Map<String, Object?>?> pushFieldRuleEditor(
  BuildContext context, {
  required String title,
  required Map<String, Object?> rule,
}) {
  return Navigator.of(context, rootNavigator: true).push<Map<String, Object?>>(
    MaterialPageRoute<Map<String, Object?>>(
      fullscreenDialog: true,
      builder: (context) => FieldRuleEditorPage(title: title, rule: rule),
    ),
  );
}

enum _FieldSourceKind {
  css('selector'),
  xpath('xpath'),
  jsonPath('jsonPath'),
  javaScript('js'),
  constant('const'),
  items('items');

  const _FieldSourceKind(this.jsonKey);

  final String jsonKey;
}

class FieldRuleEditorPage extends StatefulWidget {
  const FieldRuleEditorPage({required this.title, required this.rule, super.key});

  final String title;
  final Map<String, Object?> rule;

  @override
  State<FieldRuleEditorPage> createState() => _FieldRuleEditorPageState();
}

class _FieldRuleEditorPageState extends State<FieldRuleEditorPage> {
  late final Map<String, Object?> _rule = deepCopyJsonMap(widget.rule);
  late _FieldSourceKind _source = _detectSource(_rule);

  static _FieldSourceKind _detectSource(Map<String, Object?> rule) {
    if (rule.containsKey('items')) {
      return _FieldSourceKind.items;
    }
    for (final kind in _FieldSourceKind.values) {
      if (kind != _FieldSourceKind.items && rule.containsKey(kind.jsonKey)) {
        return kind;
      }
    }
    return _FieldSourceKind.css;
  }

  String get _sourceValue => readString(_rule, _source.jsonKey);

  void _set(void Function(Map<String, Object?> rule) action) {
    setState(() => action(_rule));
  }

  void _changeSource(_FieldSourceKind next) {
    if (next == _source) {
      return;
    }
    final text = _sourceValue;
    _set((rule) {
      for (final kind in _FieldSourceKind.values) {
        if (kind != _FieldSourceKind.items) {
          rule.remove(kind.jsonKey);
        }
      }
      if (next == _FieldSourceKind.items) {
        rule['items'] = <String, Object?>{'selector': ''};
      } else {
        rule.remove('items');
        rule.remove('fields');
        rule[next.jsonKey] = text;
      }
      _source = next;
    });
  }

  String _sourceLabel(AppLocalizations l10n) => switch (_source) {
    _FieldSourceKind.css => l10n.fieldRuleValueCss,
    _FieldSourceKind.xpath => l10n.fieldRuleValueXpath,
    _FieldSourceKind.jsonPath => l10n.fieldRuleValueJsonPath,
    _FieldSourceKind.javaScript => l10n.fieldRuleValueJs,
    _FieldSourceKind.constant => l10n.fieldRuleValueConst,
    _FieldSourceKind.items => l10n.fieldRuleItemsSource,
  };

  String? get _sourceHint => switch (_source) {
    _FieldSourceKind.css => '.item a',
    _FieldSourceKind.xpath => '//div[@class="title"]',
    _FieldSourceKind.jsonPath => r'$.data.title',
    _FieldSourceKind.javaScript => 'value => value.trim()',
    _FieldSourceKind.constant => 'https://example.invalid',
    _FieldSourceKind.items => null,
  };

  String _sourceHelp(AppLocalizations l10n) =>
      _source == _FieldSourceKind.items ? l10n.fieldRuleItemsHelp : l10n.fieldRuleSourceHelp;

  void _done() => Navigator.of(context).pop(pruneFieldRule(_rule));

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 880),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 16,
              children: <Widget>[
                _sourceCard(l10n),
                if (_source != _FieldSourceKind.items) _optionsCard(l10n),
                if (_source != _FieldSourceKind.items) _fallbackCard(l10n),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Row(
            children: <Widget>[
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(l10n.ruleEditorCancel),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _done,
                  icon: const Icon(Icons.check),
                  label: Text(l10n.fieldRuleDone),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sourceCard(AppLocalizations l10n) {
    return EditorSectionCard(
      title: l10n.fieldRuleSource,
      description: _sourceHelp(l10n),
      icon: Icons.filter_alt_outlined,
      children: <Widget>[
        EditorChoiceField<_FieldSourceKind>(
          value: _source,
          choices: <EditorChoice<_FieldSourceKind>>[
            EditorChoice(value: _FieldSourceKind.css, label: l10n.fieldRuleSourceCss),
            EditorChoice(value: _FieldSourceKind.xpath, label: l10n.fieldRuleSourceXpath),
            EditorChoice(
              value: _FieldSourceKind.jsonPath,
              label: l10n.fieldRuleSourceJsonPath,
            ),
            EditorChoice(
              value: _FieldSourceKind.javaScript,
              label: l10n.fieldRuleSourceJs,
            ),
            EditorChoice(value: _FieldSourceKind.constant, label: l10n.fieldRuleSourceConst),
            EditorChoice(value: _FieldSourceKind.items, label: l10n.fieldRuleSourceItems),
          ],
          onChanged: _changeSource,
        ),
        if (_source == _FieldSourceKind.items) ...<Widget>[
          EditorFieldRuleTile(
            label: l10n.fieldRuleItemsSource,
            value: asJsonMapOrNull(_rule['items']),
            canRemove: false,
            fieldKey: const ValueKey<String>('fieldRule.items'),
            onChanged: (updated) => _set((rule) {
              rule['items'] = updated ?? <String, Object?>{'selector': ''};
            }),
          ),
          EditorFieldRuleMapField(
            label: l10n.ruleFieldFields,
            keyPrefix: 'items',
            value: asJsonMapOrNull(_rule['fields']) ?? const <String, Object?>{},
            onChanged: (fields) => _set((rule) {
              if (fields.isEmpty) {
                rule.remove('fields');
              } else {
                rule['fields'] = fields;
              }
            }),
          ),
        ] else
          EditorTextField(
            key: const ValueKey<String>('fieldRule.value'),
            label: _sourceLabel(l10n),
            value: _sourceValue,
            hint: _sourceHint,
            maxLines: _source == _FieldSourceKind.javaScript ? 3 : 1,
            onChanged: (text) => _set((rule) => rule[_source.jsonKey] = text),
          ),
      ],
    );
  }

  Widget _optionsCard(AppLocalizations l10n) {
    return EditorSectionCard(
      title: l10n.fieldRuleOptions,
      icon: Icons.tune,
      children: <Widget>[
        EditorTextField(
          label: l10n.fieldRuleAttr,
          value: readString(_rule, 'attr'),
          hint: l10n.fieldRuleAttrHint,
          onChanged: (text) => _set((rule) => writeString(rule, 'attr', text)),
        ),
        EditorSwitchField(
          label: l10n.fieldRuleHtml,
          helper: l10n.fieldRuleHtmlHelp,
          value: readBool(_rule, 'html'),
          onChanged: (value) => _set((rule) => writeBool(rule, 'html', value)),
        ),
        EditorSwitchField(
          label: l10n.fieldRuleHtmlToText,
          value: readBool(_rule, 'htmlToText'),
          onChanged: (value) => _set((rule) => writeBool(rule, 'htmlToText', value)),
        ),
        EditorTextField(
          label: l10n.fieldRuleRegex,
          value: readString(_rule, 'regex'),
          onChanged: (text) => _set((rule) => writeString(rule, 'regex', text)),
        ),
        if (readString(_rule, 'regex').isNotEmpty)
          EditorNumberField(
            label: l10n.fieldRuleRegexGroup,
            value: readInt(_rule, 'group', 1),
            onChanged: (value) => _set((rule) => writeInt(rule, 'group', value, defaultValue: 1)),
          ),
        EditorSwitchField(
          label: l10n.fieldRuleMultiple,
          helper: l10n.fieldRuleMultipleHelp,
          value: readBool(_rule, 'multiple'),
          onChanged: (value) => _set((rule) => writeBool(rule, 'multiple', value)),
        ),
        EditorTextField(
          label: l10n.fieldRuleTemplate,
          value: readString(_rule, 'template'),
          hint: l10n.fieldRuleTemplateHint,
          onChanged: (text) => _set((rule) => writeString(rule, 'template', text)),
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              child: EditorTextField(
                label: l10n.fieldRulePrefix,
                value: readString(_rule, 'prefix'),
                onChanged: (text) => _set((rule) => writeString(rule, 'prefix', text)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: EditorTextField(
                label: l10n.fieldRuleSuffix,
                value: readString(_rule, 'suffix'),
                onChanged: (text) => _set((rule) => writeString(rule, 'suffix', text)),
              ),
            ),
          ],
        ),
        EditorSwitchField(
          label: l10n.fieldRuleAbsolute,
          value: readBool(_rule, 'absolute'),
          onChanged: (value) => _set((rule) => writeBool(rule, 'absolute', value)),
        ),
        EditorTextField(
          label: l10n.fieldRuleDefault,
          helper: l10n.fieldRuleDefaultHelp,
          value: readString(_rule, 'default'),
          onChanged: (text) => _set((rule) => rule['default'] = text),
        ),
      ],
    );
  }

  Widget _fallbackCard(AppLocalizations l10n) {
    final fallback = asJsonMapOrNull(_rule['fallback']);
    return EditorSectionCard(
      title: l10n.fieldRuleFallback,
      description: l10n.fieldRuleFallbackHelp,
      icon: Icons.alt_route,
      children: <Widget>[
        EditorFieldRuleTile(
          label: fallback == null ? l10n.fieldRuleFallbackAdd : l10n.fieldRuleFallback,
          value: fallback,
          fieldKey: const ValueKey<String>('fieldRule.fallback'),
          onChanged: (updated) => _set((rule) {
            if (updated == null) {
              rule.remove('fallback');
            } else {
              rule['fallback'] = updated;
            }
          }),
        ),
      ],
    );
  }
}
