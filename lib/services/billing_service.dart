import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/home_widget_manager.dart';
import '../utils/logger.dart';
import 'license_service.dart';

class BillingService {
  static const _premiumId = 'scyphomote_premium';
  static const _historyKey = 'support_history';
  static const _licenseKeyPref = 'license_key';
  static const _playStoreInstaller = 'com.android.vending';
  static bool get isBillingSupported => !kIsWeb && Platform.isAndroid;

  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _subscription;
  late SharedPreferences _prefs;

  bool _isPremium = false;
  bool get isPremium => _isPremium;

  bool _isAvailable = true;
  bool get isAvailable => _isAvailable;

  String? _licensedIdentifier;
  String? get licensedIdentifier => _licensedIdentifier;
  bool get isLicensed => _licensedIdentifier != null;

  List<String> _supportHistory = [];
  List<String> get supportHistory => List.unmodifiable(_supportHistory);
  bool get hasSupported => _supportHistory.isNotEmpty;

  VoidCallback? onSupportHistoryChanged;
  VoidCallback? onPremiumChanged;

  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();

    final savedLicense = _prefs.getString(_licenseKeyPref);
    if (savedLicense != null &&
        savedLicense.isNotEmpty &&
        await LicenseService.verifyKey(savedLicense)) {
      _licensedIdentifier = LicenseService.extractIdentifier(savedLicense);
      _isPremium = true;
    } else {
      if (savedLicense != null) await _prefs.remove(_licenseKeyPref);
      _isPremium = kDebugMode && (_prefs.getBool('is_premium') ?? false);
    }

    _supportHistory = _prefs.getStringList(_historyKey) ?? [];

    if (isBillingSupported) {
      final info = await PackageInfo.fromPlatform();
      _isAvailable = info.installerStore == _playStoreInstaller &&
          await _iap.isAvailable();
    } else {
      _isAvailable = false;
    }

    if (!_isAvailable) return;

    _subscription = _iap.purchaseStream.listen(
      _onPurchaseUpdated,
      onDone: () => _subscription?.cancel(),
      onError: (error) => logError('IAP Stream Error: $error'),
    );

    await _iap.restorePurchases();
  }

  void dispose() {
    _subscription?.cancel();
  }

  Future<void> buyPremium() => _buy(_premiumId, consumable: false);

  Future<void> buySupport(String productId) =>
      _buy(productId, consumable: true);

  Future<void> setPremiumLocal(bool value) => _setPremium(value);

  Future<bool> activateLicense(String licenseKey) async {
    final isValid = await LicenseService.verifyKey(licenseKey);
    if (!isValid) return false;

    await _prefs.setString(_licenseKeyPref, licenseKey.trim());
    _licensedIdentifier = LicenseService.extractIdentifier(licenseKey);
    await _setPremium(true);
    return true;
  }

  Future<void> removeLicense() async {
    await _prefs.remove(_licenseKeyPref);
    _licensedIdentifier = null;
    await _setPremium(false);
  }

  Future<void> _buy(String productId, {required bool consumable}) async {
    final response = await _iap.queryProductDetails({productId});
    if (response.notFoundIDs.isNotEmpty || response.productDetails.isEmpty) {
      logError('Product not found: $productId');
      return;
    }
    final param = PurchaseParam(productDetails: response.productDetails.first);
    if (consumable) {
      await _iap.buyConsumable(purchaseParam: param, autoConsume: true);
    } else {
      await _iap.buyNonConsumable(purchaseParam: param);
    }
  }

  Future<void> _setPremium(bool value) async {
    _isPremium = value;
    await _prefs.setBool('is_premium', value);
    await HomeWidgetManager.syncPremiumStatus(value);
    onPremiumChanged?.call();
  }

  Future<void> _recordSupport(String productId) async {
    final entry = jsonEncode({
      'product': productId,
      'date': DateTime.now().toIso8601String(),
    });
    _supportHistory.add(entry);
    await _prefs.setStringList(_historyKey, _supportHistory);
    onSupportHistoryChanged?.call();
  }

  void _onPurchaseUpdated(List<PurchaseDetails> list) async {
    for (final p in list) {
      if (p.status == PurchaseStatus.purchased ||
          p.status == PurchaseStatus.restored) {
        if (p.productID == _premiumId) {
          await _setPremium(true);
        } else if (p.productID.startsWith('scyphomote_support')) {
          await _recordSupport(p.productID);
        }
        if (p.pendingCompletePurchase) {
          await _iap.completePurchase(p);
        }
      } else if (p.status == PurchaseStatus.error) {
        logError('IAP Error: ${p.error}');
      }
    }
  }
}
