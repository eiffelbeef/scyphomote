import 'dart:ui';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'auth_provider.dart';
import '../services/storage_service.dart';

class LocaleNotifier extends Notifier<Locale?> {
  late StorageService _storageService;

  @override
  Locale? build() {
    _storageService = ref.watch(storageServiceProvider);
    Future.microtask(() => _loadLocale());
    return null; // null = system default
  }

  Future<void> _loadLocale() async {
    final code = await _storageService.getLocale();
    if (code != null) {
      state = Locale(code);
    }
  }

  Future<void> setLocale(Locale? locale) async {
    state = locale;
    await _storageService.saveLocale(locale?.languageCode);
  }
}

final localeProvider = NotifierProvider<LocaleNotifier, Locale?>(
  LocaleNotifier.new,
);
