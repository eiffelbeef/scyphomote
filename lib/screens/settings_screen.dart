import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'about_screen.dart';
import 'crash_log_screen.dart';
import 'premium_screen.dart';
import '../providers/settings_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/billing_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/locale_provider.dart';
import 'package:scyphomote/l10n/app_localizations.dart';
import '../constants.dart';
import '../utils/ui_utils.dart';

class SettingsScreen extends ConsumerWidget {
  static const routeName = '/settings';
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeProvider);
    final settings = ref.watch(settingsProvider);
    final currentLocale = ref.watch(localeProvider);
    final isPremium = ref.watch(isPremiumProvider);
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsTitle)),
      body: ListView(
        children: [
          _buildSectionHeader(context, l10n.premiumSection),
          ListTile(
            leading: const Icon(Icons.star_outline_rounded),
            title: Text(l10n.premiumSubtitle),
            trailing: const Icon(Icons.chevron_right_rounded),
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
                  'sl': 'Slovenščina',
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
            subtitleBuilder: (val) => l10n.secondsPlural(val),
            value: settings.playerRefreshRate,
            min: 3,
            max: 30,
            divisions: 27,
            onChangeEnd: (val) => ref.read(settingsProvider.notifier).setPlayerRefreshRate(val),
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
              subtitleBuilder: (val) => l10n.secondsPlural(val),
              value: settings.deviceListRefreshRate,
              min: 5,
              max: 60,
              divisions: 11,
              onChangeEnd: (val) => ref.read(settingsProvider.notifier).setDeviceListRefreshRate(val),
            ),
          const Divider(),
          _buildSliderTile(
            icon: Icons.timer_rounded,
            title: l10n.connectionTimeout,
            subtitleBuilder: (val) => l10n.secondsPlural(val),
            value: settings.connectionTimeout,
            min: 5,
            max: 60,
            divisions: 11,
            onChangeEnd: (val) => ref.read(settingsProvider.notifier).setConnectionTimeout(val),
          ),
          const Divider(),
          _buildSectionHeader(context, l10n.remoteControl),
          SwitchListTile(
            secondary: const Icon(Icons.gamepad_rounded),
            title: Text(l10n.useVolumeButtonsTitle),
            subtitle: Text(l10n.useVolumeButtonsSubtitle),
            value: settings.useVolumeToolbar,
            onChanged: (value) {
              ref
                  .read(settingsProvider.notifier)
                  .setUseVolumeToolbar(value);
            },
          ),
          if (!kIsWeb && Platform.isAndroid) ...[
            const Divider(),
            _buildSectionHeader(context, l10n.backgroundMonitoringSection),
            SwitchListTile(
              secondary: const Icon(Icons.notifications_active_outlined),
              title: Text(l10n.backgroundMonitoringTitle),
              value: settings.backgroundMonitoringEnabled && isPremium,
              onChanged: (value) {
                if (value && !isPremium) {
                  UiUtils.showActionDialog(
                    context: context,
                    title: l10n.unlockScyphomotePremium,
                    content: l10n.premiumFeatureBackground,
                    actionLabel: l10n.getPremium,
                    onAction: () =>
                        Navigator.of(context).pushNamed(PremiumScreen.routeName),
                  );
                  return;
                }
                ref
                    .read(settingsProvider.notifier)
                    .setBackgroundMonitoringEnabled(value);
              },
            ),
            if (settings.backgroundMonitoringEnabled && isPremium)
              _buildSliderTile(
                icon: Icons.timer_outlined,
                title: l10n.backgroundRefreshIntervalTitle,
                subtitleBuilder: (val) => l10n.secondsPlural(val),
                value: settings.backgroundMonitoringRefreshRate,
                min: 15,
                max: 300,
                divisions: 19,
                onChangeEnd: (val) => ref
                    .read(settingsProvider.notifier)
                    .setBackgroundMonitoringRefreshRate(val),
              ),
          ],
          const Divider(),
          _buildSectionHeader(context, l10n.librarySection),
          _buildSliderTile(
            icon: Icons.grid_view_rounded,
            title: l10n.itemsPerRowTitle,
            subtitleBuilder: (val) => l10n.itemsPlural(val),
            value: settings.libraryItemsPerRow,
            min: 1,
            max: 6,
            divisions: 5,
            onChangeEnd: (val) => ref.read(settingsProvider.notifier).setLibraryItemsPerRow(val),
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
          const Divider(),
          _buildSectionHeader(context, l10n.debugSection),
          if (kDebugMode)
            SwitchListTile(
              secondary: const Icon(Icons.bug_report_rounded),
              title: Text(
                l10n.spoofPremiumStatusTitle,
              ),
              value: ref.watch(isPremiumProvider),
              onChanged: (value) {
                ref.read(isPremiumProvider.notifier).setPremium(value);
              },
            ),
          ListTile(
            leading: const Icon(Icons.bug_report_outlined),
            title: Text(l10n.crashLogsTitle),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () {
              Navigator.of(context).pushNamed(CrashLogScreen.routeName);
            },
          ),
          const Divider(),
          _buildSectionHeader(context, l10n.aboutSection),
          ListTile(
            leading: const Icon(Icons.info_outline_rounded),
            title: Text(
              l10n.aboutAppTitle(AppConstants.appName),
            ),
            trailing: const Icon(Icons.chevron_right_rounded),
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
    required String Function(int value) subtitleBuilder,
    required int value,
    required double min,
    required double max,
    required int divisions,
    required ValueChanged<int> onChangeEnd,
  }) {
    return _SliderTile(
      icon: icon,
      title: title,
      subtitleBuilder: subtitleBuilder,
      value: value,
      min: min,
      max: max,
      divisions: divisions,
      onChangeEnd: onChangeEnd,
    );
  }

  String _getThemeModeName(BuildContext context, ThemeMode mode) => switch (mode) {
        ThemeMode.system => AppLocalizations.of(context)!.themeFollowSystemName,
        ThemeMode.light => AppLocalizations.of(context)!.themeLightModeName,
        ThemeMode.dark => AppLocalizations.of(context)!.themeDarkModeName,
      };
}

class _SliderTile extends StatefulWidget {
  final IconData icon;
  final String title;
  final String Function(int value) subtitleBuilder;
  final int value;
  final double min;
  final double max;
  final int divisions;
  final ValueChanged<int> onChangeEnd;

  const _SliderTile({
    required this.icon,
    required this.title,
    required this.subtitleBuilder,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.onChangeEnd,
  });

  @override
  State<_SliderTile> createState() => _SliderTileState();
}

class _SliderTileState extends State<_SliderTile> {
  double? _dragValue;

  @override
  Widget build(BuildContext context) {
    final currentValue = (_dragValue ?? widget.value.toDouble()).round();
    return ListTile(
      leading: Icon(widget.icon),
      title: Text(widget.title),
      subtitle: Text(widget.subtitleBuilder(currentValue)),
      trailing: SizedBox(
        width: 200,
        child: Slider(
          value: _dragValue ?? widget.value.toDouble(),
          min: widget.min,
          max: widget.max,
          divisions: widget.divisions,
          label: '$currentValue',
          onChanged: (val) {
            setState(() {
              _dragValue = val;
            });
          },
          onChangeEnd: (val) {
            widget.onChangeEnd(val.round());
            setState(() {
              _dragValue = null;
            });
          },
        ),
      ),
    );
  }
}
