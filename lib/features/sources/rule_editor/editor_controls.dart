import 'package:acgn_index/features/sources/rule_editor/field_rule_editor_page.dart';
import 'package:acgn_index/features/sources/rule_editor/rule_draft.dart';
import 'package:acgn_index/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 可视化编辑器里的分组卡片。
class EditorSectionCard extends StatelessWidget {
  const EditorSectionCard({
    required this.title,
    required this.icon,
    required this.children,
    this.description,
    super.key,
  });

  final String title;
  final String? description;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: theme.colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(icon, size: 20, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            if (description != null) ...<Widget>[
              const SizedBox(height: 6),
              Text(
                description!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 16,
              children: children,
            ),
          ],
        ),
      ),
    );
  }
}

/// 受控文本输入：外部值变化时同步，聚焦期间不覆盖用户输入。
class EditorTextField extends StatefulWidget {
  const EditorTextField({
    required this.label,
    required this.value,
    required this.onChanged,
    this.hint,
    this.helper,
    this.maxLines = 1,
    this.numbersOnly = false,
    this.enabled = true,
    super.key,
  });

  final String label;
  final String value;
  final ValueChanged<String> onChanged;
  final String? hint;
  final String? helper;
  final int maxLines;
  final bool numbersOnly;
  final bool enabled;

  @override
  State<EditorTextField> createState() => _EditorTextFieldState();
}

class _EditorTextFieldState extends State<EditorTextField> {
  late final TextEditingController _controller = TextEditingController(text: widget.value);
  late final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_syncOnBlur);
  }

  @override
  void didUpdateWidget(covariant EditorTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncFromValue();
  }

  /// 数字输入被清空等情况下，失焦后回到模型里的值，避免显示与数据不一致。
  void _syncOnBlur() {
    if (!_focusNode.hasFocus) {
      _syncFromValue();
    }
  }

  void _syncFromValue() {
    if (!_focusNode.hasFocus && _controller.text != widget.value) {
      _controller.text = widget.value;
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_syncOnBlur);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(widget.label, style: theme.textTheme.labelLarge),
        const SizedBox(height: 8),
        TextField(
          controller: _controller,
          focusNode: _focusNode,
          enabled: widget.enabled,
          maxLines: widget.maxLines,
          minLines: widget.maxLines > 1 ? 2 : 1,
          keyboardType: widget.numbersOnly ? TextInputType.number : TextInputType.text,
          inputFormatters: widget.numbersOnly
              ? <TextInputFormatter>[FilteringTextInputFormatter.digitsOnly]
              : null,
          autocorrect: false,
          enableSuggestions: false,
          style: widget.maxLines > 1
              ? theme.textTheme.bodyMedium?.copyWith(fontFamily: 'monospace')
              : null,
          decoration: InputDecoration(
            hintText: widget.hint,
            helperText: widget.helper,
            helperMaxLines: 3,
            border: const OutlineInputBorder(),
            isDense: true,
          ),
          onChanged: widget.onChanged,
        ),
      ],
    );
  }
}

class EditorNumberField extends StatelessWidget {
  const EditorNumberField({
    required this.label,
    required this.value,
    required this.onChanged,
    this.helper,
    super.key,
  });

  final String label;
  final int value;
  final ValueChanged<int> onChanged;
  final String? helper;

  @override
  Widget build(BuildContext context) => EditorTextField(
    label: label,
    value: '$value',
    helper: helper,
    numbersOnly: true,
    onChanged: (text) {
      final parsed = int.tryParse(text);
      if (parsed != null) {
        onChanged(parsed);
      }
    },
  );
}

class EditorChoice<T> {
  const EditorChoice({required this.value, required this.label, this.icon});

  final T value;
  final String label;
  final IconData? icon;
}

/// 互斥选项，窄屏时自动换行。
class EditorChoiceField<T> extends StatelessWidget {
  const EditorChoiceField({
    required this.value,
    required this.choices,
    required this.onChanged,
    this.label,
    this.helper,
    super.key,
  });

