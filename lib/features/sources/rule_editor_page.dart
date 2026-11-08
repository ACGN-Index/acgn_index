import 'dart:convert';

import 'package:acgn_index/core/errors/app_exception.dart';
import 'package:acgn_index/core/logging/app_logger.dart';
import 'package:acgn_index/data/providers.dart';
import 'package:acgn_index/domain/entities/rule_source.dart';
import 'package:acgn_index/features/sources/delete_rule_dialog.dart';
import 'package:acgn_index/features/sources/rule_editor/rule_draft.dart';
import 'package:acgn_index/features/sources/rule_editor/visual_rule_editor.dart';
import 'package:acgn_index/l10n/generated/app_localizations.dart';
import 'package:acgn_index/rule_engine/rule_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 新建规则时预填的骨架，能直接通过校验。
const String kRuleEditorTemplate = r'''
{
  "schemaVersion": 1,
  "meta": {
    "id": "user.my.rule",
    "type": "comic",
    "name": "我的规则",
    "baseUrl": "https://example.invalid",
    "version": "1.0.0",
    "author": "",
    "lang": "zh"
  },
  "request": {
    "timeoutMs": 15000,
    "encoding": "utf-8"
  },
  "capabilities": {
    "search": {
      "url": "/search?q={{key}}&page={{page}}",
      "pageSize": 20,
      "list": {
        "selector": ".item"
      },
      "fields": {
        "id": {
          "selector": "a",
          "attr": "href",
          "regex": "(\\d+)$"
        },
        "title": {
          "selector": ".title"
        }
      }
    }
  }
}
''';

enum _EditorMode { visual, json }

/// 规则编辑器：可视化表单与 JSON 两种模式共享同一份文档，校验通过后写入本地库。
class RuleEditorPage extends ConsumerStatefulWidget {
  const RuleEditorPage({this.source, super.key});

  /// 为空时表示新建规则。
  final RuleSource? source;

  @override
  ConsumerState<RuleEditorPage> createState() => _RuleEditorPageState();
}

class _RuleEditorPageState extends ConsumerState<RuleEditorPage> {
  static const JsonEncoder _encoder = JsonEncoder.withIndent('  ');
  static const RulePackValidator _validator = RulePackValidator();

