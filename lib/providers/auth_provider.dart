import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_account.dart';
import '../services/storage_service.dart';
import '../services/jellyfin_api_service.dart';
import '../services/emby_api_service.dart';
import '../constants.dart';
import 'package:uuid/uuid.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';
import '../utils/logger.dart';
import 'settings_provider.dart';

final storageServiceProvider = Provider((ref) => StorageService());
final apiServiceProvider = Provider((ref) {
  final service = JellyfinApiService();
  ref.listen(settingsProvider, (prev, next) {
    if (prev?.connectionTimeout != next.connectionTimeout) {
      service.setConnectTimeout(next.connectionTimeout);
    }
  });
  final settings = ref.read(settingsProvider);
  service.setConnectTimeout(settings.connectionTimeout);
  return service;
});

final embyApiServiceProvider = Provider((ref) => EmbyApiService());

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
  late EmbyApiService _embyApiService;

  @override
  AuthState build() {
    _storageService = ref.watch(storageServiceProvider);
    _apiService = ref.watch(apiServiceProvider);
    _embyApiService = ref.watch(embyApiServiceProvider);
    _apiService.onUrlUpdated = (newUrl, systemId) async {
      try {
        final targetEmbyUser = state.users.firstWhere((u) => u.embySystemId == systemId);
        final updatedEmbyUser = targetEmbyUser.copyWith(serverUrl: newUrl);
        
        await _storageService.saveUser(updatedEmbyUser);
        final users = await _storageService.getUsers();
        
        if (state.currentUser?.embySystemId == systemId) {
          state = state.copyWith(currentUser: updatedEmbyUser, users: users);
        } else {
          state = state.copyWith(users: users);
        }
      } catch (e) {
        logError('Failed to update Emby Connect url for system $systemId: $e');
      }
    };
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
        } else {
          if (Platform.isAndroid) {
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
          embyConnectAccessToken: activeUser.embyConnectAccessToken,
          embyConnectUserId: activeUser.embyConnectUserId,
          embySystemId: activeUser.embySystemId,
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


  Future<List<Map<String, dynamic>>> loginWithEmbyConnect(String username, String password) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final creds = await _embyApiService.authenticateEmbyConnect(username, password);
      final servers = await _embyApiService.getEmbyConnectServers(creds['ConnectUserId']!, creds['ConnectAccessToken']!);
      state = state.copyWith(isLoading: false);
      return servers.map((s) => {...s, '_embyConnectUserId': creds['ConnectUserId'], '_embyConnectAccessToken': creds['ConnectAccessToken']}).toList();
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'Emby Connect login failed: $e');
      rethrow;
    }
  }

  Future<void> completeEmbyConnectLogin(Map<String, dynamic> server, {bool persist = true}) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final connectUserId = server['_embyConnectUserId'] as String;
      final connectToken = server['_embyConnectAccessToken'] as String;
      final user = await _embyApiService.exchangeEmbyConnectToken(
        server, 
        connectUserId, 
        connectToken,
        _apiService.deviceId,
        _apiService.deviceName,
      );
      
      _apiService.setCredentials(
        user.serverUrl,
        user.accessToken,
        embyConnectAccessToken: user.embyConnectAccessToken,
        embyConnectUserId: user.embyConnectUserId,
        embySystemId: user.embySystemId,
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

      final profileImageBase64 = await _apiService.downloadUserImage(
        authenticatedUser.userId,
      );

      final user = UserAccount(
        userId: authenticatedUser.userId,
        username: authenticatedUser.username,
        serverUrl: authenticatedUser.serverUrl,
        serverName: authenticatedUser.serverName,
        accessToken: authenticatedUser.accessToken,
        serverId: authenticatedUser.serverId,
        profileImageBase64: profileImageBase64,
        isAdmin: authenticatedUser.isAdmin,
        isEmby: authenticatedUser.isEmby,
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
    _apiService.setCredentials(
      user.serverUrl, 
      user.accessToken,
      embyConnectAccessToken: user.embyConnectAccessToken,
      embyConnectUserId: user.embyConnectUserId,
      embySystemId: user.embySystemId,
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
        embyConnectAccessToken: newActiveUser.embyConnectAccessToken,
        embyConnectUserId: newActiveUser.embyConnectUserId,
        embySystemId: newActiveUser.embySystemId,
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