  final String? label;
  final T value;
  final List<EditorChoice<T>> choices;
  final ValueChanged<T> onChanged;
  final String? helper;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (label != null) ...<Widget>[
          Text(label!, style: theme.textTheme.labelLarge),
          const SizedBox(height: 8),
        ],
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            for (final choice in choices)
              ChoiceChip(
                label: Text(choice.label),
                avatar: choice.icon == null ? null : Icon(choice.icon, size: 18),
                selected: choice.value == value,
                showCheckmark: false,
                onSelected: (_) => onChanged(choice.value),
              ),
          ],
        ),
        if (helper != null) ...<Widget>[
          const SizedBox(height: 6),
          Text(
            helper!,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}

class EditorSwitchField extends StatelessWidget {
  const EditorSwitchField({
    required this.label,
    required this.value,
    required this.onChanged,
    this.helper,
    super.key,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  final String? helper;

  @override
  Widget build(BuildContext context) => SwitchListTile(
    contentPadding: EdgeInsets.zero,
    value: value,
    onChanged: onChanged,
    title: Text(label),
    subtitle: helper == null ? null : Text(helper!),
  );
}

class _MapRow {
  _MapRow(String key, String value)
    : keyController = TextEditingController(text: key),
      valueController = TextEditingController(text: value);

  final TextEditingController keyController;
  final TextEditingController valueController;

  void dispose() {
    keyController.dispose();
    valueController.dispose();
  }
}

/// 键值对编辑（请求头等）。空键的行不会写入结果。
class EditorStringMapField extends StatefulWidget {
  const EditorStringMapField({
    required this.label,
    required this.value,
    required this.onChanged,
    required this.addLabel,
    required this.keyLabel,
    required this.valueLabel,
    this.helper,
    super.key,
  });

  final String label;
  final Map<String, String> value;
  final ValueChanged<Map<String, String>> onChanged;
  final String addLabel;
  final String keyLabel;
  final String valueLabel;
  final String? helper;

  @override
  State<EditorStringMapField> createState() => _EditorStringMapFieldState();
}

class _EditorStringMapFieldState extends State<EditorStringMapField> {
  late final List<_MapRow> _rows = <_MapRow>[
    for (final entry in widget.value.entries) _MapRow(entry.key, entry.value),
  ];

  /// 已从界面移除、等组件销毁时统一释放的行。
  final List<_MapRow> _retired = <_MapRow>[];

  @override
  void dispose() {
    for (final row in <_MapRow>[..._rows, ..._retired]) {
      row.dispose();
    }
    super.dispose();
  }

  void _emit() {
    final result = <String, String>{};
    for (final row in _rows) {
      final key = row.keyController.text.trim();
      if (key.isEmpty) {
        continue;
      }
      result[key] = row.valueController.text;
    }
    widget.onChanged(result);
  }

  void _addRow() {
    setState(() => _rows.add(_MapRow('', '')));
  }

  void _removeRow(_MapRow row) {
    setState(() => _rows.remove(row));
    _retired.add(row);
    _emit();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(widget.label, style: theme.textTheme.labelLarge),
        if (widget.helper != null) ...<Widget>[
          const SizedBox(height: 6),
          Text(
            widget.helper!,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
        if (_rows.isEmpty) const SizedBox(height: 8),
        for (final row in _rows)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              children: <Widget>[
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: row.keyController,
                    autocorrect: false,
                    enableSuggestions: false,
                    decoration: InputDecoration(
                      hintText: widget.keyLabel,
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                    onChanged: (_) => _emit(),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: row.valueController,
                    autocorrect: false,
                    enableSuggestions: false,
                    decoration: InputDecoration(
                      hintText: widget.valueLabel,
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                    onChanged: (_) => _emit(),
                  ),
                ),
                IconButton(
                  tooltip: MaterialLocalizations.of(context).deleteButtonTooltip,
                  onPressed: () => _removeRow(row),
                  icon: const Icon(Icons.remove_circle_outline),
                ),
              ],
            ),
          ),
        const SizedBox(height: 8),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton.icon(
            onPressed: _addRow,
            icon: const Icon(Icons.add),
            label: Text(widget.addLabel),
          ),
        ),
      ],
    );
  }
}

/// 字符串列表编辑（额外允许的主机等）。
class EditorStringListField extends StatefulWidget {
  const EditorStringListField({
    required this.label,
    required this.value,
    required this.onChanged,
    required this.addLabel,
    this.helper,
    super.key,
  });

  final String label;
  final List<String> value;
  final ValueChanged<List<String>> onChanged;
  final String addLabel;
  final String? helper;

  @override
  State<EditorStringListField> createState() => _EditorStringListFieldState();
}

