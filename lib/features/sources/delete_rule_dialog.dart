import 'package:acgn_index/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';

/// 删除规则前的确认弹窗；返回 true 表示用户确认删除。
Future<bool> confirmDeleteRule(BuildContext context, {required String name}) async {
  final l10n = AppLocalizations.of(context);
  final colors = Theme.of(context).colorScheme;
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(l10n.sourcesDeleteTitle),
      content: Text(l10n.sourcesDeleteBody(name)),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l10n.ruleEditorCancel),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: colors.error,
            foregroundColor: colors.onError,
          ),
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(l10n.sourcesDeleteConfirm),
        ),
      ],
    ),
  );
  return result ?? false;
}
