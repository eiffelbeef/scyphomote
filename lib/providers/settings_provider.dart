import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'auth_provider.dart';
import '../services/storage_service.dart';

class SettingsState {
  final int playerRefreshRate;
  final bool deviceListAutoRefresh;
  final int deviceListRefreshRate;
  final int libraryItemsPerRow;
  final bool hideOtherUsersSessions;

  SettingsState({
    this.playerRefreshRate = 10,
    this.deviceListAutoRefresh = true,
    this.deviceListRefreshRate = 10,
    this.libraryItemsPerRow = 2,
    this.hideOtherUsersSessions = false,
  });

  SettingsState copyWith({
    int? playerRefreshRate,
    bool? deviceListAutoRefresh,
    int? deviceListRefreshRate,
    int? libraryItemsPerRow,
    bool? hideOtherUsersSessions,
  }) {
    return SettingsState(
      playerRefreshRate: playerRefreshRate ?? this.playerRefreshRate,
      deviceListAutoRefresh:
          deviceListAutoRefresh ?? this.deviceListAutoRefresh,
      deviceListRefreshRate:
          deviceListRefreshRate ?? this.deviceListRefreshRate,
      libraryItemsPerRow: libraryItemsPerRow ?? this.libraryItemsPerRow,
      hideOtherUsersSessions:
          hideOtherUsersSessions ?? this.hideOtherUsersSessions,
    );
  }
}

class SettingsNotifier extends Notifier<SettingsState> {
  late StorageService _storageService;

  @override
  SettingsState build() {
    _storageService = ref.watch(storageServiceProvider);
    // Load settings asynchronously
    Future.microtask(() => _loadSettings());
    return SettingsState();
  }

  Future<void> _loadSettings() async {
    final playerRate = await _storageService.getPlayerRefreshRate();
    final autoRefresh = await _storageService.getDeviceListAutoRefresh();
    final listRate = await _storageService.getDeviceListRefreshRate();
    final itemsPerRow = await _storageService.getLibraryItemsPerRow();
    final hideSessions = await _storageService.getHideOtherUsersSessions();

    state = SettingsState(
      playerRefreshRate: playerRate ?? 10,
      deviceListAutoRefresh: autoRefresh ?? true,
      deviceListRefreshRate: listRate ?? 10,
      libraryItemsPerRow: itemsPerRow ?? 2,
      hideOtherUsersSessions: hideSessions ?? false,
    );
  }

  Future<void> setPlayerRefreshRate(int rate) async {
    state = state.copyWith(playerRefreshRate: rate);
    await _storageService.savePlayerRefreshRate(rate);
  }

  Future<void> setDeviceListAutoRefresh(bool enabled) async {
    state = state.copyWith(deviceListAutoRefresh: enabled);
    await _storageService.saveDeviceListAutoRefresh(enabled);
  }

  Future<void> setDeviceListRefreshRate(int rate) async {
    state = state.copyWith(deviceListRefreshRate: rate);
    await _storageService.saveDeviceListRefreshRate(rate);
  }

  Future<void> setLibraryItemsPerRow(int count) async {
    state = state.copyWith(libraryItemsPerRow: count);
    await _storageService.saveLibraryItemsPerRow(count);
  }

  Future<void> setHideOtherUsersSessions(bool hide) async {
    state = state.copyWith(hideOtherUsersSessions: hide);
    await _storageService.saveHideOtherUsersSessions(hide);
  }
}

final settingsProvider = NotifierProvider<SettingsNotifier, SettingsState>(
  SettingsNotifier.new,
);
