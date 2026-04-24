import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/home_widget_manager.dart';
import '../utils/logger.dart';

class BillingService {
  static const _premiumId = 'scyphomote_premium';
  static const _historyKey = 'support_history';
  static bool get isBillingSupported => !kIsWeb && Platform.isAndroid;

  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _subscription;
  late SharedPreferences _prefs;

  bool _isPremium = false;
  bool get isPremium => _isPremium;

  bool _isAvailable = true;
  bool get isAvailable => _isAvailable;

  List<String> _supportHistory = [];
  List<String> get supportHistory => List.unmodifiable(_supportHistory);
  bool get hasSupported => _supportHistory.isNotEmpty;

  VoidCallback? onSupportHistoryChanged;

  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
    _isPremium = _prefs.getBool('is_premium') ?? false;
    _supportHistory = _prefs.getStringList(_historyKey) ?? [];

    _isAvailable = isBillingSupported && await _iap.isAvailable();
    if (!_isAvailable) {
      logError('In-App Purchases are not available.');
      return;
    }

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

  Future<void> setPremiumLocal(bool value) async {
    await _setPremium(value);
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