class _EditorStringListFieldState extends State<EditorStringListField> {
  late final List<TextEditingController> _controllers = <TextEditingController>[
    for (final item in widget.value) TextEditingController(text: item),
  ];

  final List<TextEditingController> _retired = <TextEditingController>[];

  @override
  void dispose() {
    for (final controller in <TextEditingController>[..._controllers, ..._retired]) {
      controller.dispose();
    }
    super.dispose();
  }

  void _emit() {
    widget.onChanged(<String>[
      for (final controller in _controllers)
        if (controller.text.trim().isNotEmpty) controller.text.trim(),
    ]);
  }

  void _addRow() => setState(() => _controllers.add(TextEditingController()));

  void _removeRow(TextEditingController controller) {
    setState(() => _controllers.remove(controller));
    _retired.add(controller);
    _emit();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(widget.label, style: theme.textTheme.labelLarge),
        if (widget.helper != null) ...<Widget>[
          const SizedBox(height: 6),
          Text(
            widget.helper!,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
        for (final controller in _controllers)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: TextField(
                    controller: controller,
                    autocorrect: false,
                    enableSuggestions: false,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onChanged: (_) => _emit(),
                  ),
                ),
                IconButton(
                  tooltip: MaterialLocalizations.of(context).deleteButtonTooltip,
                  onPressed: () => _removeRow(controller),
                  icon: const Icon(Icons.remove_circle_outline),
                ),
              ],
            ),
          ),
        const SizedBox(height: 8),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton.icon(
            onPressed: _addRow,
            icon: const Icon(Icons.add),
            label: Text(widget.addLabel),
          ),
        ),
      ],
    );
  }
}

/// 字段规则的一句话摘要，用于列表展示。
String describeFieldRule(AppLocalizations l10n, Map<String, Object?>? rule) {
  if (rule == null || rule.isEmpty) {
    return l10n.fieldRuleSummaryEmpty;
  }
  if (rule.containsKey('items')) {
    final fields = asJsonMapOrNull(rule['fields']);
    return l10n.fieldRuleSummaryObjectList(fields?.length ?? 0);
  }
  final sourceLabels = <String, String>{
    'selector': l10n.fieldRuleSourceCss,
    'xpath': l10n.fieldRuleSourceXpath,
    'jsonPath': l10n.fieldRuleSourceJsonPath,
    'js': l10n.fieldRuleSourceJs,
    'const': l10n.fieldRuleSourceConst,
  };
  for (final entry in sourceLabels.entries) {
    if (!rule.containsKey(entry.key)) {
      continue;
    }
    final value = readString(rule, entry.key);
    return value.isEmpty ? entry.value : '${entry.value} · $value';
  }
  return l10n.fieldRuleSummaryEmpty;
}

/// 单条字段规则的编辑入口。
class EditorFieldRuleTile extends StatelessWidget {
  const EditorFieldRuleTile({
    required this.label,
    required this.value,
    required this.onChanged,
    this.helper,
    this.editorTitle,
    this.fieldKey,
    this.canRemove = true,
    super.key,
  });

  final String label;
  final Map<String, Object?>? value;
  final ValueChanged<Map<String, Object?>?> onChanged;
  final String? helper;

  /// 编辑页标题；缺省使用 [label]。
  final String? editorTitle;

  /// 用于测试与定位列表项。
  final Key? fieldKey;

  /// 是否允许清空该规则；对象数组的条目选择必须保留。
  final bool canRemove;

  Future<void> _edit(BuildContext context) async {
    final result = await pushFieldRuleEditor(
      context,
      title: editorTitle ?? label,
      rule: value ?? <String, Object?>{},
    );
    if (result != null) {
      onChanged(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return Material(
      key: fieldKey,
      color: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: ListTile(
        dense: true,
        title: Text(label),
        subtitle: Text(
          <String>[describeFieldRule(l10n, value), ?helper].join('\n'),
        ),
        isThreeLine: helper != null,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            IconButton(
              tooltip: l10n.ruleFieldEdit,
              onPressed: () => _edit(context),
              icon: const Icon(Icons.edit_outlined),
            ),
            if (value != null && canRemove)
              IconButton(
                tooltip: l10n.ruleFieldRemove,
                onPressed: () => onChanged(null),
                icon: const Icon(Icons.close),
              ),
          ],
        ),
      ),
    );
  }
}
