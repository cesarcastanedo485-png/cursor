import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/entitlements_constants.dart';
import '../services/billing_service.dart';
import '../services/store_billing_service.dart';

/// Injectable billing backend.
///
/// Use [StubBillingService] by default. Set [useStoreBilling] to `true` after
/// configuring Pro SKUs (see [StoreBillingService]).
const bool kUseStoreBilling = false;

/// Injectable billing backend. Replace [StubBillingService] with store-backed impl when ready.
final billingServiceProvider = Provider<BillingService>((ref) {
  final svc = kUseStoreBilling ? StoreBillingService() : StubBillingService();
  ref.onDispose(svc.dispose);
  return svc;
});

/// Effective Pro flag (store or debug stub).
final isProProvider = Provider<bool>((ref) => ref.watch(billingServiceProvider).isProActive);

/// Maximum saved launch presets (unlimited when Pro).
final maxLaunchPresetsProvider = Provider<int>((ref) {
  final pro = ref.watch(isProProvider);
  return pro ? 999 : kMaxLaunchPresetsFreeTier;
});
