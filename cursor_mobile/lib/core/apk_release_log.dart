/// APK-focused release history bundled inside each Android APK.
///
/// **Maintenance:** Whenever you bump `pubspec.yaml` `version:` for a shipped APK,
/// append a new [ApkReleaseEntry] at the **top** of [apkReleaseHistory] with the
/// same `versionLabel` + `buildNumber` and bullet points for that build only.
/// This keeps Settings → About aligned with CI / Drive filenames like
/// `MordechaiusMaximus-v2.0.4-build14.apk`.
library;

/// One shipped APK line (matches `versionName` + `versionCode` from Android).
class ApkReleaseEntry {
  const ApkReleaseEntry({
    required this.versionLabel,
    required this.buildNumber,
    required this.released,
    required this.changes,
  });

  /// Semantic part of `version:` in pubspec (e.g. `2.0.4`).
  final String versionLabel;

  /// Integer build / `+N` in pubspec (e.g. `14`).
  final int buildNumber;

  /// Optional human date (not used by the OS; for your own log readability).
  final String released;

  /// What changed in **this** APK vs the previous one.
  final List<String> changes;

  String get apkLabel => 'v$versionLabel (build $buildNumber)';
}

/// Newest APK first.
const List<ApkReleaseEntry> apkReleaseHistory = [
  ApkReleaseEntry(
    versionLabel: '2.0.9',
    buildNumber: 20,
    released: '2026-03-26',
    changes: [
      'Release hygiene: pre-flight checks passed (Mordecai web UI shell loads locally, flutter analyze clean, Node bridge tests green).',
      'CI: APK and Flutter workflows remain pinned to cursor_mobile/ in this monorepo so Drive upload and releases keep working from main.',
    ],
  ),
  ApkReleaseEntry(
    versionLabel: '2.0.9',
    buildNumber: 19,
    released: '2026-03-26',
    changes: [
      'Commissions URL handling hardened: if /health endpoint is pasted, app normalizes to base URL so WebView opens full app (not raw {"ok":true} JSON).',
      'Desktop-first Launch routing: readiness probe, retry budget, cooldown, and automatic cloud fallback only when bridge is unavailable.',
      'Bridge API minimization: launch idempotency, telemetry for fallback reasons, and server metrics surfaced via runtime status.',
      'Security hardening: protected bridge/push routes, production secret guards, CORS/body/rate protections, and request-ID structured logs.',
      'Runtime automation + diagnostics: tunnel start/stop/status endpoints, extension runtime commands, and API Savings dashboard in web settings.',
    ],
  ),
  ApkReleaseEntry(
    versionLabel: '2.0.8',
    buildNumber: 18,
    released: '2026-03-23',
    changes: [
      'My Private AIs removed — app focuses on Cloud Agents, Capabilities, and Commissions only.',
      'Commissions: health check to Mordecai (/api/commissions/health, /health) before showing workflow.',
      'When healthy: banner “Installed and up and running” then WebView; offline: Retry + open anyway.',
      'Android: core library desugaring enabled for release builds (notifications / CI).',
      'Unused dependencies dropped (TTS, video, cached images, Lottie).',
    ],
  ),
  ApkReleaseEntry(
    versionLabel: '2.0.7',
    buildNumber: 17,
    released: '2026-03-22',
    changes: [
      'Desktop bridge: Use desktop (saves tokens) toggle in Launch — send tasks to your Cursor on desktop instead of Cloud API.',
      'What\'s New: Modal on first launch after app update showing changelog.',
      'Settings: Bridge secret for Mordecai task queue API.',
      'Cursor extension: Poll for tasks, copy/run in Composer, mark done.',
    ],
  ),
  ApkReleaseEntry(
    versionLabel: '2.0.6',
    buildNumber: 16,
    released: '2026-03-22',
    changes: [
      'Commissions tab: 4th main tab with WebView (set Mordecai URL in Settings).',
      'Settings: API keys & secrets section with tappable links (Cursor, GitHub, releases).',
      'Commissions ecosystem: all key/secrets links accessible from phone.',
    ],
  ),
  ApkReleaseEntry(
    versionLabel: '2.0.5',
    buildNumber: 15,
    released: '2026-03-20',
    changes: [
      'API: 503 retry with exponential backoff; improved 400/503/timeout error messages.',
      'API: sendMessage validation; legacy endpoint fallback only on 404/405.',
      'Tests: BackendStateNotifier provider override type fix.',
    ],
  ),
  ApkReleaseEntry(
    versionLabel: '2.0.4',
    buildNumber: 14,
    released: '2026-03-20',
    changes: [
      'Settings → About: shows this device’s APK version and a per-build change log.',
      'GitHub Actions: clearer “header” logs before analyze/test (version line, pwd, flutter --version).',
      'Footer version string now comes from the installed package (no hard-coded label).',
    ],
  ),
  ApkReleaseEntry(
    versionLabel: '2.0.3',
    buildNumber: 13,
    released: '(pre-change-log)',
    changes: [
      'Shipped builds before the in-app APK log existed; see git history for details.',
    ],
  ),
];
