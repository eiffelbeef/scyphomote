import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:scyphomote/l10n/app_localizations.dart';
import '../../models/session.dart';

import '../../providers/auth_provider.dart';
import '../../providers/session_provider.dart';
import '../../providers/playback_provider.dart';
import '../../widgets/home_widget_manager.dart';
import '../../utils/ui_utils.dart';
import 'widgets/now_playing_section.dart';
import 'widgets/playback_controls_section.dart';

class RemoteControlScreen extends ConsumerStatefulWidget {
  static const routeName = '/remote';
  const RemoteControlScreen({super.key});

  @override
  ConsumerState<RemoteControlScreen> createState() =>
      _RemoteControlScreenState();
}

class _RemoteControlScreenState extends ConsumerState<RemoteControlScreen> {
  double? _dragVolume;

  double? _optimisticSeek;
  double? _optimisticVolume;

  int? _lastServerSeek;
  int? _lastServerVolume;

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final sessionState = ref.watch(sessionProvider);
    final session = sessionState.selectedSession;
    final user = authState.currentUser;
    final l10n = AppLocalizations.of(context)!;

    if (session == null || user == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.remoteControl)),
        body: Center(child: Text(l10n.noSessionSelected)),
      );
    }

    final nowPlaying = session.nowPlaying;
    final playState = session.playState;
    final isPaused = playState?.isPaused ?? true;
    final duration = nowPlaying?.durationSeconds ?? 0;

    // --- Change Detection Logic ---
    final currentServerSeek = playState?.positionSeconds ?? 0;
    final currentServerVolume = playState?.volumeLevel ?? 0;

    if (_optimisticSeek != null) {
      if (_lastServerSeek != null && currentServerSeek != _lastServerSeek) {
        _optimisticSeek = null;
      }
    }
    _lastServerSeek = currentServerSeek;

    if (_optimisticVolume != null) {
      if (_lastServerVolume != null &&
          currentServerVolume != _lastServerVolume) {
        _optimisticVolume = null;
      }
    }
    _lastServerVolume = currentServerVolume;

    final currentVolume =
        _dragVolume ?? _optimisticVolume ?? currentServerVolume.toDouble();

    String? imageUrl;
    if (nowPlaying != null) {
      final apiService = ref.read(apiServiceProvider);
      imageUrl = apiService.getArtworkUrl(
        nowPlaying.artworkId,
        'Primary',
        maxWidth: 500,
      );
    }

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: Theme.of(context).bottomSystemUiOverlayStyleOnBackground,
      child: Scaffold(
        appBar: AppBar(
          title: Text(session.deviceName),
          centerTitle: true,
          actions: [
            if (HomeWidgetManager.isWidgetSupported)
              IconButton(
                icon: const Icon(Icons.add_to_home_screen),
                tooltip: l10n.addRemoteWidget,
                onPressed: () => _showPinWidgetOptions(context, session),
              ),
            IconButton(
              icon: const Icon(Icons.info_outline),
              onPressed: () => _showSessionInfoDialog(context, session),
            ),
          ],
        ),
        body: LayoutBuilder(
          builder: (context, constraints) {
            // Calculate available space to determine ideal artwork size
            // We subtract fixed margins and estimated heights of controls
            // Controls height estimate (safe values):
            // - Status/Bitrate: 60
            // - Titles: 80
            // - Progress Bar: 40
            // - Play/Pause Row: 100
            // - Message/Stop Row: 70
            // - Volume Slider: 60
            // - Bottom Buttons: 80
            // - Paddings/Spacings: ~150
            final fixedHeights = 60 + 80 + 40 + 100 + 70 + 60 + 80 + 150;
            final availableForArtwork = constraints.maxHeight - fixedHeights;

            // Constrain artwork size between a min and max
            final artworkSize = availableForArtwork.clamp(120.0, 500.0);

            return RefreshIndicator(
              onRefresh: () =>
                  ref.read(sessionProvider.notifier).fetchSessions(),
              child: ScrollConfiguration(
                behavior: ScrollConfiguration.of(
                  context,
                ).copyWith(overscroll: false),
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: ClampingScrollPhysics(),
                  ),
                  slivers: [
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(
                          24.0,
                          16.0,
                          24.0,
                          16.0 + MediaQuery.paddingOf(context).bottom,
                        ),
                        child: Column(
                          children: [
                            const Spacer(),
                            // Top Section: Artwork and Identifiers
                            NowPlayingSection(
                              session: session,
                              imageUrl: imageUrl,
                              artworkSize: artworkSize,
                              maxWidth: constraints.maxWidth - 48.0,
                            ),
                            const Spacer(),
                            // Bottom Section: Playback Controls and Volume
                            // Bottom Section: Playback Controls and Volume
                            PlaybackControlsSection(
                              session: session,
                              currentPositionSeconds:
                                  (_optimisticSeek ?? currentServerSeek)
                                      .toInt(),
                              durationSeconds: duration,
                              isPaused: isPaused,
                              currentVolume: currentVolume,
                              availableWidth: constraints.maxWidth - 48.0,
                              onSeek: (value) {
                                setState(() {
                                  _optimisticSeek = value;
                                });
                              },
                              onSeekEnd: (value) {
                                HapticFeedback.lightImpact();
                                ref
                                    .read(playbackProvider.notifier)
                                    .seek(value.toInt());
                                setState(() {
                                  _optimisticSeek = value;
                                });
                              },
                              onVolumeChanged: (value) =>
                                  setState(() => _dragVolume = value),
                              onVolumeChangeEnd: (value) {
                                HapticFeedback.lightImpact();
                                ref
                                    .read(playbackProvider.notifier)
                                    .setVolume(value.toInt());
                                setState(() {
                                  _dragVolume = null;
                                  _optimisticVolume = value;
                                });
                              },
                            ),
                            const Spacer(),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  void _showPinWidgetOptions(BuildContext context, Session session) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.gamepad),
                title: const Text('Full Remote Widget'),
                subtitle: const Text(
                  'Includes D-Pad and full playback controls',
                ),
                onTap: () {
                  Navigator.pop(context);
                  _pinWidget(context, session, 'RemoteWidgetProvider');
                },
              ),
              ListTile(
                leading: const Icon(Icons.fast_forward),
                title: const Text('Compact Remote Widget'),
                subtitle: const Text(
                  'Single line with basic playback controls',
                ),
                onTap: () {
                  Navigator.pop(context);
                  _pinWidget(context, session, 'CompactRemoteWidgetProvider');
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pinWidget(
    BuildContext context,
    Session session,
    String providerName,
  ) async {
    try {
      final authState = ref.read(authProvider);
      final user = authState.currentUser;

      if (user == null) {
        throw Exception('User not logged in');
      }

      final apiService = ref.read(apiServiceProvider);

      await HomeWidgetManager.pinWidget(
        serverUrl: user.serverUrl,
        accessToken: user.accessToken,
        localDeviceId: apiService.deviceId,
        localDeviceName: apiService.deviceName,
        clientDeviceId: session.deviceId,
        clientDeviceName: session.deviceName,
        sessionId: session.sessionId,
        providerName: providerName,
      );
      if (context.mounted) {
        UiUtils.showSnackBar(
          context,
          AppLocalizations.of(context)!.widgetPinned,
        );
      }
    } catch (e) {
      if (context.mounted) {
        UiUtils.showSnackBar(
          context,
          AppLocalizations.of(context)!.widgetPinFailed(e.toString()),
        );
      }
    }
  }

  void _showSessionInfoDialog(BuildContext context, Session session) {
    showDialog(
      context: context,
      builder: (context) {
        final l10n = AppLocalizations.of(context)!;
        return AlertDialog(
          title: Text(l10n.sessionInfo),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _infoItem(l10n.user, session.userName),
                _infoItem(l10n.client, session.clientName),
                _infoItem(l10n.deviceName, session.deviceName),
                _infoItem(
                  l10n.appVersion,
                  session.applicationVersion ?? l10n.none,
                ),
                _infoItem(l10n.sessionId, session.sessionId),
                if (session.nowPlaying != null)
                  _infoItem(
                    'Item ID',
                    session.nowPlaying!.id,
                    onTapIcon: Icons.open_in_new,
                    onTap: () {
                      final user = ref.read(authProvider).currentUser;
                      if (user != null) {
                        final itemId = session.nowPlaying!.id;
                        final uri = Uri.parse(user.serverUrl).replace(
                          path: '/web/',
                          fragment: '/details?id=$itemId',
                        );
                        launchUrl(uri, mode: LaunchMode.externalApplication);
                      }
                    },
                  ),
                if (session.remoteEndPoint != null)
                  _infoItem(
                    l10n.remoteEndpoint,
                    session.remoteEndPoint!,
                    onTap: () {
                      if (_isPrivateIp(session.remoteEndPoint!)) {
                        _showPrivateIpInfo(context, session.remoteEndPoint!);
                      } else {
                        _showIpLookupPrompt(context, session.remoteEndPoint!);
                      }
                    },
                  ),
                _infoItem(
                  l10n.canSeek,
                  session.playState?.canSeek.toString() ?? l10n.none,
                ),
                _infoItem(
                  l10n.supportsMediaControl,
                  session.supportsMediaControl.toString(),
                ),
                _infoItem(
                  l10n.supportsRemoteControl,
                  session.supportsRemoteControl.toString(),
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.playableMediaTypes,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: session.playableMediaTypes.map((type) {
                    return Chip(
                      label: Text(
                        type,
                        style: const TextStyle(
                          fontSize: 10,
                          fontFamily: 'monospace',
                        ),
                      ),
                      padding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                    );
                  }).toList(),
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.supportedCommands,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: session.supportedCommands.map((cmd) {
                    return Chip(
                      label: Text(
                        cmd,
                        style: const TextStyle(
                          fontSize: 10,
                          fontFamily: 'monospace',
                        ),
                      ),
                      padding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l10n.close),
            ),
          ],
        );
      },
    );
  }

  Widget _infoItem(
    String label,
    String value, {
    VoidCallback? onTap,
    IconData onTapIcon = Icons.info_outline,
  }) {
    final l10n = AppLocalizations.of(context)!;

    Widget valueWidget = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(value, style: const TextStyle(fontFamily: 'monospace')),
        ),
        if (onTap != null)
          Padding(
            padding: const EdgeInsets.only(left: 4.0),
            child: Icon(
              onTapIcon,
              size: 14,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
      ],
    );

    if (onTap != null) {
      valueWidget = InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 2.0),
          child: valueWidget,
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(
              top: 2.0,
            ), // Align with InkWell padding
            child: Text(
              l10n.labelFormat(label),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Align(alignment: Alignment.centerLeft, child: valueWidget),
          ),
        ],
      ),
    );
  }

  void _showIpLookupPrompt(BuildContext context, String ip) {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.ipLookupTitle),
        content: Text(l10n.ipLookupPrompt(ip)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext); // close prompt
              Navigator.pop(context); // close session info dialog
              launchUrl(Uri.parse('https://whatismyipaddress.com/ip/$ip'));
            },
            child: Text(l10n.open),
          ),
        ],
      ),
    );
  }

  bool _isPrivateIp(String ip) {
    if (ip == 'localhost' || ip == '::1') return true;
    final parts = ip.split('.');
    if (parts.length == 4) {
      if (parts[0] == '10') return true;
      if (parts[0] == '127') return true;
      if (parts[0] == '192' && parts[1] == '168') return true;
      if (parts[0] == '172') {
        final second = int.tryParse(parts[1]);
        if (second != null && second >= 16 && second <= 31) return true;
      }
    }
    final lowerIp = ip.toLowerCase();
    if (lowerIp.startsWith('fc') || lowerIp.startsWith('fd')) return true;
    if (lowerIp.startsWith('fe8') ||
        lowerIp.startsWith('fe9') ||
        lowerIp.startsWith('fea') ||
        lowerIp.startsWith('feb')) {
      return true;
    }
    return false;
  }

  void _showPrivateIpInfo(BuildContext context, String ip) {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.privateIpTitle),
        content: Text(l10n.privateIpMessage(ip)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(l10n.close),
          ),
        ],
      ),
    );
  }
}
