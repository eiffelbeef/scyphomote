import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'auth_provider.dart';
import '../services/storage_service.dart';

class SettingsState {
  final int playerRefreshRate;
  final bool deviceListAutoRefresh;
  final int deviceListRefreshRate;
  final int libraryItemsPerRow;
  final bool hideOtherUsersSessions;
  final bool showNonMediaCapableSessions;
  final int connectionTimeout;
  final bool castAndCrewExpanded;
  final bool externalLinksExpanded;
  final bool useVolumeToolbar;

  SettingsState({
    this.playerRefreshRate = 10,
    this.deviceListAutoRefresh = true,
    this.deviceListRefreshRate = 10,
    this.libraryItemsPerRow = 2,
    this.hideOtherUsersSessions = false,
    this.showNonMediaCapableSessions = false,
    this.connectionTimeout = 30,
    this.castAndCrewExpanded = true,
    this.externalLinksExpanded = true,
    this.useVolumeToolbar = false,
  });

  SettingsState copyWith({
    int? playerRefreshRate,
    bool? deviceListAutoRefresh,
    int? deviceListRefreshRate,
    int? libraryItemsPerRow,
    bool? hideOtherUsersSessions,
    bool? showNonMediaCapableSessions,
    int? connectionTimeout,
    bool? castAndCrewExpanded,
    bool? externalLinksExpanded,
    bool? useVolumeToolbar,
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
      showNonMediaCapableSessions:
          showNonMediaCapableSessions ?? this.showNonMediaCapableSessions,
      connectionTimeout: connectionTimeout ?? this.connectionTimeout,
      castAndCrewExpanded: castAndCrewExpanded ?? this.castAndCrewExpanded,
      externalLinksExpanded: externalLinksExpanded ?? this.externalLinksExpanded,
      useVolumeToolbar: useVolumeToolbar ?? this.useVolumeToolbar,
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
    final showNonMediaCapable =
        await _storageService.getShowNonMediaCapableSessions();
    final connectionTimeout = await _storageService.getConnectionTimeout();
    final castAndCrewExp = await _storageService.getCastAndCrewExpanded();
    final externalLinksExp = await _storageService.getExternalLinksExpanded();
    final useVolToolbar = await _storageService.getUseVolumeToolbar();

    state = SettingsState(
      playerRefreshRate: playerRate ?? 10,
      deviceListAutoRefresh: autoRefresh ?? true,
      deviceListRefreshRate: listRate ?? 10,
      libraryItemsPerRow: itemsPerRow ?? 2,
      hideOtherUsersSessions: hideSessions ?? false,
      showNonMediaCapableSessions: showNonMediaCapable ?? false,
      connectionTimeout: connectionTimeout ?? 30,
      castAndCrewExpanded: castAndCrewExp ?? true,
      externalLinksExpanded: externalLinksExp ?? true,
      useVolumeToolbar: useVolToolbar ?? false,
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

  Future<void> setShowNonMediaCapableSessions(bool show) async {
    state = state.copyWith(showNonMediaCapableSessions: show);
    await _storageService.saveShowNonMediaCapableSessions(show);
  }

  Future<void> setConnectionTimeout(int seconds) async {
    state = state.copyWith(connectionTimeout: seconds);
    await _storageService.saveConnectionTimeout(seconds);
  }

  Future<void> setCastAndCrewExpanded(bool expanded) async {
    state = state.copyWith(castAndCrewExpanded: expanded);
    await _storageService.saveCastAndCrewExpanded(expanded);
  }

  Future<void> setExternalLinksExpanded(bool expanded) async {
    state = state.copyWith(externalLinksExpanded: expanded);
    await _storageService.saveExternalLinksExpanded(expanded);
  }

  Future<void> setUseVolumeToolbar(bool useToolbar) async {
    state = state.copyWith(useVolumeToolbar: useToolbar);
    await _storageService.saveUseVolumeToolbar(useToolbar);
  }
}

final settingsProvider = NotifierProvider<SettingsNotifier, SettingsState>(
  SettingsNotifier.new,
);
