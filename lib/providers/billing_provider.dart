import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/billing_service.dart';

final billingServiceProvider = Provider<BillingService>((ref) {
  final service = BillingService();
  ref.onDispose(() => service.dispose());
  return service;
});

class IsPremiumNotifier extends Notifier<bool> {
  late BillingService _billing;

  @override
  bool build() {
    _billing = ref.watch(billingServiceProvider);
    _init();
    return _billing.isPremium;
  }

  Future<void> _init() async {
    await _billing.initialize();
    state = _billing.isPremium;
    // Kick the history provider once billing is ready
    ref.read(supportHistoryProvider.notifier).refresh();
  }

  Future<void> buyPremium() => _billing.buyPremium();

  Future<void> setPremium(bool value) async {
    await _billing.setPremiumLocal(value);
    state = value;
  }
}

final isPremiumProvider = NotifierProvider<IsPremiumNotifier, bool>(
  IsPremiumNotifier.new,
);

class SupportHistoryNotifier extends Notifier<List<String>> {
  @override
  List<String> build() {
    final billing = ref.watch(billingServiceProvider);
    billing.onSupportHistoryChanged = () => refresh();
    return billing.supportHistory;
  }

  void refresh() {
    final billing = ref.read(billingServiceProvider);
    state = billing.supportHistory;
  }

  Future<void> buySupport(String productId) async {
    await ref.read(billingServiceProvider).buySupport(productId);
  }
}

final supportHistoryProvider =
    NotifierProvider<SupportHistoryNotifier, List<String>>(
      SupportHistoryNotifier.new,
    );
