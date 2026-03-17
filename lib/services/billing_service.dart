import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/home_widget_manager.dart';
import '../utils/logger.dart';

class BillingService {
  final InAppPurchase _iap = InAppPurchase.instance;
  final String _premiumProductId = 'scyphomote_premium';

  StreamSubscription<List<PurchaseDetails>>? _subscription;
  late SharedPreferences _prefs;

  bool _isPremium = false;
  bool get isPremium => _isPremium;

  bool _isAvailable = true;
  bool get isAvailable => _isAvailable;

  static bool get isBillingSupported => !kIsWeb && Platform.isAndroid;
  // !kIsWeb && (Platform.isAndroid || Platform.isIOS || Platform.isMacOS);

  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
    _isPremium = _prefs.getBool('is_premium') ?? false;

    _isAvailable = isBillingSupported && await _iap.isAvailable();
    if (!_isAvailable) {
      logError('In-App Purchases are not available.');
      return;
    }

    _subscription = _iap.purchaseStream.listen(
      _listenToPurchaseUpdated,
      onDone: () {
        _subscription?.cancel();
      },
      onError: (error) {
        logError('IAP Stream Error: $error');
      },
    );

    await _iap.restorePurchases();
  }

  void dispose() {
    _subscription?.cancel();
  }

  Future<void> _updatePremiumStatus(bool value) async {
    _isPremium = value;
    await _prefs.setBool('is_premium', value);

    await HomeWidgetManager.syncPremiumStatus(value);
  }

  void _listenToPurchaseUpdated(
    List<PurchaseDetails> purchaseDetailsList,
  ) async {
    for (var purchaseDetails in purchaseDetailsList) {
      if (purchaseDetails.status == PurchaseStatus.purchased ||
          purchaseDetails.status == PurchaseStatus.restored) {
        if (purchaseDetails.productID == _premiumProductId) {
          await _updatePremiumStatus(true);
        }

        if (purchaseDetails.pendingCompletePurchase) {
          await _iap.completePurchase(purchaseDetails);
        }
      } else if (purchaseDetails.status == PurchaseStatus.error) {
        logError('IAP Error: ${purchaseDetails.error}');
      }
    }
  }

  Future<void> buyPremium() async {
    final ProductDetailsResponse response = await _iap.queryProductDetails({
      _premiumProductId,
    });
    if (response.notFoundIDs.isNotEmpty || response.productDetails.isEmpty) {
      logError('Product not found: $_premiumProductId');
      return;
    }

    final PurchaseParam purchaseParam = PurchaseParam(
      productDetails: response.productDetails.first,
    );
    await _iap.buyNonConsumable(purchaseParam: purchaseParam);
  }

  Future<void> setPremiumLocal(bool value) async {
    await _updatePremiumStatus(value);
  }
}
