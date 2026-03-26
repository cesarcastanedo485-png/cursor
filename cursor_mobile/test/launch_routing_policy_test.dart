import 'package:flutter_test/flutter_test.dart';
import 'package:mordechaius_maximus/core/launch_routing_policy.dart';

void main() {
  test('routes desktop when preferred and ready', () {
    final decision = LaunchRoutingPolicy.decide(
      preferDesktop: true,
      hasBridgeService: true,
      bridgeReady: true,
      lastLaunchAtMs: null,
      nowMs: 10000,
    );
    expect(decision.path, LaunchRoutePath.desktop);
    expect(decision.reason, 'desktop_ready');
  });

  test('routes cloud when bridge not configured', () {
    final decision = LaunchRoutingPolicy.decide(
      preferDesktop: true,
      hasBridgeService: false,
      bridgeReady: false,
      lastLaunchAtMs: null,
      nowMs: 10000,
    );
    expect(decision.path, LaunchRoutePath.cloud);
    expect(decision.reason, 'bridge_not_configured');
  });

  test('routes cloud when bridge not ready', () {
    final decision = LaunchRoutingPolicy.decide(
      preferDesktop: true,
      hasBridgeService: true,
      bridgeReady: false,
      lastLaunchAtMs: null,
      nowMs: 10000,
    );
    expect(decision.path, LaunchRoutePath.cloud);
    expect(decision.reason, 'bridge_not_ready');
  });

  test('cooldown blocks rapid repeat launch', () {
    final blocked = LaunchRoutingPolicy.isCooldownBlocked(
      lastLaunchAtMs: 5000,
      nowMs: 5500,
    );
    expect(blocked, isTrue);
  });
}
