import 'package:acgn_index/core/constants/app_constants.dart';
import 'package:acgn_index/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';

/// 设置：外观、关于与许可证。主题持久化在 M2 提供。
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.navSettings)),
      body: ListView(
        children: <Widget>[
          ListTile(
            leading: const Icon(Icons.brightness_auto_outlined),
            title: Text(l10n.settingsThemeMode),
            subtitle: Text(l10n.settingsThemeSystem),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: Text(l10n.settingsAbout),
            subtitle: Text(l10n.settingsVersion(AppConstants.appVersion)),
          ),
          ListTile(
            leading: const Icon(Icons.balance_outlined),
            title: Text(l10n.settingsLicense),
            subtitle: Text(l10n.settingsLicenseValue),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              l10n.settingsDisclaimer,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}
