import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'about_screen.dart';
import 'premium_screen.dart';
import '../providers/settings_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/billing_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/locale_provider.dart';
import 'package:scyphomote/l10n/app_localizations.dart';
import '../constants.dart';

class SettingsScreen extends ConsumerWidget {
  static const routeName = '/settings';
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeProvider);
    final settings = ref.watch(settingsProvider);
    final currentLocale = ref.watch(localeProvider);
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsTitle)),
      body: ListView(
        children: [
          _buildSectionHeader(context, l10n.premiumSection),
          ListTile(
            leading: const Icon(Icons.star_outline),
            title: Text(l10n.premiumSubtitle),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.of(context).pushNamed(PremiumScreen.routeName);
            },
          ),
          const Divider(),
          _buildSectionHeader(context, l10n.appearanceSection),
          ListTile(
            leading: const Icon(Icons.palette_outlined),
            title: Text(l10n.themeModeTitle),
            subtitle: Text(_getThemeModeName(context, themeMode)),
            trailing: LayoutBuilder(
              builder: (context, constraints) {
                final showLabels = MediaQuery.of(context).size.width > 450;
                return SegmentedButton<ThemeMode>(
                  segments: [
                    ButtonSegment(
                      value: ThemeMode.system,
                      icon: const Icon(Icons.settings_brightness_rounded),
                      label: showLabels
                          ? Text(l10n.themeAuto)
                          : null,
                    ),
                    ButtonSegment(
                      value: ThemeMode.light,
                      icon: const Icon(Icons.light_mode_rounded),
                      label: showLabels
                          ? Text(l10n.themeLight)
                          : null,
                    ),
                    ButtonSegment(
                      value: ThemeMode.dark,
                      icon: const Icon(Icons.dark_mode_rounded),
                      label: showLabels
                          ? Text(l10n.themeDark)
                          : null,
                    ),
                  ],
                  selected: {themeMode},
                  onSelectionChanged: (Set<ThemeMode> newSelection) {
                    ref
                        .read(themeProvider.notifier)
                        .setThemeMode(newSelection.first);
                  },
                  showSelectedIcon: false,
                );
              },
            ),
          ),
          ListTile(
            leading: const Icon(Icons.language_rounded),
            title: Text(l10n.languageTitle),
            trailing: DropdownMenu<String?>(
              key: ValueKey(currentLocale?.languageCode),
              initialSelection: currentLocale?.languageCode,
              requestFocusOnTap: false,
              dropdownMenuEntries: [
                DropdownMenuEntry<String?>(
                  value: null,
                  label: l10n.languageSystem,
                ),
                ...{
                  'en': 'English',
                  'fr': 'Français',
                  'es': 'Español',
                  'de': 'Deutsch',
                  'pt': 'Português',
                  'ja': '日本語',
                  'zh': '简体中文',
                }.entries.map(
                      (e) => DropdownMenuEntry<String?>(
                        value: e.key,
                        label: e.value,
                      ),
                    ),
              ],
              onSelected: (value) {
                ref
                    .read(localeProvider.notifier)
                    .setLocale(value != null ? Locale(value) : null);
              },
            ),
          ),
          const Divider(),
          _buildSectionHeader(context, l10n.performanceSection),
          _buildSliderTile(
            icon: Icons.speed_rounded,
            title: l10n.playerRefreshRateTitle,
            subtitle: l10n.secondsPlural(settings.playerRefreshRate),
            label: l10n.secondsShort(settings.playerRefreshRate),
            value: settings.playerRefreshRate,
            min: 3,
            max: 30,
            divisions: 27,
            onChanged: (val) => ref.read(settingsProvider.notifier).setPlayerRefreshRate(val),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.sync_rounded),
            title: Text(
              l10n.deviceListAutoRefreshTitle,
            ),
            value: settings.deviceListAutoRefresh,
            onChanged: (value) {
              ref
                  .read(settingsProvider.notifier)
                  .setDeviceListAutoRefresh(value);
            },
          ),
          if (settings.deviceListAutoRefresh)
            _buildSliderTile(
              icon: Icons.timer_outlined,
              title: l10n.listRefreshRateTitle,
              subtitle: l10n.secondsPlural(settings.deviceListRefreshRate),
              label: l10n.secondsShort(settings.deviceListRefreshRate),
              value: settings.deviceListRefreshRate,
              min: 5,
              max: 60,
              divisions: 11,
              onChanged: (val) => ref.read(settingsProvider.notifier).setDeviceListRefreshRate(val),
            ),
          const Divider(),
          _buildSliderTile(
            icon: Icons.timer_rounded,
            title: 'Connection Timeout',
            subtitle: l10n.secondsPlural(settings.connectionTimeout),
            label: l10n.secondsShort(settings.connectionTimeout),
            value: settings.connectionTimeout,
            min: 5,
            max: 60,
            divisions: 11,
            onChanged: (val) => ref.read(settingsProvider.notifier).setConnectionTimeout(val),
          ),
          const Divider(),
          _buildSectionHeader(context, l10n.librarySection),
          _buildSliderTile(
            icon: Icons.grid_view_rounded,
            title: l10n.itemsPerRowTitle,
            subtitle: l10n.itemsPlural(settings.libraryItemsPerRow),
            label: '${settings.libraryItemsPerRow}',
            value: settings.libraryItemsPerRow,
            min: 1,
            max: 6,
            divisions: 5,
            onChanged: (val) => ref.read(settingsProvider.notifier).setLibraryItemsPerRow(val),
          ),
          if (ref.watch(authProvider).currentUser?.isAdmin ?? false) ...[
            const Divider(),
            _buildSectionHeader(context, l10n.adminSection),
            SwitchListTile(
              secondary: const Icon(Icons.visibility_off_outlined),
              title: Text(
                l10n.hideOtherUsersSessionsTitle,
              ),
              value: settings.hideOtherUsersSessions,
              onChanged: (value) {
                ref
                    .read(settingsProvider.notifier)
                    .setHideOtherUsersSessions(value);
              },
            ),
            SwitchListTile(
              secondary: const Icon(Icons.devices_other_rounded),
              title: Text(
                l10n.showNonMediaCapableSessionsTitle,
              ),
              value: settings.showNonMediaCapableSessions,
              onChanged: (value) {
                ref
                    .read(settingsProvider.notifier)
                    .setShowNonMediaCapableSessions(value);
              },
            ),
          ],
          if (kDebugMode) ...[
            const Divider(),
            _buildSectionHeader(context, l10n.debugSection),
            SwitchListTile(
              secondary: const Icon(Icons.bug_report),
              title: Text(
                l10n.spoofPremiumStatusTitle,
              ),
              value: ref.watch(isPremiumProvider),
              onChanged: (value) {
                ref.read(isPremiumProvider.notifier).setPremium(value);
              },
            ),
          ],
          const Divider(),
          _buildSectionHeader(context, l10n.aboutSection),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: Text(
              l10n.aboutAppTitle(AppConstants.appName),
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.of(context).pushNamed(AboutScreen.routeName);
            },
          ),
          const Divider(),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildSliderTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required String label,
    required int value,
    required double min,
    required double max,
    required int divisions,
    required ValueChanged<int> onChanged,
  }) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: SizedBox(
        width: 200,
        child: Slider(
          value: value.toDouble(),
          min: min,
          max: max,
          divisions: divisions,
          label: label,
          onChanged: (val) => onChanged(val.round()),
        ),
      ),
    );
  }

  String _getThemeModeName(BuildContext context, ThemeMode mode) => switch (mode) {
        ThemeMode.system => AppLocalizations.of(context)!.themeFollowSystemName,
        ThemeMode.light => AppLocalizations.of(context)!.themeLightModeName,
        ThemeMode.dark => AppLocalizations.of(context)!.themeDarkModeName,
      };
}
