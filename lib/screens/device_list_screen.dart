import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scyphomote/constants.dart';
import '../providers/auth_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/session_provider.dart';
import '../models/session.dart';
import '../utils/ui_utils.dart';
import '../widgets/user_avatar.dart';
import 'remote_control/remote_control_screen.dart';
import 'user_management_screen.dart';
import 'loading_screen.dart';
import 'settings_screen.dart';
import '../widgets/text_input_dialog.dart';
import '../utils/logger.dart';

class DeviceListScreen extends ConsumerWidget {
  const DeviceListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final sessionState = ref.watch(sessionProvider);

    if (sessionState.isLoading && sessionState.sessions.isEmpty) {
      return const LoadingScreen();
    }

    return Scaffold(
      appBar: AppBar(
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Image.asset('assets/scyphomote.png', width: 40, height: 40),
        ),
        title: const Text(AppConstants.appName),
        actions: [
          IconButton(
            icon: const Icon(Icons.message),
            onPressed: _getSessionsSupportingMessaging(sessionState).isNotEmpty
                ? () => _showMessageAllDialog(context, ref)
                : null,
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.of(context).pushNamed(SettingsScreen.routeName);
            },
          ),
          IconButton(
            icon: const Icon(Icons.person),
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
      body: RefreshIndicator(
        onRefresh: () => ref.read(sessionProvider.notifier).fetchSessions(),
        child: sessionState.sessions.isEmpty
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
                            Icons.devices_other,
                            size: 64,
                            color: Theme.of(context).colorScheme.secondary,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No active devices found',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Start playing media on a Jellyfin client',
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              )
            : CustomScrollView(
                slivers: [
                  ..._buildActiveSessions(context, ref, sessionState),
                  ..._buildIdleSessions(context, ref, sessionState),
                  const SliverPadding(padding: EdgeInsets.only(bottom: 24)),
                ],
              ),
      ),
      bottomNavigationBar: authState.currentUser != null
          ? Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
              ),
              child: Row(
                children: [
                  UserAvatar(
                    user: authState.currentUser!,
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          authState.currentUser!.username,
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        Text(
                          authState.currentUser!.serverUrl,
                          style: Theme.of(context).textTheme.bodySmall,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            )
          : null,
    );
  }

  Widget _buildDeviceCard(
    BuildContext context,
    WidgetRef ref,
    dynamic session,
  ) {
    final authState = ref.read(authProvider);
    final isPlaying = session.isPlaying;
    final isPaused = session.isPaused;
    final isActive = isPlaying || isPaused;

    // Calculate progress for active sessions
    double progress = 0.0;
    if (session.nowPlaying != null &&
        session.nowPlaying!.durationSeconds > 0 &&
        session.playState != null) {
      progress =
          (session.playState!.positionSeconds /
                  session.nowPlaying!.durationSeconds)
              .clamp(0.0, 1.0);
    }

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
                backgroundColor: isPlaying
                    ? Colors.green
                    : isPaused
                    ? Colors.orange
                    : Theme.of(context).colorScheme.surfaceContainerHighest,
                child: Icon(
                  isPlaying
                      ? Icons.play_arrow_rounded
                      : isPaused
                      ? Icons.pause_rounded
                      : Icons.devices,
                  color: isPlaying || isPaused ? Colors.white : null,
                ),
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
                  Text(session.clientName),
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
                                  ? 'Transcoding'
                                  : 'Direct Play',
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

  // Helper methods for session filtering and sorting
  static int _compareDeviceNames(Session a, Session b) {
    return a.deviceName.toLowerCase().compareTo(b.deviceName.toLowerCase());
  }

  List<Session> _getSessions(
    SessionState state,
    WidgetRef ref,
    AuthState authState, {
    required bool active,
    bool sortByLastActivity = false,
  }) {
    final settings = ref.watch(settingsProvider);
    final sessions = state.sessions.where((s) {
      if (settings.hideOtherUsersSessions &&
          s.userId != authState.currentUser?.userId) {
        return false;
      }
      final isSessionActive = s.isPlaying || s.isPaused;
      return active ? isSessionActive : !isSessionActive;
    }).toList();

    if (sortByLastActivity) {
      return sessions..sort((a, b) {
        if (a.lastActivityDate == null && b.lastActivityDate == null) {
          return 0;
        }
        if (a.lastActivityDate == null) return 1;
        if (b.lastActivityDate == null) return -1;
        return b.lastActivityDate!.compareTo(a.lastActivityDate!);
      });
    } else {
      return sessions..sort(_compareDeviceNames);
    }
  }

  // Sliver builders for better code organization
  List<Widget> _buildActiveSessions(
    BuildContext context,
    WidgetRef ref,
    SessionState state,
  ) {
    final authState = ref.watch(authProvider);
    final activeSessions = _getSessions(state, ref, authState, active: true);
    if (activeSessions.isEmpty) return [];

    return [
      _buildSectionHeader(
        context,
        'Active Devices',
        Theme.of(context).colorScheme.primary,
        const EdgeInsets.fromLTRB(16, 16, 16, 8),
      ),
      _buildSessionList(context, ref, activeSessions),
    ];
  }

  List<Widget> _buildIdleSessions(
    BuildContext context,
    WidgetRef ref,
    SessionState state,
  ) {
    final authState = ref.watch(authProvider);
    final idleSessions = _getSessions(
      state,
      ref,
      authState,
      active: false,
      sortByLastActivity: true,
    );
    if (idleSessions.isEmpty) return [];

    return [
      _buildSectionHeader(
        context,
        'Idle Devices',
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

    TextInputDialog.show(
      context: context,
      title: 'Message all sessions',
      subtitle:
          '${supportedSessions.length} session(s) will receive this message',
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
            'Message sent to $successCount session(s)',
          );
        }
      },
    );
  }
}
