import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/session.dart';
import '../../../providers/playback_provider.dart';
import '../../../constants/jellyfin_commands.dart';

class RemoteNavigationSheet extends ConsumerWidget {
  final Session session;

  final VoidCallback onShowKeyboard;

  const RemoteNavigationSheet({
    super.key,
    required this.session,
    required this.onShowKeyboard,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 24),

              // Top Buttons Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _RoundActionButton(
                    icon: Icons.home_rounded,
                    label: 'Home',
                    onPressed: session.ifCapable(JellyfinCommands.goHome, () {
                      HapticFeedback.mediumImpact();
                      ref
                          .read(playbackProvider.notifier)
                          .sendCommand(JellyfinCommands.goHome);
                    }),
                  ),
                  _RoundActionButton(
                    icon: Icons.settings_rounded,
                    label: 'Settings',
                    onPressed: session.ifCapable(
                      JellyfinCommands.goToSettings,
                      () {
                        HapticFeedback.mediumImpact();
                        ref
                            .read(playbackProvider.notifier)
                            .sendCommand(JellyfinCommands.goToSettings);
                      },
                    ),
                  ),
                  _RoundActionButton(
                    icon: Icons.keyboard_rounded,
                    label: 'Keyboard',
                    onPressed: session.ifCapable(
                      JellyfinCommands.sendString,
                      () {
                        Navigator.pop(context); // Close sheet to show input
                        onShowKeyboard();
                      },
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 48),

              // D-Pad Container
              Container(
                width: 240,
                height: 240,
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                  shape: BoxShape.circle,
                ),
                child: Stack(
                  children: [
                    // Up
                    Align(
                      alignment: Alignment.topCenter,
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: _DPadButton(
                          icon: Icons.keyboard_arrow_up_rounded,
                          onPressed: session.ifCapable(
                            JellyfinCommands.moveUp,
                            () => ref
                                .read(playbackProvider.notifier)
                                .sendCommand(JellyfinCommands.moveUp),
                          ),
                        ),
                      ),
                    ),
                    // Down
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: _DPadButton(
                          icon: Icons.keyboard_arrow_down_rounded,
                          onPressed: session.ifCapable(
                            JellyfinCommands.moveDown,
                            () => ref
                                .read(playbackProvider.notifier)
                                .sendCommand(JellyfinCommands.moveDown),
                          ),
                        ),
                      ),
                    ),
                    // Left
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: _DPadButton(
                          icon: Icons.keyboard_arrow_left_rounded,
                          onPressed: session.ifCapable(
                            JellyfinCommands.moveLeft,
                            () => ref
                                .read(playbackProvider.notifier)
                                .sendCommand(JellyfinCommands.moveLeft),
                          ),
                        ),
                      ),
                    ),
                    // Right
                    Align(
                      alignment: Alignment.centerRight,
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: _DPadButton(
                          icon: Icons.keyboard_arrow_right_rounded,
                          onPressed: session.ifCapable(
                            JellyfinCommands.moveRight,
                            () => ref
                                .read(playbackProvider.notifier)
                                .sendCommand(JellyfinCommands.moveRight),
                          ),
                        ),
                      ),
                    ),
                    // Center (OK)
                    Align(
                      alignment: Alignment.center,
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: session.hasCapability(JellyfinCommands.select)
                              ? Theme.of(context).colorScheme.primaryContainer
                              : Theme.of(
                                  context,
                                ).colorScheme.onSurface.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                          boxShadow: [
                            if (session.hasCapability(JellyfinCommands.select))
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.1),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: session.ifCapable(
                              JellyfinCommands.select,
                              () {
                                HapticFeedback.mediumImpact();
                                ref
                                    .read(playbackProvider.notifier)
                                    .sendCommand(JellyfinCommands.select);
                              },
                            ),
                            customBorder: const CircleBorder(),
                            child: Center(
                              child: Text(
                                'OK',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                  color:
                                      session.hasCapability(
                                        JellyfinCommands.select,
                                      )
                                      ? Theme.of(
                                          context,
                                        ).colorScheme.onPrimaryContainer
                                      : Theme.of(context).colorScheme.onSurface
                                            .withValues(alpha: 0.38),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 48),

              // Back Button
              _RoundActionButton(
                icon: Icons.arrow_back_rounded,
                label: 'Back',
                onPressed: session.ifCapable(JellyfinCommands.back, () {
                  HapticFeedback.mediumImpact();
                  ref
                      .read(playbackProvider.notifier)
                      .sendCommand(JellyfinCommands.back);
                }),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoundActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  const _RoundActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton.filledTonal(
          onPressed: onPressed,
          icon: Icon(icon),
          iconSize: 28,
          style: IconButton.styleFrom(padding: const EdgeInsets.all(16)),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _DPadButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;

  const _DPadButton({required this.icon, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed != null
          ? () {
              HapticFeedback.mediumImpact();
              onPressed!();
            }
          : null,
      icon: Icon(icon),
      iconSize: 32,
      style: IconButton.styleFrom(
        foregroundColor: Theme.of(context).colorScheme.onSurface,
      ),
    );
  }
}
