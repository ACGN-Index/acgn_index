import 'package:acgn_index/features/viewer/player_settings.dart';
import 'package:acgn_index/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 播放器设置面板；「我的」页与播放器控制栏共用。
class PlayerSettingsSheet extends ConsumerWidget {
  const PlayerSettingsSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final settings = ref.watch(playerSettingsProvider).value ?? const PlayerSettings();
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(l10n.playerSettings, style: Theme.of(context).textTheme.titleMedium),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.playerSettingHover),
              subtitle: Text(l10n.playerSettingHoverHint),
              value: settings.showControlsOnPointerMove,
              onChanged: (value) =>
                  ref.read(playerSettingsProvider.notifier).setShowControlsOnPointerMove(value),
            ),
          ],
        ),
      ),
    );
  }
}
