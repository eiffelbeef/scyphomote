import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scyphomote/constants.dart';
import 'package:scyphomote/l10n/app_localizations.dart';
import '../utils/ui_utils.dart';
import '../providers/auth_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/session_provider.dart';
import '../models/session.dart';
import '../widgets/user_avatar.dart';
import 'remote_control/remote_control_screen.dart';
import 'user_management_screen.dart';
import 'settings_screen.dart';
import '../widgets/text_input_dialog.dart';
import '../utils/logger.dart';

class DeviceListScreen extends ConsumerWidget {
  const DeviceListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final sessionState = ref.watch(sessionProvider);
    final settings = ref.watch(settingsProvider);
    final l10n = AppLocalizations.of(context)!;

    final filteredSessions = sessionState.sessions.where((s) {
      if (settings.hideOtherUsersSessions &&
          s.userId != authState.currentUser?.userId) {
        return false;
      }
      return true;
    }).toList();

    final activeSessions =
        filteredSessions.where((s) => s.isPlaying || s.isPaused).toList()
          ..sort((a, b) => a.deviceName.toLowerCase().compareTo(b.deviceName.toLowerCase()));

    final idleSessions =
        filteredSessions.where((s) => !s.isPlaying && !s.isPaused).toList()
          ..sort((a, b) {
            if (a.canPlayOn != b.canPlayOn) {
              return a.canPlayOn ? -1 : 1;
            }
            if (a.lastActivityDate == null && b.lastActivityDate == null) {
              return 0;
            }
            if (a.lastActivityDate == null) return 1;
            if (b.lastActivityDate == null) return -1;
            return b.lastActivityDate!.compareTo(a.lastActivityDate!);
          });

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: Theme.of(context).bottomSystemUiOverlayStyleOverScrolled,
      child: Scaffold(
        appBar: AppBar(
          leading: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Image.asset('assets/scyphomote.png', width: 40, height: 40),
          ),
          title: const Text(AppConstants.appName),
          actions: [
            IconButton(
              icon: const Icon(Icons.message_rounded),
              onPressed:
                  _getSessionsSupportingMessaging(sessionState).isNotEmpty
                  ? () => _showMessageAllDialog(context, ref)
                  : null,
            ),
            IconButton(
              icon: const Icon(Icons.settings_rounded),
              onPressed: () {
                Navigator.of(context).pushNamed(SettingsScreen.routeName);
              },
            ),
            IconButton(
              icon: authState.currentUser != null
                  ? UserAvatar(user: authState.currentUser!, radius: 12)
                  : const Icon(Icons.person_rounded),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const UserManagementScreen(),
                  ),
                );
              },
            ),
          ],
        ),
        body: sessionState.isLoading && sessionState.sessions.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset('assets/scyphomote.png', width: 120, height: 120),
                    const SizedBox(height: 24),
                    const SizedBox(
                      width: 120,
                      child: LinearProgressIndicator(
                        borderRadius: BorderRadius.all(Radius.circular(4)),
                      ),
                    ),
                  ],
                ),
              )
            : RefreshIndicator(
                onRefresh: () => ref.read(sessionProvider.notifier).fetchSessions(),
                child: filteredSessions.isEmpty
                    ? CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              sessionState.error != null
                                  ? Icons.error_outline_rounded
                                  : Icons.devices_other,
                              size: 64,
                              color: sessionState.error != null
                                  ? Theme.of(context).colorScheme.error
                                  : Theme.of(context).colorScheme.secondary,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              sessionState.error != null ? 'Connection Error' : l10n.noActiveDevicesFound,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 8),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 32.0),
                              child: Text(
                                sessionState.error ?? l10n.startPlayingMediaOnJellyfinClient,
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                )
              : CustomScrollView(
                  slivers: [
                    ..._buildActiveSessions(context, ref, activeSessions),
                    ..._buildIdleSessions(context, ref, idleSessions),
                    const SliverPadding(padding: EdgeInsets.only(bottom: 24)),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildDeviceCard(
    BuildContext context,
    WidgetRef ref,
    Session session,
  ) {
    final authState = ref.read(authProvider);
    final l10n = AppLocalizations.of(context)!;
    final isPlaying = session.isPlaying;
    final isPaused = session.isPaused;
    final isActive = isPlaying || isPaused;

    // Calculate progress for active sessions
    double progress = 0.0;
    final duration = session.nowPlaying?.durationSeconds ?? 0;
    final position = session.playState?.positionSeconds ?? 0;

    if (duration > 0) {
      progress = (position / duration).clamp(0.0, 1.0);
    }

    final (bgColor, icon, iconColor) = switch ((isPlaying, isPaused)) {
      (true, _) => (Colors.green, Icons.play_arrow_rounded, Colors.white),
      (_, true) => (Colors.orange, Icons.pause_rounded, Colors.white),
      _ => (Theme.of(context).colorScheme.surfaceContainerHighest, Icons.devices_rounded, null),
    };

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () async {
          ref.read(sessionProvider.notifier).selectSession(session);
          await Navigator.of(context).pushNamed(RemoteControlScreen.routeName);
          ref.read(sessionProvider.notifier).deselectSession();
        },
        child: Column(
          children: [
            ListTile(
              leading: CircleAvatar(
                backgroundColor: bgColor,
                child: Icon(icon, color: iconColor),
              ),
              title: Row(
                children: [
                  Flexible(child: Text(session.deviceName)),
                  if (authState.currentUser?.userId != session.userId) ...[
                    const SizedBox(width: 8),
                    Text(
                      '(${session.userName})',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(session.clientName),
                      if (session.canPlayOn) ...[
                        const SizedBox(width: 4),
                        Icon(
                          Icons.cast_rounded,
                          size: 14,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ],
                    ],
                  ),
                  if (session.nowPlaying != null) ...[
                    Text(
                      session.nowPlaying!.displayTitle,
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    if (session.playMethod != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4.0),
                        child: Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: session.playMethod == 'Transcode'
                                    ? Colors.orange
                                    : Colors.green,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              session.playMethod == 'Transcode'
                                  ? l10n.transcoding
                                  : l10n.directPlay,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            if (session.playState?.positionSeconds != null &&
                                session.nowPlaying!.durationSeconds != null &&
                                MediaQuery.of(context).size.width >= 360) ...[
                              const Spacer(),
                              Builder(
                                builder: (context) {
                                  final baseColor = Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant;
                                  return Text.rich(
                                    TextSpan(
                                      children: [
                                        TextSpan(
                                          text: formatDuration(
                                            session.playState!.positionSeconds!,
                                          ),
                                        ),
                                        TextSpan(
                                          text:
                                              ' / ${formatDuration(session.nowPlaying!.durationSeconds!)}',
                                          style: TextStyle(
                                            color: baseColor.withValues(
                                              alpha: 0.35,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(
                                          color: baseColor.withValues(
                                            alpha: 0.65,
                                          ),
                                          fontWeight: FontWeight.w300,
                                          fontFeatures: const [
                                            FontFeature.tabularFigures(),
                                          ],
                                          height: 1.0,
                                        ),
                                  );
                                },
                              ),
                            ],
                          ],
                        ),
                      ),
                  ],
                ],
              ),
              trailing: const Icon(Icons.chevron_right),
            ),
            if (isActive && progress > 0)
              LinearProgressIndicator(
                value: progress,
                minHeight: 4,
                backgroundColor: Theme.of(
                  context,
                ).colorScheme.surfaceContainerHighest,
              ),
          ],
        ),
      ),
    );
  }

  // Sliver builders for better code organization
  List<Widget> _buildActiveSessions(
    BuildContext context,
    WidgetRef ref,
    List<Session> activeSessions,
  ) {
    if (activeSessions.isEmpty) return [];

    return [
      _buildSectionHeader(
        context,
        AppLocalizations.of(context)!.activeDevices,
        Theme.of(context).colorScheme.primary,
        const EdgeInsets.fromLTRB(16, 16, 16, 8),
      ),
      _buildSessionList(context, ref, activeSessions),
    ];
  }

  List<Widget> _buildIdleSessions(
    BuildContext context,
    WidgetRef ref,
    List<Session> idleSessions,
  ) {
    if (idleSessions.isEmpty) return [];

    return [
      _buildSectionHeader(
        context,
        AppLocalizations.of(context)!.idleDevices,
        Theme.of(context).colorScheme.secondary,
        const EdgeInsets.fromLTRB(16, 24, 16, 8),
      ),
      _buildSessionList(context, ref, idleSessions),
    ];
  }

  Widget _buildSectionHeader(
    BuildContext context,
    String title,
    Color color,
    EdgeInsets padding,
  ) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: padding,
        child: Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: color,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildSessionList(
    BuildContext context,
    WidgetRef ref,
    List<Session> sessions,
  ) {
    return SliverList(
      delegate: SliverChildBuilderDelegate((context, index) {
        if (index >= sessions.length) return null;
        return _buildDeviceCard(context, ref, sessions[index]);
      }, childCount: sessions.length),
    );
  }

  List<Session> _getSessionsSupportingMessaging(dynamic sessionState) {
    return (sessionState.sessions as List)
        .whereType<Session>()
        .where((session) => session.canDisplayMessages)
        .toList();
  }

  void _showMessageAllDialog(BuildContext context, WidgetRef ref) {
    final sessionState = ref.read(sessionProvider);
    final supportedSessions = _getSessionsSupportingMessaging(sessionState);

    final l10n = AppLocalizations.of(context)!;

    TextInputDialog.show(
      context: context,
      title: l10n.messageAllSessions,
      subtitle: l10n.sessionsWillReceiveMessage(supportedSessions.length),
      maxLines: 3,
      onSend: (text) async {
        final authState = ref.read(authProvider);
        final user = authState.currentUser;
        if (user == null) return;

        final apiService = ref.read(apiServiceProvider);
        int successCount = 0;

        for (final session in supportedSessions) {
          try {
            await apiService.sendDisplayMessage(
              session.sessionId,
              AppConstants.appName,
              text,
            );
            successCount++;
          } catch (e) {
            logError('Failed to send message to ${session.deviceName}: $e');
          }
        }

        if (context.mounted) {
          UiUtils.showSnackBar(
            context,
            AppLocalizations.of(context)!.messageSentToSessions(successCount),
          );
        }
      },
    );
  }
}
