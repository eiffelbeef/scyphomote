import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';
import 'package:scyphomote/l10n/app_localizations.dart';
import '../widgets/user_avatar.dart';
import 'login_screen.dart';
import '../widgets/themed_svg_icon.dart';

class UserManagementScreen extends ConsumerWidget {
  const UserManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.manageUsers)),
      body: authState.users.isEmpty
          ? Center(child: Text(l10n.noSavedUsers))
          : ListView.builder(
              itemCount: authState.users.length,
              itemBuilder: (context, index) {
                final user = authState.users[index];
                final isActive = user.userId == authState.currentUser?.userId;

                return ListTile(
                  leading: UserAvatar(user: user),
                  title: Text(user.username),
                  subtitle: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ThemedSvgIcon(
                        user.isEmby
                            ? 'assets/emby.svg'
                            : 'assets/jellyfin.svg',
                        size: 14.0,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 6.0),
                      Flexible(
                        child: Text(
                          user.serverUrl,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  trailing: isActive
                      ? Icon(
                          Icons.check_circle,
                          color: Theme.of(context).colorScheme.primary,
                        )
                      : null,
                  onTap: () async {
                    await ref
                        .read(authProvider.notifier)
                        .switchUser(user.userId);
                    if (context.mounted) {
                      Navigator.of(context).popUntil((route) => route.isFirst);
                    }
                  },
                  onLongPress: () {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: Text(l10n.deleteUser),
                        content: Text(
                          l10n.deleteUserConfirmation(user.username),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: Text(l10n.cancel),
                          ),
                          TextButton(
                            onPressed: () async {
                              await ref
                                  .read(authProvider.notifier)
                                  .deleteUser(user.userId);
                              if (context.mounted) {
                                Navigator.of(context).pop();
                                if (authState.users.length == 1) {
                                  Navigator.of(context).pushReplacement(
                                    MaterialPageRoute(
                                      builder: (context) => const LoginScreen(),
                                    ),
                                  );
                                }
                              }
                            },
                            child: Text(l10n.delete),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const LoginScreen()),
          );
        },
        icon: const Icon(Icons.add_rounded),
        label: Text(l10n.addUser),
      ),
    );
  }
}
