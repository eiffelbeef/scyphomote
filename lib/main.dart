import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'screens/login_screen.dart';
import 'screens/device_list_screen.dart';
import 'screens/remote_control/remote_control_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/about_screen.dart';
import 'screens/premium_screen.dart';
import 'screens/crash_log_screen.dart';
import 'screens/loading_screen.dart';
import 'providers/auth_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/locale_provider.dart';
import 'providers/session_provider.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:home_widget/home_widget.dart';
import 'package:scyphomote/l10n/app_localizations.dart';
import 'widgets/home_widget_manager.dart';
import 'utils/logger.dart';
import 'utils/ui_utils.dart';
import 'services/background_session_service.dart';
import 'services/media_control_service.dart';
import 'services/review_service.dart';
import 'providers/settings_provider.dart';
import 'constants.dart';

void main() {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    FlutterError.onError = (FlutterErrorDetails details) {
      FlutterError.presentError(details);
      logError('Flutter framework error: ${details.exception}');
      CrashLog.record(details.exception, details.stack);
    };

    PlatformDispatcher.instance.onError = (error, stack) {
      logError('PlatformDispatcher unhandled error: $error');
      CrashLog.record(error, stack);
      return true;
    };

    final packageInfo = await PackageInfo.fromPlatform();
    AppConstants.appVersion = packageInfo.version;

    await HomeWidgetManager.init();
    ReviewService.recordLaunch();

    runApp(const ProviderScope(child: ScyphomoteApp()));
  }, (error, stackTrace) {
    logError('Uncaught async error: $error');
    CrashLog.record(error, stackTrace);
  });
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
    if (HomeWidgetManager.isWidgetSupported) {
      _checkForWidgetLaunch();
      _widgetSubscription = HomeWidget.widgetClicked.listen((Uri? uri) {
        if (uri != null) {
          _handleWidgetLaunch(uri);
        }
      });
    }
  }

  Future<void> _checkForWidgetLaunch() async {
    if (!HomeWidgetManager.isWidgetSupported) return;
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
    // Pre-resolve all localized strings before any async work
    final ctx = AppConstants.navigatorKey.currentContext;
    if (ctx == null) return;
    final l10n = AppLocalizations.of(ctx)!;
    final msgPleaseLogin = l10n.pleaseLogInFirst;
    final msgNotFound = l10n.sessionNotFoundOrOffline;
    final msgLaunched = l10n.launchedFromRemoteWidget;

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
          UiUtils.showSnackBar(
            AppConstants.navigatorKey.currentContext,
            msgPleaseLogin,
          );
          return;
        }

        final sessionNotifier = ref.read(sessionProvider.notifier);

        var session = ref
            .read(sessionProvider)
            .sessions
            .where((s) => s.sessionId == sessionId)
            .firstOrNull;

        if (session == null) {
          await sessionNotifier.fetchSessions();
          session = ref
              .read(sessionProvider)
              .sessions
              .where((s) => s.sessionId == sessionId)
              .firstOrNull;
        }

        if (session != null) {
          final navigator = AppConstants.navigatorKey.currentState;
          if (navigator != null) {
            bool hasRemoteScreen = false;
            navigator.popUntil((route) {
              if (route.settings.name == RemoteControlScreen.routeName) {
                hasRemoteScreen = true;
                return true;
              }
              return route.isFirst;
            });

            sessionNotifier.selectSession(session);

            if (!hasRemoteScreen) {
              await navigator.pushNamed(RemoteControlScreen.routeName);
              sessionNotifier.deselectSession();
            }
          } else {
            sessionNotifier.selectSession(session);
          }
        } else {
          UiUtils.showSnackBar(
            AppConstants.navigatorKey.currentContext,
            msgNotFound,
          );
        }
      } else {
        UiUtils.showSnackBar(
          AppConstants.navigatorKey.currentContext,
          msgLaunched,
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
      if (AppConstants.isInForeground) {
        AppConstants.isInForeground = false;
        ref.read(sessionProvider.notifier).refreshSessionPolling();
      }
      messenger?.clearSnackBars();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb && Platform.isAndroid) {
      MediaControlService().init(ref);
    }

    ref.listen(authProvider, (previous, next) {
      if (!kIsWeb && Platform.isAndroid) {
        final settings = ref.read(settingsProvider);
        final user = next.currentUser;
        SessionNotificationService().setEnabled(
          user != null && settings.backgroundMonitoringEnabled,
          user: user,
        );
      }
    });

    ref.listen(settingsProvider, (previous, next) {
      if (!kIsWeb && Platform.isAndroid) {
        final user = ref.read(authProvider).currentUser;
        SessionNotificationService().setEnabled(
          user != null && next.backgroundMonitoringEnabled,
          user: user,
        );
      }
    });

    final authState = ref.watch(authProvider);
    final themeMode = ref.watch(themeProvider);
    final locale = ref.watch(localeProvider);
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
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: locale,
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
      home: switch ((isLoading, authState.currentUser != null)) {
        (true, _) => const LoadingScreen(),
        (false, true) => const DeviceListScreen(),
        (false, false) => const LoginScreen(),
      },
      routes: {
        RemoteControlScreen.routeName: (context) => const RemoteControlScreen(),
        SettingsScreen.routeName: (context) => const SettingsScreen(),
        AboutScreen.routeName: (context) => const AboutScreen(),
        PremiumScreen.routeName: (context) => const PremiumScreen(),
        CrashLogScreen.routeName: (context) => const CrashLogScreen(),
      },
    );
  }
}
