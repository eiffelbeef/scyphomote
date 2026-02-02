import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'screens/login_screen.dart';
import 'screens/device_list_screen.dart';
import 'screens/remote_control/remote_control_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/about_screen.dart';
import 'providers/auth_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/session_provider.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'constants.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final packageInfo = await PackageInfo.fromPlatform();
  AppConstants.appVersion = packageInfo.version;

  runApp(const ProviderScope(child: ScyphomoteApp()));
}

class ScyphomoteApp extends ConsumerStatefulWidget {
  const ScyphomoteApp({super.key});

  @override
  ConsumerState<ScyphomoteApp> createState() => _ScyphomoteAppState();
}

class _ScyphomoteAppState extends ConsumerState<ScyphomoteApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    AppConstants.isInForeground = true;
  }

  @override
  void dispose() {
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
      },
    );
  }
}
