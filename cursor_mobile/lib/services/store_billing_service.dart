import 'dart:async';

import 'package:in_app_purchase/in_app_purchase.dart';

import 'billing_service.dart';

/// Store-backed billing. Swap in for [StubBillingService] after product IDs and entitlements are implemented.
///
/// Today: [isProActive] stays false until purchase validation is wired to `_pro`.
class StoreBillingService implements BillingService {
  StoreBillingService() {
    _subscription = InAppPurchase.instance.purchaseStream.listen(
      _onPurchases,
      onError: (_) {},
    );
  }

  StreamSubscription<List<PurchaseDetails>>? _subscription;
  bool _pro = false;
  bool _disposed = false;

  void _onPurchases(List<PurchaseDetails> details) {
    for (final d in details) {
      if (d.status == PurchaseStatus.purchased || d.status == PurchaseStatus.restored) {
        // TODO: verify productId matches Mordechaius Pro SKU
        _pro = true;
      }
      if (d.pendingCompletePurchase) {
        InAppPurchase.instance.completePurchase(d);
      }
    }
  }

  @override
  bool get isProActive => _pro;

  @override
  Future<void> refresh() async {
    if (_disposed) return;
    await InAppPurchase.instance.isAvailable();
  }

  @override
  Future<void> restorePurchases() async {
    if (_disposed) return;
    await InAppPurchase.instance.restorePurchases();
  }

  @override
  void dispose() {
    _disposed = true;
    _subscription?.cancel();
    _subscription = null;
  }
}
