import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scyphomote/l10n/app_localizations.dart';
import '../providers/auth_provider.dart';
import '../utils/logger.dart';

class EmbyConnectLoginScreen extends ConsumerStatefulWidget {
  const EmbyConnectLoginScreen({super.key});

  @override
  ConsumerState<EmbyConnectLoginScreen> createState() => _EmbyConnectLoginScreenState();
}

class _EmbyConnectLoginScreenState extends ConsumerState<EmbyConnectLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final l10n = AppLocalizations.of(context)!;
    if (_formKey.currentState!.validate()) {
      try {
        final servers = await ref.read(authProvider.notifier).loginWithEmbyConnect(
          _usernameController.text.trim(),
          _passwordController.text,
        );

        if (mounted) {
          if (servers.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(l10n.noEmbyServersFound)),
            );
          } else {
            _showServerSelectionDialog(servers);
          }
        }
      } catch (e) {
        logError('Emby Connect login failed: $e');
      }
    }
  }

  void _showServerSelectionDialog(List<Map<String, dynamic>> servers) {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: Text(l10n.selectAServer),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: servers.length,
              itemBuilder: (context, index) {
                final server = servers[index];
                return ListTile(
                  title: Text(server['Name'] as String? ?? l10n.unknownServer),
                  subtitle: Text(server['Url'] as String? ?? ''),
                  onTap: () {
                    Navigator.of(context).pop();
                    _completeLogin(server);
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l10n.cancel),
            ),
          ],
        );
      },
    );
  }

  Future<void> _completeLogin(Map<String, dynamic> server) async {
    await ref.read(authProvider.notifier).completeEmbyConnectLogin(server);
    if (mounted && ref.read(authProvider).currentUser != null) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final authState = ref.watch(authProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.embyConnect)),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: AutofillGroup(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(Icons.cloud_circle_rounded, size: 80, color: Colors.green),
                    const SizedBox(height: 32),
                    TextFormField(
                      controller: _usernameController,
                      autofillHints: const [AutofillHints.username, AutofillHints.email],
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: l10n.embyConnectUsernameEmail,
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.person_rounded),
                      ),
                      validator: (value) => value == null || value.isEmpty ? l10n.requiredField : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _passwordController,
                      autofillHints: const [AutofillHints.password],
                      keyboardType: TextInputType.visiblePassword,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => authState.isLoading ? null : _login(),
                      decoration: InputDecoration(
                        labelText: l10n.password,
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.lock_rounded),
                      ),
                      obscureText: true,
                      validator: (value) => value == null || value.isEmpty ? l10n.requiredField : null,
                    ),
                    const SizedBox(height: 24),
                    if (authState.error != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Text(
                          authState.error!,
                          style: TextStyle(color: Theme.of(context).colorScheme.error),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    FilledButton(
                      onPressed: authState.isLoading ? null : _login,
                      child: authState.isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(l10n.login),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
