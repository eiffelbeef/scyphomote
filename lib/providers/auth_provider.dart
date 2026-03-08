import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_account.dart';
import '../services/storage_service.dart';
import '../services/jellyfin_api_service.dart';
import '../constants.dart';
import 'package:uuid/uuid.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';
import '../utils/logger.dart';
import '../widgets/home_widget_manager.dart';

final storageServiceProvider = Provider((ref) => StorageService());
final apiServiceProvider = Provider((ref) => JellyfinApiService());

class AuthState {
  final UserAccount? currentUser;
  final List<UserAccount> users;
  final bool isLoading;
  final String? error;

  AuthState({
    this.currentUser,
    this.users = const [],
    this.isLoading = false,
    this.error,
  });

  AuthState copyWith({
    UserAccount? currentUser,
    List<UserAccount>? users,
    bool? isLoading,
    String? error,
  }) {
    return AuthState(
      currentUser: currentUser ?? this.currentUser,
      users: users ?? this.users,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class AuthNotifier extends Notifier<AuthState> {
  late StorageService _storageService;
  late JellyfinApiService _apiService;

  @override
  AuthState build() {
    _storageService = ref.watch(storageServiceProvider);
    _apiService = ref.watch(apiServiceProvider);
    Future.microtask(() => _loadUsers());
    return AuthState(isLoading: true);
  }

  Future<void> _loadUsers() async {
    state = state.copyWith(isLoading: true);
    try {
      // Ensure we have a persistent device ID
      String? deviceId = await _storageService.getDeviceId();
      if (deviceId == null) {
        deviceId = const Uuid().v4();
        await _storageService.saveDeviceId(deviceId);
      }
      _apiService.setDeviceId(deviceId);

      final deviceInfo = DeviceInfoPlugin();
      String deviceName = AppConstants.appName;
      try {
        if (kIsWeb) {
          final webInfo = await deviceInfo.webBrowserInfo;
          deviceName = 'Web (${webInfo.browserName.name})';
        } else if (Platform.isAndroid) {
          final androidInfo = await deviceInfo.androidInfo;
          //deviceName = '${androidInfo.manufacturer} ${androidInfo.model}';
          deviceName = androidInfo.name;
        } else if (Platform.isIOS) {
          final iosInfo = await deviceInfo.iosInfo;
          deviceName = iosInfo.name;
        } else if (Platform.isLinux) {
          deviceName = Platform.localHostname;
        } else if (Platform.isMacOS) {
          final macInfo = await deviceInfo.macOsInfo;
          deviceName = macInfo.computerName;
        } else if (Platform.isWindows) {
          final windowsInfo = await deviceInfo.windowsInfo;
          deviceName = windowsInfo.computerName;
        }
      } catch (e) {
        logError('Failed to get device name: $e');
      }
      _apiService.setDeviceName(deviceName);

      final users = await _storageService.getUsers();
      final activeUser = await _storageService.getActiveUser();
      if (activeUser != null) {
        _apiService.setCredentials(
          activeUser.serverUrl,
          activeUser.accessToken,
        );
        HomeWidgetManager.saveSettingsToWidget(
          activeUser.serverUrl,
          activeUser.accessToken,
        );
      }
      state = AuthState(
        currentUser: activeUser,
        users: users,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to load users: $e',
      );
    }
  }

  Future<void> login(
    String serverUrl,
    String username,
    String password, {
    bool persist = true,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final authenticatedUser = await _apiService.authenticate(
        serverUrl,
        username,
        password,
      );

      _apiService.setCredentials(
        authenticatedUser.serverUrl,
        authenticatedUser.accessToken,
      );
      HomeWidgetManager.saveSettingsToWidget(
        authenticatedUser.serverUrl,
        authenticatedUser.accessToken,
      );

      final profileImageBase64 = await _apiService.downloadUserImage(
        authenticatedUser.userId,
      );

      final user = UserAccount(
        userId: authenticatedUser.userId,
        username: authenticatedUser.username,
        serverUrl: authenticatedUser.serverUrl,
        accessToken: authenticatedUser.accessToken,
        serverId: authenticatedUser.serverId,
        profileImageBase64: profileImageBase64,
      );

      if (persist) {
        await _storageService.saveUser(user);
        await _storageService.setActiveUser(user.userId);
      }

      final users = await _storageService.getUsers();
      state = AuthState(currentUser: user, users: users, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'Login failed: $e');
    }
  }

  Future<void> switchUser(String userId) async {
    final user = state.users.firstWhere((u) => u.userId == userId);
    await _storageService.setActiveUser(userId);
    _apiService.setCredentials(user.serverUrl, user.accessToken);
    await HomeWidgetManager.saveSettingsToWidget(
      user.serverUrl,
      user.accessToken,
    );
    state = state.copyWith(currentUser: user);
  }

  Future<void> deleteUser(String userId) async {
    await _storageService.deleteUser(userId);
    final users = await _storageService.getUsers();

    if (state.currentUser?.userId == userId) {
      final newActiveUser = users.isNotEmpty ? users.first : null;
      if (newActiveUser != null) {
        await _storageService.setActiveUser(newActiveUser.userId);
      }
      state = AuthState(currentUser: newActiveUser, users: users);
    } else {
      state = state.copyWith(users: users);
    }
  }

  Future<void> logout() async {
    if (state.currentUser != null) {
      await _storageService.deleteUser(state.currentUser!.userId);
    }
    final users = await _storageService.getUsers();
    final newActiveUser = users.isNotEmpty ? users.first : null;
    if (newActiveUser != null) {
      await _storageService.setActiveUser(newActiveUser.userId);
      _apiService.setCredentials(
        newActiveUser.serverUrl,
        newActiveUser.accessToken,
      );
      await HomeWidgetManager.saveSettingsToWidget(
        newActiveUser.serverUrl,
        newActiveUser.accessToken,
      );
    } else {
      _apiService.clearCredentials();
    }
    state = AuthState(currentUser: newActiveUser, users: users);
  }
}

final authProvider = NotifierProvider<AuthNotifier, AuthState>(
  AuthNotifier.new,
);
