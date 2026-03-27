import 'package:flutter/foundation.dart';

/// Play Billing / App Store integration replaces [StubBillingService] in production.
abstract class BillingService {
  /// Whether the user has an active Pro entitlement (subscription or lifetime).
  bool get isProActive;

  /// Refresh entitlements from the store (no-op on stub).
  Future<void> refresh();

  /// Restore purchases (no-op on stub).
  Future<void> restorePurchases();

  void dispose();
}

/// Default until store SKUs are configured. [debugForcePro] enables testing Pro gates.
class StubBillingService implements BillingService {
  StubBillingService({this.debugForcePro = false});

  /// Set `true` in debug builds to verify Pro-only UI without a store.
  final bool debugForcePro;

  @override
  bool get isProActive => kDebugMode && debugForcePro;

  @override
  Future<void> refresh() async {}

  @override
  Future<void> restorePurchases() async {}

  @override
  void dispose() {}
}