  late final TextEditingController _controller;
  late final String _initialText;
  List<RuleIssue> _issues = const <RuleIssue>[];
  RuleDraft? _draft;
  late final VoidCallback _draftListener = _syncDraft;
  _EditorMode _mode = _EditorMode.visual;
  bool _readOnly = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final source = widget.source;
    _readOnly = source?.readOnly ?? false;
    _initialText = source == null
        ? kRuleEditorTemplate
        : '${_encoder.convert(source.pack.toJson())}\n';
    _controller = TextEditingController(text: _initialText);
    _replaceDraft(_tryCreateDraft(_initialText));
    if (_draft == null) {
      _mode = _EditorMode.json;
    }
  }

  void _replaceDraft(RuleDraft? draft) {
    _draft?.removeListener(_draftListener);
    _draft = draft;
    _draft?.addListener(_draftListener);
  }

  RuleDraft? _tryCreateDraft(String text) {
    try {
      return RuleDraft.parse(text);
    } on FormatException {
      return null;
    }
  }

  @override
  void dispose() {
    _draft?.removeListener(_draftListener);
    _controller.dispose();
    super.dispose();
  }

  bool get _isDirty => !_readOnly && _controller.text != _initialText;

  bool get _canDelete => widget.source != null && !widget.source!.isBuiltin;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final title = widget.source == null ? l10n.ruleEditorNewTitle : l10n.ruleEditorEditTitle;

    return PopScope(
      canPop: !_isDirty,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) {
          return;
        }
        final shouldDiscard = await _confirmDiscard(l10n);
        if (shouldDiscard && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text('${l10n.ruleEditorTitle} · $title'),
          actions: <Widget>[
            if (_mode == _EditorMode.json)
              IconButton(
                onPressed: _readOnly ? null : _format,
                tooltip: l10n.ruleEditorFormat,
                icon: const Icon(Icons.format_align_left),
              ),
            IconButton(
              onPressed: _validate,
              tooltip: l10n.ruleEditorValidate,
              icon: const Icon(Icons.fact_check_outlined),
            ),
            if (_canDelete)
              IconButton(
                onPressed: _delete,
                tooltip: l10n.sourcesDelete,
                icon: const Icon(Icons.delete_outline),
              ),
          ],
        ),
        body: Column(
          children: <Widget>[
            if (_readOnly) _ReadOnlyBanner(l10n: l10n, onDuplicate: _duplicate),
            _modeSelector(l10n),
            Expanded(child: _buildEditor(l10n)),
            if (_issues.isNotEmpty) _IssueList(issues: _issues),
          ],
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: FilledButton.icon(
              onPressed: _readOnly || _saving ? null : _save,
              icon: const Icon(Icons.save_outlined),
              label: Text(l10n.ruleEditorSave),
            ),
          ),
        ),
      ),
    );
  }

  Widget _modeSelector(AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: SegmentedButton<_EditorMode>(
        segments: <ButtonSegment<_EditorMode>>[
          ButtonSegment<_EditorMode>(
            value: _EditorMode.visual,
            icon: const Icon(Icons.widgets_outlined),
            label: Text(l10n.ruleEditorModeVisual),
          ),
          ButtonSegment<_EditorMode>(
            value: _EditorMode.json,
            icon: const Icon(Icons.code),
            label: Text(l10n.ruleEditorModeJson),
          ),
        ],
        selected: <_EditorMode>{_mode},
        showSelectedIcon: false,
        onSelectionChanged: (selection) => _switchMode(selection.first),
      ),
    );
  }

  Widget _buildEditor(AppLocalizations l10n) {
    final draft = _draft;
    if (_mode == _EditorMode.visual && draft != null) {
      return VisualRuleEditor(key: ObjectKey(draft), draft: draft, readOnly: _readOnly);
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: TextField(
        controller: _controller,
        readOnly: _readOnly,
        expands: true,
        maxLines: null,
        textAlignVertical: TextAlignVertical.top,
        keyboardType: TextInputType.multiline,
        style: const TextStyle(fontFamily: 'monospace', fontSize: 13, height: 1.4),
        decoration: const InputDecoration(border: OutlineInputBorder()),
        onChanged: (_) => setState(() {
          _issues = const <RuleIssue>[];
        }),
      ),
    );
  }

  void _switchMode(_EditorMode mode) {
    if (mode == _mode) {
      return;
    }
    if (mode == _EditorMode.visual) {
      try {
        final draft = RuleDraft.parse(_controller.text);
        _replaceDraft(draft);
        setState(() => _mode = mode);
      } on FormatException catch (error) {
        final l10n = AppLocalizations.of(context);
        _showMessage(l10n.ruleEditorInvalidJson(error.message));
      }
      return;
    }
    setState(() => _mode = mode);
  }

  /// 可视化编辑后把草稿写回 JSON 文本，保证两种模式与保存使用的是同一份内容。
  void _syncDraft() {
    final draft = _draft;
    if (draft == null) {
      return;
    }
    final text = draft.toJsonText();
    if (_controller.text != text) {
      _controller.text = text;
    }
    if (_issues.isNotEmpty) {
      setState(() => _issues = const <RuleIssue>[]);
    }
  }

  Future<void> _delete() async {
    final source = widget.source;
    if (source == null) {
      return;
    }
    final l10n = AppLocalizations.of(context);
    final confirmed = await confirmDeleteRule(context, name: source.name);
    if (!confirmed || !mounted) {
      return;
    }
    try {
      await ref.read(ruleSourceRepositoryProvider).delete(source.id);
      if (!mounted) {
        return;
      }
      _showMessage(l10n.sourcesDeleted(source.name));
      Navigator.of(context).pop();
    } on Object catch (error, stackTrace) {
      AppLogger.of('rule-editor').severe('删除规则失败', error, stackTrace);
      if (mounted) {
        _showMessage(l10n.sourcesDeleteFailed);
      }
    }
  }

  void _format() {
    final l10n = AppLocalizations.of(context);
    try {
      final decoded = jsonDecode(_controller.text);
      _controller.text = '${_encoder.convert(decoded)}\n';
      setState(() => _issues = const <RuleIssue>[]);
    } on FormatException catch (error) {
      _showMessage(l10n.ruleEditorInvalidJson(error.message));
    }
  }

  void _validate() {
    final l10n = AppLocalizations.of(context);
    final validation = _runValidation(l10n);
    if (validation == null) {
      return;
    }
    setState(() => _issues = validation.issues);
    if (validation.isValid) {
      _showMessage(l10n.ruleEditorValid);
    }
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    final validation = _runValidation(l10n);
    if (validation == null) {
      return;
    }
    setState(() => _issues = validation.issues);
    if (!validation.isValid) {
      _showMessage(l10n.ruleEditorSaveFailed);
      return;
    }

    final RulePack pack;
    try {
      pack = RulePack.fromJson(
        _decodeObject(_controller.text) ?? const <String, Object?>{},
      );
    } on AppException catch (error) {
      _showMessage(error.message);
      return;
    }

    final conflict = await _hasBuiltinConflict(pack.id);
    if (conflict) {
      _showMessage(l10n.ruleEditorIdConflict);
      return;
    }

    setState(() => _saving = true);
    try {
      await ref
          .read(ruleSourceRepositoryProvider)
          .save(
            RuleSource(
              pack: pack,
              enabled: widget.source?.enabled ?? true,
              installedAt: widget.source?.installedAt ?? DateTime.now(),
            ),
          );
      if (!mounted) {
        return;
      }
      _showMessage(l10n.ruleEditorSaved(pack.meta.name));
      Navigator.of(context).pop();
    } on Object catch (error, stackTrace) {
      AppLogger.of('rule-editor').severe('保存规则失败', error, stackTrace);
      if (mounted) {
        _showMessage(l10n.ruleEditorSaveFailed);
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<bool> _hasBuiltinConflict(String id) async {
    final sources = await ref.read(ruleSourceRepositoryProvider).getAll();
    return sources.any((source) => source.id == id && source.isBuiltin);
  }

  ValidationResult? _runValidation(AppLocalizations l10n) {
    final Object? decoded;
    try {
      decoded = jsonDecode(_controller.text);
    } on FormatException catch (error) {
      _showMessage(l10n.ruleEditorInvalidJson(error.message));
      return null;
    }
    if (decoded is! Map) {
      _showMessage(l10n.ruleEditorInvalidJson('顶层必须是 JSON 对象'));
      return null;
    }
    return _validator.validate(
      decoded.map((Object? key, Object? value) => MapEntry(key.toString(), value)),
    );
  }

  Map<String, Object?>? _decodeObject(String text) {
    final decoded = jsonDecode(text);
    if (decoded is! Map) {
      return null;
    }
    return decoded.map((Object? key, Object? value) => MapEntry(key.toString(), value));
  }

  /// 把只读的内置规则复制成一份可编辑的已导入规则。
  void _duplicate() {
    final l10n = AppLocalizations.of(context);
    final source = widget.source;
    if (source == null) {
      return;
    }
    final json = source.pack.toJson();
    final meta = <String, Object?>{
      ...(json['meta']! as Map<String, Object?>),
      'id': '${source.id}.${l10n.ruleEditorCopySuffix}',
      'name': '${source.name}（${l10n.ruleEditorCopySuffix}）',
      'notice': '',
    };
    json['meta'] = meta;
    final text = '${_encoder.convert(json)}\n';
    _controller.text = text;
    _replaceDraft(_tryCreateDraft(text));
    setState(() {
      _readOnly = false;
      _issues = const <RuleIssue>[];
      if (_draft == null) {
        _mode = _EditorMode.json;
      }
    });
  }

  Future<bool> _confirmDiscard(AppLocalizations l10n) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.ruleEditorDiscardTitle),
        content: Text(l10n.ruleEditorDiscardBody),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.ruleEditorCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.ruleEditorDiscardConfirm),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class _ReadOnlyBanner extends StatelessWidget {
  const _ReadOnlyBanner({required this.l10n, required this.onDuplicate});

  final AppLocalizations l10n;
  final VoidCallback onDuplicate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
        child: Row(
          children: <Widget>[
            Icon(Icons.lock_outline, size: 18, color: theme.colorScheme.outline),
            const SizedBox(width: 8),
            Expanded(child: Text(l10n.ruleEditorReadOnly, style: theme.textTheme.bodySmall)),
            TextButton(onPressed: onDuplicate, child: Text(l10n.ruleEditorDuplicate)),
          ],
        ),
      ),
    );
  }
}

class _IssueList extends StatelessWidget {
  const _IssueList({required this.issues});

  final List<RuleIssue> issues;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 168),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: theme.dividerColor)),
        ),
        child: ListView.builder(
          shrinkWrap: true,
          padding: const EdgeInsets.symmetric(vertical: 4),
          itemCount: issues.length,
          itemBuilder: (context, index) {
            final issue = issues[index];
            final isError = issue.severity == RuleIssueSeverity.error;
            final color = isError ? theme.colorScheme.error : theme.colorScheme.tertiary;
            return ListTile(
              dense: true,
              visualDensity: VisualDensity.compact,
              leading: Icon(
                isError ? Icons.error_outline : Icons.warning_amber_outlined,
                size: 18,
                color: color,
              ),
              title: Text(issue.message, style: theme.textTheme.bodySmall),
              subtitle: Text(
                issue.path.isEmpty ? '-' : issue.path,
                style: theme.textTheme.labelSmall?.copyWith(color: color),
              ),
            );
          },
        ),
      ),
    );
  }
}
