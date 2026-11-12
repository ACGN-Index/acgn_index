import 'package:acgn_index/features/viewer/danmaku/danmaku_settings.dart';
import 'package:acgn_index/features/viewer/player_settings.dart';
import 'package:acgn_index/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 弹幕设置面板的返回值：最终参数 + 是否请求打开弹幕库面板。
class DanmakuSettingsResult {
  const DanmakuSettingsResult({required this.settings, this.openLibrary = false});

  final DanmakuSettings settings;
  final bool openLibrary;
}

/// 弹幕设置面板；弹幕库索引与播放器设置也从这里进入。
class DanmakuSettingsSheet extends ConsumerStatefulWidget {
  const DanmakuSettingsSheet({required this.initial, this.libraryLabel, super.key});

  final DanmakuSettings initial;

  /// 弹幕库当前匹配状态，展示在入口副标题。
  final String? libraryLabel;

  @override
  ConsumerState<DanmakuSettingsSheet> createState() => _DanmakuSettingsSheetState();
}

class _DanmakuSettingsSheetState extends ConsumerState<DanmakuSettingsSheet> {
  late DanmakuSettings _settings = widget.initial;

  void _update(DanmakuSettings settings) => setState(() => _settings = settings);

  void _close({bool openLibrary = false}) => Navigator.of(
    context,
  ).pop(DanmakuSettingsResult(settings: _settings, openLibrary: openLibrary));

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final playerSettings = ref.watch(playerSettingsProvider).value ?? const PlayerSettings();
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(l10n.viewerDanmakuSettings, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.cloud_download_outlined),
              title: Text(l10n.viewerDanmakuLibrary),
              subtitle: Text(widget.libraryLabel ?? l10n.viewerDanmakuLibraryIdle),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _close(openLibrary: true),
            ),
            const Divider(height: 1),
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
            const Divider(height: 24),
            Text(l10n.playerSettings, style: Theme.of(context).textTheme.titleSmall),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.playerSettingHover),
              subtitle: Text(l10n.playerSettingHoverHint),
              value: playerSettings.showControlsOnPointerMove,
              onChanged: (value) =>
                  ref.read(playerSettingsProvider.notifier).setShowControlsOnPointerMove(value),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(onPressed: _close, child: Text(l10n.viewerDone)),
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
