import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/user_account.dart';

class StorageService {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  static const String _usersKey = 'jellyfin_users';
  static const String _activeUserKey = 'active_user_id';
  static const String _deviceIdKey = 'device_id';
  static const String _themeModeKey = 'theme_mode';
  static const String _musicViewModeKey = 'music_view_mode';
  static const String _browseSortByKey = 'browse_sort_by';
  static const String _browseSortOrderKey = 'browse_sort_order';
  static const String _libraryItemsPerRowKey = 'library_items_per_row';
  static const String _hideOtherUsersSessionsKey = 'hide_other_users_sessions';
  static const String _showNonMediaCapableSessionsKey = 'show_non_media_capable_sessions';
  static const String _connectionTimeoutKey = 'connection_timeout';
  static const String _castAndCrewExpandedKey = 'cast_and_crew_expanded';
  static const String _externalLinksExpandedKey = 'external_links_expanded';
  static const String _useVolumeToolbarKey = 'use_volume_toolbar';

  Future<void> saveUser(UserAccount user) async {
    final users = await getUsers();
    users.removeWhere((u) => u.userId == user.userId);
    users.add(user);

    final usersJson = users.map((u) => u.toJson()).toList();
    await _storage.write(key: _usersKey, value: jsonEncode(usersJson));
  }

