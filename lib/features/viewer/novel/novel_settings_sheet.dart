import 'dart:async';

import 'package:acgn_index/features/viewer/novel/novel_reader_settings.dart';
import 'package:acgn_index/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 小说阅读设置面板：字号、行距、背景。改动即时生效并持久化。
class NovelSettingsSheet extends ConsumerWidget {
  const NovelSettingsSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final settings = ref.watch(novelReaderSettingsProvider).value ?? const NovelReaderSettings();
    final notifier = ref.read(novelReaderSettingsProvider.notifier);

    void update(NovelReaderSettings next) => unawaited(notifier.save(next));

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(l10n.novelReaderSettings, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            _buildSlider(
              label: l10n.novelReaderFontSize,
              valueLabel: settings.fontSize.round().toString(),
              value: settings.fontSize,
              min: 14,
              max: 30,
              divisions: 16,
              onChanged: (value) => update(settings.copyWith(fontSize: value.roundToDouble())),
            ),
            _buildSlider(
              label: l10n.novelReaderLineHeight,
              valueLabel: settings.lineHeight.toStringAsFixed(1),
              value: settings.lineHeight,
              min: 1.2,
              max: 2.4,
              divisions: 12,
              onChanged: (value) => update(settings.copyWith(lineHeight: value)),
            ),
            const SizedBox(height: 8),
            Text(l10n.novelReaderBackground),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: <Widget>[
                for (final theme in NovelReaderTheme.values)
                  ChoiceChip(
                    label: Text(_themeLabel(l10n, theme)),
                    selected: settings.theme == theme,
                    onSelected: (selected) {
                      if (selected) {
                        update(settings.copyWith(theme: theme));
                      }
                    },
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSlider({
    required String label,
    required String valueLabel,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required ValueChanged<double> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Text(label),
              const Spacer(),
              Text(valueLabel),
            ],
          ),
          Slider(
            value: value,
            min: min,
            max: max,
            divisions: divisions,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  String _themeLabel(AppLocalizations l10n, NovelReaderTheme theme) => switch (theme) {
    NovelReaderTheme.paper => l10n.novelReaderThemePaper,
    NovelReaderTheme.sepia => l10n.novelReaderThemeSepia,
    NovelReaderTheme.night => l10n.novelReaderThemeNight,
  };
}
