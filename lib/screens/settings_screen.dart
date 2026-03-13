import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'about_screen.dart';
import 'premium_screen.dart';
import '../providers/settings_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/billing_provider.dart';
import '../constants.dart';

class SettingsScreen extends ConsumerWidget {
  static const routeName = '/settings';
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeProvider);
    final settings = ref.watch(settingsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          if (ref.watch(billingServiceProvider).isAvailable) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                'Premium',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.star_outline),
              title: const Text('Scyphomote Premium'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.of(context).pushNamed(PremiumScreen.routeName);
              },
            ),
            const Divider(),
          ],
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'Appearance',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.palette_outlined),
            title: const Text('Theme Mode'),
            subtitle: Text(_getThemeModeName(themeMode)),
            trailing: LayoutBuilder(
              builder: (context, constraints) {
                final showLabels = MediaQuery.of(context).size.width > 450;
                return SegmentedButton<ThemeMode>(
                  segments: [
                    ButtonSegment(
                      value: ThemeMode.system,
                      icon: const Icon(Icons.settings_brightness_rounded),
                      label: showLabels ? const Text('Auto') : null,
                    ),
                    ButtonSegment(
                      value: ThemeMode.light,
                      icon: const Icon(Icons.light_mode_rounded),
                      label: showLabels ? const Text('Light') : null,
                    ),
                    ButtonSegment(
                      value: ThemeMode.dark,
                      icon: const Icon(Icons.dark_mode_rounded),
                      label: showLabels ? const Text('Dark') : null,
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
          const Divider(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'Performance',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.speed),
            title: const Text('Player Refresh Rate'),
            subtitle: Text('${settings.playerRefreshRate} seconds'),
            trailing: SizedBox(
              width: 200,
              child: Slider(
                value: settings.playerRefreshRate.toDouble(),
                min: 3,
                max: 30,
                divisions: 27,
                label: '${settings.playerRefreshRate}s',
                onChanged: (value) {
                  ref
                      .read(settingsProvider.notifier)
                      .setPlayerRefreshRate(value.round());
                },
              ),
            ),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.sync),
            title: const Text('Device List Auto-Refresh'),
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
              title: const Text('List Refresh Rate'),
              subtitle: Text('${settings.deviceListRefreshRate} seconds'),
              trailing: SizedBox(
                width: 200,
                child: Slider(
                  value: settings.deviceListRefreshRate.toDouble(),
                  min: 5,
                  max: 60,
                  divisions: 11,
                  label: '${settings.deviceListRefreshRate}s',
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
              'Library',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.grid_view_rounded),
            title: const Text('Items per Row'),
            subtitle: Text('${settings.libraryItemsPerRow} items'),
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
          if (kDebugMode) ...[
            const Divider(),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                'Debug',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            SwitchListTile(
              secondary: const Icon(Icons.bug_report),
              title: const Text('Spoof Premium Status'),
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
              'About',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: Text('About ${AppConstants.appName}'),
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

  String _getThemeModeName(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.system:
        return 'Follow System';
      case ThemeMode.light:
        return 'Light Mode';
      case ThemeMode.dark:
        return 'Dark Mode';
    }
  }
}
