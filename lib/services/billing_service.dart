import 'dart:async';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:home_widget/home_widget.dart';
import '../utils/logger.dart';

class BillingService {
  final InAppPurchase _iap = InAppPurchase.instance;
  final String _premiumProductId = 'scyphomote_premium';

  StreamSubscription<List<PurchaseDetails>>? _subscription;

  bool _isPremium = false;
  bool get isPremium => _isPremium;

  Future<void> initialize() async {
    final available = await _iap.isAvailable();
    if (!available) {
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

    _isPremium = await HomeWidget.getWidgetData<bool>('is_premium') ?? false;

    await _iap.restorePurchases();
  }

  void dispose() {
    _subscription?.cancel();
  }

  void _listenToPurchaseUpdated(
    List<PurchaseDetails> purchaseDetailsList,
  ) async {
    for (var purchaseDetails in purchaseDetailsList) {
      if (purchaseDetails.status == PurchaseStatus.purchased ||
          purchaseDetails.status == PurchaseStatus.restored) {
        if (purchaseDetails.productID == _premiumProductId) {
          _isPremium = true;
          await HomeWidget.saveWidgetData<bool>('is_premium', true);
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
    _isPremium = value;
    await HomeWidget.saveWidgetData<bool>('is_premium', value);
  }
}
