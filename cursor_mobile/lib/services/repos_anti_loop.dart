import 'package:shared_preferences/shared_preferences.dart';

/// Prevents hammering Cursor GET /v0/repositories (401 loops, rate limits, user refresh spam).
///
/// Rules:
/// - After [max401BeforeSuppress] consecutive 401s within [windowFor401Count], suppress API calls
///   for [circuitDuration] and show empty list + banner instead of error.
/// - Minimum [minSecondsBetweenAttempts] between attempts (unless [force] bypass).
/// - [force] retry clears circuit for one attempt only.
class ReposAntiLoop {
  ReposAntiLoop._();
  static const _kLastAttemptMs = 'repos_antiloop_last_attempt_ms';
  static const _k401Timestamps = 'repos_antiloop_401_timestamps'; // comma-separated ms
  static const _kCircuitUntilMs = 'repos_antiloop_circuit_until_ms';

  static const int max401BeforeSuppress = 2;
  static const Duration windowFor401Count = Duration(hours: 24);
  static const Duration circuitDuration = Duration(minutes: 30);
  static const int minSecondsBetweenAttempts = 45;

  static Future<ReposFetchGate> checkGate({required bool force}) async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now().millisecondsSinceEpoch;

    if (force) {
      await prefs.remove(_kCircuitUntilMs);
      return const ReposFetchGate(allowFetch: true);
    }

    final circuitUntil = prefs.getInt(_kCircuitUntilMs) ?? 0;
    if (now < circuitUntil) {
      final until = DateTime.fromMillisecondsSinceEpoch(circuitUntil);
      return ReposFetchGate(
        allowFetch: false,
        suppressErrorUi: true,
        userMessage:
            'Cursor repo list is paused until ${until.hour.toString().padLeft(2, '0')}:${until.minute.toString().padLeft(2, '0')} '
            'to avoid repeat failures. Use manual repos below, or tap “Force API retry”.',
      );
    }

    final lastAttempt = prefs.getInt(_kLastAttemptMs) ?? 0;
    final elapsedSec = (now - lastAttempt) / 1000;
    if (lastAttempt > 0 && elapsedSec < minSecondsBetweenAttempts) {
      final wait = (minSecondsBetweenAttempts - elapsedSec).ceil();
      return ReposFetchGate(
        allowFetch: false,
        suppressErrorUi: true,
        userMessage:
            'Wait ~${wait}s before another Cursor repos request (reduces rate-limit / loop issues). '
            'Or tap “Force API retry”.',
      );
    }

    return const ReposFetchGate(allowFetch: true);
  }

  static Future<void> markAttemptStart() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kLastAttemptMs, DateTime.now().millisecondsSinceEpoch);
  }

  static Future<void> onSuccess() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_k401Timestamps);
    await prefs.remove(_kCircuitUntilMs);
  }

  static Future<void> on401Unauthorized() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now().millisecondsSinceEpoch;
    final windowStart = now - windowFor401Count.inMilliseconds;

    final raw = prefs.getString(_k401Timestamps) ?? '';
    final list = raw
        .split(',')
        .map((s) => int.tryParse(s.trim()))
        .whereType<int>()
        .where((t) => t >= windowStart)
        .toList();
    list.add(now);
    await prefs.setString(_k401Timestamps, list.join(','));

    if (list.length >= max401BeforeSuppress) {
      final until = now + circuitDuration.inMilliseconds;
      await prefs.setInt(_kCircuitUntilMs, until);
    }
  }

  /// True if we should show empty data + banner instead of throwing (after repeated 401).
  static Future<bool> shouldSuppressErrorUi() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now().millisecondsSinceEpoch;
    if ((prefs.getInt(_kCircuitUntilMs) ?? 0) > now) return true;

    final raw = prefs.getString(_k401Timestamps) ?? '';
    final windowStart = now - windowFor401Count.inMilliseconds;
    final recent = raw
        .split(',')
        .map((s) => int.tryParse(s.trim()))
        .whereType<int>()
        .where((t) => t >= windowStart)
        .length;
    return recent >= max401BeforeSuppress;
  }
}

class ReposFetchGate {
  const ReposFetchGate({
    required this.allowFetch,
    this.suppressErrorUi = false,
    this.userMessage,
  });

  final bool allowFetch;
  final bool suppressErrorUi;
  final String? userMessage;
}
