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
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              AppLocalizations.of(context)!.premiumSection,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.star_outline),
            title: Text(AppLocalizations.of(context)!.premiumSubtitle),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.of(context).pushNamed(PremiumScreen.routeName);
            },
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              AppLocalizations.of(context)!.appearanceSection,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.palette_outlined),
            title: Text(AppLocalizations.of(context)!.themeModeTitle),
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
                          ? Text(AppLocalizations.of(context)!.themeAuto)
                          : null,
                    ),
                    ButtonSegment(
                      value: ThemeMode.light,
                      icon: const Icon(Icons.light_mode_rounded),
                      label: showLabels
                          ? Text(AppLocalizations.of(context)!.themeLight)
                          : null,
                    ),
                    ButtonSegment(
                      value: ThemeMode.dark,
                      icon: const Icon(Icons.dark_mode_rounded),
                      label: showLabels
                          ? Text(AppLocalizations.of(context)!.themeDark)
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
            title: Text(AppLocalizations.of(context)!.languageTitle),
            trailing: DropdownMenu<String?>(
              key: ValueKey(currentLocale?.languageCode),
              initialSelection: currentLocale?.languageCode,
              requestFocusOnTap: false,
              dropdownMenuEntries: [
                DropdownMenuEntry<String?>(
                  value: null,
                  label: AppLocalizations.of(context)!.languageSystem,
                ),
                const DropdownMenuEntry<String?>(value: 'en', label: 'English'),
                const DropdownMenuEntry<String?>(
                  value: 'fr',
                  label: 'Français',
                ),
                const DropdownMenuEntry<String?>(value: 'es', label: 'Español'),
                const DropdownMenuEntry<String?>(value: 'de', label: 'Deutsch'),
                const DropdownMenuEntry<String?>(
                  value: 'pt',
                  label: 'Português',
                ),
                const DropdownMenuEntry<String?>(value: 'ja', label: '日本語'),
              ],
              onSelected: (value) {
                ref
                    .read(localeProvider.notifier)
                    .setLocale(value != null ? Locale(value) : null);
              },
            ),
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              AppLocalizations.of(context)!.performanceSection,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.speed_rounded),
            title: Text(AppLocalizations.of(context)!.playerRefreshRateTitle),
            subtitle: Text(
              AppLocalizations.of(
                context,
              )!.secondsPlural(settings.playerRefreshRate),
            ),
            trailing: SizedBox(
              width: 200,
              child: Slider(
                value: settings.playerRefreshRate.toDouble(),
                min: 3,
                max: 30,
                divisions: 27,
                label: AppLocalizations.of(
                  context,
                )!.secondsShort(settings.playerRefreshRate),
                onChanged: (value) {
                  ref
                      .read(settingsProvider.notifier)
                      .setPlayerRefreshRate(value.round());
                },
              ),
            ),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.sync_rounded),
            title: Text(
              AppLocalizations.of(context)!.deviceListAutoRefreshTitle,
            ),
            value: settings.deviceListAutoRefresh,
            onChanged: (value) {
              ref
                  .read(settingsProvider.notifier)
                  .setDeviceListAutoRefresh(value);
            },
          ),
          if (settings.deviceListAutoRefresh)
            ListTile(
              leading: const Icon(Icons.timer_outlined),
              title: Text(AppLocalizations.of(context)!.listRefreshRateTitle),
              subtitle: Text(
                AppLocalizations.of(
                  context,
                )!.secondsPlural(settings.deviceListRefreshRate),
              ),
              trailing: SizedBox(
                width: 200,
                child: Slider(
                  value: settings.deviceListRefreshRate.toDouble(),
                  min: 5,
                  max: 60,
                  divisions: 11,
                  label: AppLocalizations.of(
                    context,
                  )!.secondsShort(settings.deviceListRefreshRate),
                  onChanged: (value) {
                    ref
                        .read(settingsProvider.notifier)
                        .setDeviceListRefreshRate(value.round());
                  },
                ),
              ),
            ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              AppLocalizations.of(context)!.librarySection,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.grid_view_rounded),
            title: Text(AppLocalizations.of(context)!.itemsPerRowTitle),
            subtitle: Text(
              AppLocalizations.of(
                context,
              )!.itemsPlural(settings.libraryItemsPerRow),
            ),
            trailing: SizedBox(
              width: 200,
              child: Slider(
                value: settings.libraryItemsPerRow.toDouble(),
                min: 1,
                max: 6,
                divisions: 5,
                label: '${settings.libraryItemsPerRow}',
                onChanged: (value) {
                  ref
                      .read(settingsProvider.notifier)
                      .setLibraryItemsPerRow(value.round());
                },
              ),
            ),
          ),
          if (ref.watch(authProvider).currentUser?.isAdmin ?? false) ...[
            const Divider(),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                AppLocalizations.of(context)!.adminSection,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            SwitchListTile(
              secondary: const Icon(Icons.visibility_off_outlined),
              title: Text(
                AppLocalizations.of(context)!.hideOtherUsersSessionsTitle,
              ),
              value: settings.hideOtherUsersSessions,
              onChanged: (value) {
                ref
                    .read(settingsProvider.notifier)
                    .setHideOtherUsersSessions(value);
              },
            ),
          ],
          if (kDebugMode) ...[
            const Divider(),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                AppLocalizations.of(context)!.debugSection,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            SwitchListTile(
              secondary: const Icon(Icons.bug_report),
              title: Text(
                AppLocalizations.of(context)!.spoofPremiumStatusTitle,
              ),
              value: ref.watch(isPremiumProvider),
              onChanged: (value) {
                ref.read(isPremiumProvider.notifier).setPremium(value);
              },
            ),
          ],
          const Divider(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              AppLocalizations.of(context)!.aboutSection,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: Text(
              AppLocalizations.of(context)!.aboutAppTitle(AppConstants.appName),
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

  String _getThemeModeName(BuildContext context, ThemeMode mode) {
    switch (mode) {
      case ThemeMode.system:
        return AppLocalizations.of(context)!.themeFollowSystemName;
      case ThemeMode.light:
        return AppLocalizations.of(context)!.themeLightModeName;
      case ThemeMode.dark:
        return AppLocalizations.of(context)!.themeDarkModeName;
    }
  }
}
