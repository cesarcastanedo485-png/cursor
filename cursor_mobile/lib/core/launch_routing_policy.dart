enum LaunchRoutePath { desktop, cloud }

class LaunchRouteDecision {
  const LaunchRouteDecision({
    required this.path,
    required this.reason,
    this.cooldownBlocked = false,
  });

  final LaunchRoutePath path;
  final String reason;
  final bool cooldownBlocked;
}

class LaunchRoutingPolicy {
  const LaunchRoutingPolicy._();

  static const int cooldownMs = 1200;
  static const int desktopRetryBudget = 2;

  static bool isCooldownBlocked({
    required int? lastLaunchAtMs,
    required int nowMs,
  }) {
    if (lastLaunchAtMs == null) return false;
    return (nowMs - lastLaunchAtMs) < cooldownMs;
  }

  static LaunchRouteDecision decide({
    required bool preferDesktop,
    required bool hasBridgeService,
    required bool bridgeReady,
    required int? lastLaunchAtMs,
    required int nowMs,
  }) {
    if (isCooldownBlocked(lastLaunchAtMs: lastLaunchAtMs, nowMs: nowMs)) {
      return const LaunchRouteDecision(
        path: LaunchRoutePath.cloud,
        reason: 'cooldown_blocked',
        cooldownBlocked: true,
      );
    }
    if (!preferDesktop) {
      return const LaunchRouteDecision(
        path: LaunchRoutePath.cloud,
        reason: 'desktop_disabled',
      );
    }
    if (!hasBridgeService) {
      return const LaunchRouteDecision(
        path: LaunchRoutePath.cloud,
        reason: 'bridge_not_configured',
      );
    }
    if (!bridgeReady) {
      return const LaunchRouteDecision(
        path: LaunchRoutePath.cloud,
        reason: 'bridge_not_ready',
      );
    }
    return const LaunchRouteDecision(
      path: LaunchRoutePath.desktop,
      reason: 'desktop_ready',
    );
  }
}
