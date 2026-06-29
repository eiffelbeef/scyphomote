import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';
import 'user_management_screen.dart';
import 'emby_connect_login_screen.dart';
import 'package:scyphomote/l10n/app_localizations.dart';
import '../constants.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _serverUrlController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _serverUrlController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_formKey.currentState!.validate()) {
      await ref
          .read(authProvider.notifier)
          .login(
            _serverUrlController.text.trim(),
            _usernameController.text.trim(),
            _passwordController.text,
          );

      // Check if login was successful and we are still on this screen
      final authState = ref.read(authProvider);
      if (mounted && authState.error == null && authState.currentUser != null) {
        Navigator.of(context).pop();
      }
    }
  }

  Future<void> _loginDemo() async {
    await ref
        .read(authProvider.notifier)
        .login('https://demo.jellyfin.org/stable/', 'demo', '', persist: false);

    final authState = ref.read(authProvider);
    if (mounted && authState.error == null && authState.currentUser != null) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final l10n = AppLocalizations.of(context)!;
    final hasUsers = authState.users.isNotEmpty;

    return Scaffold(
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
                    Image.asset('assets/scyphomote.png', height: 100),
                    const SizedBox(height: 16),
                    Text(
                      AppConstants.appName,
                      style: Theme.of(context).textTheme.headlineMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 48),
                    TextFormField(
                      controller: _serverUrlController,
                      decoration: InputDecoration(
                        labelText: l10n.serverUrl,
                        hintText: l10n.serverUrlHint,
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.dns_rounded),
                      ),
                      keyboardType: TextInputType.url,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.url],
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return l10n.pleaseEnterServerUrl;
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _usernameController,
                      decoration: InputDecoration(
                        labelText: l10n.username,
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.person_rounded),
                      ),
                      keyboardType: TextInputType.text,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.username],
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return l10n.pleaseEnterUsername;
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _passwordController,
                      decoration: InputDecoration(
                        labelText: l10n.password,
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.lock_rounded),
                      ),
                      obscureText: true,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => authState.isLoading ? null : _login(),
                      autofillHints: const [AutofillHints.password],
                      validator: (value) => null,
                    ),
                    const SizedBox(height: 24),
                    if (authState.error != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Text(
                          authState.error!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
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
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: authState.isLoading
                          ? null
                          : () async {
                              final result = await Navigator.of(context).push<bool>(
                                MaterialPageRoute(
                                  builder: (context) => const EmbyConnectLoginScreen(),
                                ),
                              );
                              if (result == true && context.mounted) {
                                Navigator.of(context).pop();
                              }
                            },
                      child: Text(l10n.loginWithEmbyConnect),
                    ),
                    if (kDebugMode) ...[
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: authState.isLoading ? null : _loginDemo,
                        child: Text(l10n.tryOnJellyfinDemoServer),
                      ),
                    ],
                    if (hasUsers) ...[
                      const SizedBox(height: 16),
                      OutlinedButton(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) =>
                                  const UserManagementScreen(),
                            ),
                          );
                        },
                        child: Text(l10n.manageUsers),
                      ),
                    ],
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