  Future<List<UserAccount>> getUsers() async {
    final usersJson = await _storage.read(key: _usersKey);
    if (usersJson == null) return [];

    final List<dynamic> decoded = jsonDecode(usersJson);
    return decoded
        .map((json) => UserAccount.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  Future<void> deleteUser(String userId) async {
    final users = await getUsers();
    users.removeWhere((u) => u.userId == userId);

    final usersJson = users.map((u) => u.toJson()).toList();
    await _storage.write(key: _usersKey, value: jsonEncode(usersJson));

    final activeUser = await getActiveUser();
    if (activeUser?.userId == userId) {
      await _storage.delete(key: _activeUserKey);
    }
  }

  Future<void> setActiveUser(String userId) async {
    await _storage.write(key: _activeUserKey, value: userId);
  }

  Future<UserAccount?> getActiveUser() async {
    final activeUserId = await _storage.read(key: _activeUserKey);
    if (activeUserId == null) return null;

    final users = await getUsers();
    try {
      return users.firstWhere((u) => u.userId == activeUserId);
    } catch (e) {
      return null;
    }
  }

  Future<String?> getDeviceId() async {
    return await _storage.read(key: _deviceIdKey);
  }

  Future<void> saveDeviceId(String deviceId) async {
    await _storage.write(key: _deviceIdKey, value: deviceId);
  }

  Future<void> clearAll() async {
    await _storage.deleteAll();
  }

  Future<String?> getThemeMode() async {
    return await _storage.read(key: _themeModeKey);
  }

  Future<void> saveThemeMode(String mode) async {
    await _storage.write(key: _themeModeKey, value: mode);
  }

  Future<String?> getMusicViewMode() async {
    return await _storage.read(key: _musicViewModeKey);
  }

  Future<void> saveMusicViewMode(String mode) async {
    await _storage.write(key: _musicViewModeKey, value: mode);
  }

  Future<String?> getBrowseSortBy() async {
    return await _storage.read(key: _browseSortByKey);
  }

  Future<void> saveBrowseSortBy(String sortBy) async {
    await _storage.write(key: _browseSortByKey, value: sortBy);
  }

  Future<String?> getBrowseSortOrder() async {
    return await _storage.read(key: _browseSortOrderKey);
  }

  Future<void> saveBrowseSortOrder(String sortOrder) async {
    await _storage.write(key: _browseSortOrderKey, value: sortOrder);
  }

  // Refresh Settings
  static const String _playerRefreshRateKey = 'player_refresh_rate';
  static const String _deviceListAutoRefreshKey = 'device_list_auto_refresh';
  static const String _deviceListRefreshRateKey = 'device_list_refresh_rate';

  Future<int?> getPlayerRefreshRate() async {
    final val = await _storage.read(key: _playerRefreshRateKey);
    return val != null ? int.tryParse(val) : null;
  }

  Future<void> savePlayerRefreshRate(int seconds) async {
    await _storage.write(key: _playerRefreshRateKey, value: seconds.toString());
  }

  Future<bool?> getDeviceListAutoRefresh() async {
    final val = await _storage.read(key: _deviceListAutoRefreshKey);
    return val != null ? val == 'true' : null;
  }

  Future<void> saveDeviceListAutoRefresh(bool enabled) async {
    await _storage.write(
      key: _deviceListAutoRefreshKey,
      value: enabled.toString(),
    );
  }

  Future<int?> getDeviceListRefreshRate() async {
    final val = await _storage.read(key: _deviceListRefreshRateKey);
    return val != null ? int.tryParse(val) : null;
  }

  Future<void> saveDeviceListRefreshRate(int seconds) async {
    await _storage.write(
      key: _deviceListRefreshRateKey,
      value: seconds.toString(),
    );
  }

  Future<bool?> getUseVolumeToolbar() async {
    final val = await _storage.read(key: _useVolumeToolbarKey);
    return val != null ? val == 'true' : null;
  }

  Future<void> saveUseVolumeToolbar(bool enabled) async {
    await _storage.write(
      key: _useVolumeToolbarKey,
      value: enabled.toString(),
    );
  }

  Future<int?> getLibraryItemsPerRow() async {
    final val = await _storage.read(key: _libraryItemsPerRowKey);
    return val != null ? int.tryParse(val) : null;
  }

  Future<void> saveLibraryItemsPerRow(int count) async {
    await _storage.write(key: _libraryItemsPerRowKey, value: count.toString());
  }

  Future<bool?> getHideOtherUsersSessions() async {
    final val = await _storage.read(key: _hideOtherUsersSessionsKey);
    return val == null ? null : val == 'true';
  }

  Future<void> saveHideOtherUsersSessions(bool hide) async {
    await _storage.write(
      key: _hideOtherUsersSessionsKey,
      value: hide.toString(),
    );
  }

  Future<bool?> getShowNonMediaCapableSessions() async {
    final val = await _storage.read(key: _showNonMediaCapableSessionsKey);
    return val == null ? null : val == 'true';
  }

  Future<void> saveShowNonMediaCapableSessions(bool show) async {
    await _storage.write(
      key: _showNonMediaCapableSessionsKey,
      value: show.toString(),
    );
  }

  // Locale
  static const String _localeKey = 'locale';

  Future<String?> getLocale() async {
    return await _storage.read(key: _localeKey);
  }

  Future<void> saveLocale(String? localeCode) async {
    if (localeCode == null) {
      await _storage.delete(key: _localeKey);
    } else {
      await _storage.write(key: _localeKey, value: localeCode);
    }
  }

  Future<int?> getConnectionTimeout() async {
    final val = await _storage.read(key: _connectionTimeoutKey);
    return val != null ? int.tryParse(val) : null;
  }

  Future<void> saveConnectionTimeout(int seconds) async {
    await _storage.write(key: _connectionTimeoutKey, value: seconds.toString());
  }

  Future<bool?> getCastAndCrewExpanded() async {
    final val = await _storage.read(key: _castAndCrewExpandedKey);
    return val == null ? null : val == 'true';
  }

  Future<void> saveCastAndCrewExpanded(bool expanded) async {
    await _storage.write(
      key: _castAndCrewExpandedKey,
      value: expanded.toString(),
    );
  }

  Future<bool?> getExternalLinksExpanded() async {
    final val = await _storage.read(key: _externalLinksExpandedKey);
    return val == null ? null : val == 'true';
  }

  Future<void> saveExternalLinksExpanded(bool expanded) async {
    await _storage.write(
      key: _externalLinksExpandedKey,
      value: expanded.toString(),
    );
  }
}
