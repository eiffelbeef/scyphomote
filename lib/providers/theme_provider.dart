import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'auth_provider.dart';
import '../services/storage_service.dart';

class ThemeNotifier extends Notifier<ThemeMode> {
  late StorageService _storageService;

  @override
  ThemeMode build() {
    _storageService = ref.watch(storageServiceProvider);
    _loadTheme();
    return ThemeMode.system;
  }

  Future<void> _loadTheme() async {
    final savedMode = await _storageService.getThemeMode();
    if (savedMode != null) {
      state = _parseThemeMode(savedMode);
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = mode;
    await _storageService.saveThemeMode(mode.name);
  }

  ThemeMode _parseThemeMode(String name) {
    return ThemeMode.values.firstWhere(
      (m) => m.name == name,
      orElse: () => ThemeMode.system,
    );
  }
}

final themeProvider = NotifierProvider<ThemeNotifier, ThemeMode>(
  ThemeNotifier.new,
);
