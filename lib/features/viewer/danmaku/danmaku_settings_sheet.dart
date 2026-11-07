import 'package:acgn_index/features/viewer/danmaku/danmaku_settings.dart';
import 'package:acgn_index/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';

/// 弹幕设置面板；关闭时把最终参数返回给播放器页面。
class DanmakuSettingsSheet extends StatefulWidget {
  const DanmakuSettingsSheet({required this.initial, super.key});

  final DanmakuSettings initial;

  @override
  State<DanmakuSettingsSheet> createState() => _DanmakuSettingsSheetState();
}

class _DanmakuSettingsSheetState extends State<DanmakuSettingsSheet> {
  late DanmakuSettings _settings = widget.initial;

  void _update(DanmakuSettings settings) => setState(() => _settings = settings);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(l10n.viewerDanmakuSettings, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            _buildSlider(
              label: l10n.viewerDanmakuOpacity,
              value: _settings.opacity,
              min: 0.2,
              max: 1,
              onChanged: (value) => _update(_settings.copyWith(opacity: value)),
            ),
            _buildSlider(
              label: l10n.viewerDanmakuFontScale,
              value: _settings.fontScale,
              min: 0.6,
              max: 1.6,
              onChanged: (value) => _update(_settings.copyWith(fontScale: value)),
            ),
            _buildSlider(
              label: l10n.viewerDanmakuArea,
              value: _settings.displayArea,
              min: 0.25,
              max: 1,
              onChanged: (value) => _update(_settings.copyWith(displayArea: value)),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.viewerDanmakuScroll),
              value: _settings.showScroll,
              onChanged: (value) => _update(_settings.copyWith(showScroll: value)),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.viewerDanmakuTop),
              value: _settings.showTop,
              onChanged: (value) => _update(_settings.copyWith(showTop: value)),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.viewerDanmakuBottom),
              value: _settings.showBottom,
              onChanged: (value) => _update(_settings.copyWith(showBottom: value)),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(_settings),
                child: Text(l10n.viewerDone),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSlider({
    required String label,
    required double value,
    required double min,
    required double max,
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
              Text('${(value * 100).round()}%'),
            ],
          ),
          Slider(value: value, min: min, max: max, onChanged: onChanged),
        ],
      ),
    );
  }
}
