import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'screens/login_screen.dart';
import 'screens/device_list_screen.dart';
import 'screens/remote_control/remote_control_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/about_screen.dart';
import 'screens/premium_screen.dart';
import 'providers/auth_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/session_provider.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:home_widget/home_widget.dart';
import 'widgets/home_widget_manager.dart';
import 'utils/logger.dart';
import 'constants.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final packageInfo = await PackageInfo.fromPlatform();
  AppConstants.appVersion = packageInfo.version;

  await HomeWidgetManager.init();

  runApp(const ProviderScope(child: ScyphomoteApp()));
}

class ScyphomoteApp extends ConsumerStatefulWidget {
  const ScyphomoteApp({super.key});

  @override
  ConsumerState<ScyphomoteApp> createState() => _ScyphomoteAppState();
}

class _ScyphomoteAppState extends ConsumerState<ScyphomoteApp>
    with WidgetsBindingObserver {
  StreamSubscription<Uri?>? _widgetSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    AppConstants.isInForeground = true;
    _checkForWidgetLaunch();
    _widgetSubscription = HomeWidget.widgetClicked.listen((Uri? uri) {
      if (uri != null) {
        _handleWidgetLaunch(uri);
      }
    });
  }

  Future<void> _checkForWidgetLaunch() async {
    try {
      final uri = await HomeWidget.initiallyLaunchedFromHomeWidget();
      if (uri != null) {
        _handleWidgetLaunch(uri);
      }
    } catch (e) {
      logError('Failed to check widget launch intent: $e');
    }
  }

  Future<void> _handleWidgetLaunch(Uri uri) async {
    if (uri.host == 'remote') {
      final sessionId = uri.queryParameters['session_id'];
      if (sessionId != null) {
        // Wait for auth to be initialized
        if (ref.read(authProvider).isLoading) {
          final completer = Completer<void>();
          final sub = ref.listenManual(authProvider, (prev, next) {
            if (!next.isLoading) {
              if (!completer.isCompleted) completer.complete();
            }
          });
          await completer.future;
          sub.close();
        }

        if (ref.read(authProvider).currentUser == null) {
          AppConstants.messengerKey.currentState?.showSnackBar(
            const SnackBar(content: Text('Please log in first')),
          );
          return;
        }

        AppConstants.messengerKey.currentState?.showSnackBar(
          const SnackBar(content: Text('Connecting to session...')),
        );

        final sessionNotifier = ref.read(sessionProvider.notifier);
        await sessionNotifier.fetchSessions();
        final sessionState = ref.read(sessionProvider);

        final session = sessionState.sessions
            .where((s) => s.sessionId == sessionId)
            .firstOrNull;

        if (session != null) {
          sessionNotifier.selectSession(session);

          final navigator = AppConstants.navigatorKey.currentState;
          if (navigator != null) {
            navigator.popUntil((route) => route.isFirst);
            navigator.pushNamed(RemoteControlScreen.routeName);
          }
        } else {
          AppConstants.messengerKey.currentState?.showSnackBar(
            const SnackBar(content: Text('Session not found or offline')),
          );
        }
      } else {
        AppConstants.messengerKey.currentState?.showSnackBar(
          const SnackBar(content: Text('Launched from Remote Widget')),
        );
      }
    } else if (uri.host == 'upgrade') {
      await Future.delayed(
        const Duration(milliseconds: 150),
      ); // needed for navigator to not drop the transition when app is brought up from background
      final navigator = AppConstants.navigatorKey.currentState;
      if (navigator != null) {
        navigator.popUntil((route) => route.isFirst);
        navigator.pushNamed(PremiumScreen.routeName);
      }
    }
  }

  @override
  void dispose() {
    _widgetSubscription?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final messenger = AppConstants.messengerKey.currentState;
    if (state == AppLifecycleState.resumed) {
      AppConstants.isInForeground = true;
      ref.read(sessionProvider.notifier).refreshSessionPolling();
    } else if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      AppConstants.isInForeground = false;
      messenger?.clearSnackBars();
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final themeMode = ref.watch(themeProvider);
    final isLoading = authState.isLoading;

    final lightColorScheme = ColorScheme.fromSeed(
      seedColor: Colors.deepPurple,
      brightness: Brightness.light,
    );
    final darkColorScheme = ColorScheme.fromSeed(
      seedColor: Colors.deepPurple,
      brightness: Brightness.dark,
    );

    return MaterialApp(
      navigatorKey: AppConstants.navigatorKey,
      scaffoldMessengerKey: AppConstants.messengerKey,
      title: AppConstants.appName,
      theme: ThemeData(
        colorScheme: lightColorScheme,
        useMaterial3: true,
        snackBarTheme: SnackBarThemeData(
          backgroundColor: lightColorScheme.secondaryContainer,
          contentTextStyle: TextStyle(
            color: lightColorScheme.onSecondaryContainer,
          ),
          behavior: SnackBarBehavior.floating,
        ),
      ),
      darkTheme: ThemeData(
        colorScheme: darkColorScheme,
        useMaterial3: true,
        snackBarTheme: SnackBarThemeData(
          backgroundColor: darkColorScheme.secondaryContainer,
          contentTextStyle: TextStyle(
            color: darkColorScheme.onSecondaryContainer,
          ),
          behavior: SnackBarBehavior.floating,
        ),
      ),
      themeMode: themeMode,
      home: isLoading
          ? const Scaffold(body: Center(child: SizedBox.shrink()))
          : authState.currentUser != null
          ? const DeviceListScreen()
          : const LoginScreen(),
      routes: {
        RemoteControlScreen.routeName: (context) => const RemoteControlScreen(),
        SettingsScreen.routeName: (context) => const SettingsScreen(),
        AboutScreen.routeName: (context) => const AboutScreen(),
        PremiumScreen.routeName: (context) => const PremiumScreen(),
      },
    );
  }
}
