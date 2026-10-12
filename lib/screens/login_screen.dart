import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';
import 'device_list_screen.dart';
import 'user_management_screen.dart';
import 'emby_connect_login_screen.dart';
import '../widgets/auth_text_field.dart';
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

  bool _serverEntered = false;

  @override
  void dispose() {
    _serverUrlController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _submitServer() {
    if (_serverUrlController.text.trim().isEmpty) {
      _formKey.currentState?.validate();
      return;
    }
    setState(() => _serverEntered = true);
  }

  void _onLoginSuccess() {
    if (!mounted) return;
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop(true);
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const DeviceListScreen()),
      );
    }
  }

  Future<void> _login() async {
    if (_formKey.currentState!.validate()) {
      await ref.read(authProvider.notifier).login(
            _serverUrlController.text.trim(),
            _usernameController.text.trim(),
            _passwordController.text,
          );

      if (!mounted) return;
      final authState = ref.read(authProvider);
      if (authState.error == null && authState.currentUser != null) {
        _onLoginSuccess();
      }
    }
  }

  Future<void> _loginDemo() async {
    await ref
        .read(authProvider.notifier)
        .login('https://demo.jellyfin.org/stable/', 'demo', '', persist: false);

    if (!mounted) return;
    final authState = ref.read(authProvider);
    if (authState.error == null && authState.currentUser != null) {
      _onLoginSuccess();
    }
  }

  Widget _buildOrDivider(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      child: Row(
        children: [
          const Expanded(child: Divider()),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Text(AppLocalizations.of(context)!.orDivider),
          ),
          const Expanded(child: Divider()),
        ],
      ),
    );
  }

  Future<void> _openQuickConnect() async {
    final success = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _QuickConnectDialog(
        serverUrl: _serverUrlController.text.trim(),
      ),
    );

    if (success == true && mounted) {
      _onLoginSuccess();
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final l10n = AppLocalizations.of(context)!;
    final hasUsers = authState.users.isNotEmpty;

    return PopScope(
      canPop: !_serverEntered,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _serverEntered) {
          setState(() => _serverEntered = false);
        }
      },
      child: Scaffold(
        appBar: (_serverEntered || Navigator.of(context).canPop())
            ? AppBar(
                leading: BackButton(
                  onPressed: () {
                    if (_serverEntered) {
                      setState(() => _serverEntered = false);
                    } else if (Navigator.of(context).canPop()) {
                      Navigator.of(context).pop();
                    }
                  },
                ),
                backgroundColor: Colors.transparent,
                elevation: 0,
                scrolledUnderElevation: 0,
              )
            : null,
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
                      if (_serverEntered) ...[
                        const SizedBox(height: 4),
                        Text(
                          _serverUrlController.text.trim(),
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Theme.of(context).colorScheme.outline,
                              ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                      const SizedBox(height: 48),
                      if (!_serverEntered) ...[
                        AuthTextField(
                          controller: _serverUrlController,
                          labelText: l10n.serverUrl,
                          hintText: l10n.serverUrlHint,
                          icon: Icons.dns_rounded,
                          keyboardType: TextInputType.url,
                          autofillHints: const [AutofillHints.url],
                          emptyErrorMsg: l10n.pleaseEnterServerUrl,
                          textInputAction: TextInputAction.next,
                          onFieldSubmitted: (_) => _submitServer(),
                        ),
                        const SizedBox(height: 24),
                        FilledButton(
                          onPressed: _submitServer,
                          child: Text(l10n.connect),
                        ),
                        _buildOrDivider(context),
                        TextButton(
                          onPressed: authState.isLoading
                              ? null
                              : () async {
                                  final result =
                                      await Navigator.of(context).push<bool>(
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          const EmbyConnectLoginScreen(),
                                    ),
                                  );
                                  if (result == true && mounted) {
                                    _onLoginSuccess();
                                  }
                                },
                          child: Text(l10n.loginWithEmbyConnect),
                        ),
                      ] else ...[
                        AuthTextField(
                          controller: _usernameController,
                          labelText: l10n.username,
                          icon: Icons.person_rounded,
                          keyboardType: TextInputType.text,
                          autofillHints: const [AutofillHints.username],
                          emptyErrorMsg: l10n.pleaseEnterUsername,
                          textInputAction: TextInputAction.next,
                        ),
                        const SizedBox(height: 16),
                        AuthTextField(
                          controller: _passwordController,
                          labelText: l10n.password,
                          icon: Icons.lock_rounded,
                          keyboardType: TextInputType.text,
                          autofillHints: const [AutofillHints.password],
                          obscureText: true,
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: (_) =>
                              authState.isLoading ? null : _login(),
                          emptyErrorMsg: '',
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
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                )
                              : Text(l10n.login),
                        ),
                        _buildOrDivider(context),
                        TextButton(
                          onPressed:
                              authState.isLoading ? null : _openQuickConnect,
                          child: Text(l10n.loginWithQuickConnect),
                        ),
                      ],
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
      ),
    );
  }
}

class _QuickConnectDialog extends ConsumerStatefulWidget {
  final String serverUrl;

  const _QuickConnectDialog({required this.serverUrl});

  @override
  ConsumerState<_QuickConnectDialog> createState() =>
      _QuickConnectDialogState();
}

class _QuickConnectDialogState extends ConsumerState<_QuickConnectDialog> {
  String? _code;
  String? _error;
  Timer? _timer;
  bool _isChecking = false;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _start() async {
    try {
      final res = await ref
          .read(authProvider.notifier)
          .initiateQuickConnect(widget.serverUrl);
      final code = res['Code'] as String?;
      final secret = res['Secret'] as String?;
      if (code == null || secret == null) throw Exception('Invalid response');
      if (!mounted) return;
      setState(() => _code = code);

      _timer = Timer.periodic(const Duration(seconds: 3), (t) async {
        if (_isChecking) return;
        _isChecking = true;
        try {
          final auth = await ref
              .read(authProvider.notifier)
              .checkQuickConnect(widget.serverUrl, secret);
          if (auth) {
            t.cancel();
            if (!mounted) return;
            await ref
                .read(authProvider.notifier)
                .completeQuickConnectLogin(widget.serverUrl, secret);
            if (mounted) Navigator.of(context).pop(true);
          }
        } catch (e) {
          if (!mounted) return;
          t.cancel();
          setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
        } finally {
          _isChecking = false;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return AlertDialog(
      title: Text(l10n.quickConnect),
      content: _error != null
          ? Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            )
          : _code == null
              ? const SizedBox(
                  height: 80,
                  child: Center(child: CircularProgressIndicator()),
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      l10n.quickConnectInstructions,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    SelectableText(
                      _code!,
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            letterSpacing: 4,
                          ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        const SizedBox(width: 12),
                        Text(l10n.waitingForAuthorization),
                      ],
                    ),
                  ],
                ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
      ],
    );
  }
}
