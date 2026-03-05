import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/session.dart';
import '../../../providers/playback_provider.dart';
import '../../../constants/jellyfin_commands.dart';
import '../../../widgets/text_input_dialog.dart';
import '../../../constants.dart';
import '../../../utils/ui_utils.dart';

class RemoteIconButton extends StatelessWidget {
  final IconData icon;
  final double iconSize;
  final VoidCallback? onPressed;
  final ButtonStyle? style;
  final String? tooltip;

  const RemoteIconButton({
    super.key,
    required this.icon,
    this.iconSize = 24,
    this.onPressed,
    this.style,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton.filledTonal(
      icon: Icon(icon),
      iconSize: iconSize,
      onPressed: onPressed != null
          ? () {
              HapticFeedback.mediumImpact();
              onPressed!();
            }
          : null,
      style: style,
      tooltip: tooltip,
    );
  }
}

class MessageButton extends ConsumerWidget {
  final Session session;
  final double iconSize;

  const MessageButton({super.key, required this.session, this.iconSize = 24});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return RemoteIconButton(
      icon: Icons.message_rounded,
      iconSize: iconSize,
      onPressed: session.ifCapable(
        JellyfinCommands.displayMessage,
        () => TextInputDialog.show(
          context: context,
          title: 'Send Message',
          maxLines: 3,
          onSend: (text) async {
            if (context.mounted) {
              UiUtils.showSnackBar(context, 'Message sent');
            }
            await ref
                .read(playbackProvider.notifier)
                .sendDisplayMessage(AppConstants.appName, text);
          },
        ),
      ),
    );
  }
}
