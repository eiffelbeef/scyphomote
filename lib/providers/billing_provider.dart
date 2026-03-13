import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/billing_service.dart';

final billingServiceProvider = Provider<BillingService>((ref) {
  final service = BillingService();
  ref.onDispose(() => service.dispose());
  return service;
});

class IsPremiumNotifier extends Notifier<bool> {
  late BillingService _billingService;

  @override
  bool build() {
    _billingService = ref.watch(billingServiceProvider);
    // Initialize async state tracking but return default first
    _init();
    return _billingService.isPremium;
  }

  Future<void> _init() async {
    await _billingService.initialize();
    state = _billingService.isPremium;
  }

  Future<void> buyPremium() async {
    await _billingService.buyPremium();
    // Assuming UI takes care of listening to stream if we added it,
    // or we just trust the service updates it.
  }

  Future<void> setPremium(bool value) async {
    await _billingService.setPremiumLocal(value);
    state = value;
  }
}

final isPremiumProvider = NotifierProvider<IsPremiumNotifier, bool>(
  IsPremiumNotifier.new,
);
