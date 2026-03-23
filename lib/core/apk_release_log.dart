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
    versionLabel: '2.0.7',
    buildNumber: 17,
    released: '2026-03-23',
    changes: [
      'CI: APK + Google Drive workflow runs on this release branch (MordechaiusMaximus-install.apk).',
      'Flutter CI (analyze/test) also runs on the same branch before build.',
      'Restore notification provider + service stubs so release APK compiles (FCM wiring optional).',
      'Android: enable core library desugaring for flutter_local_notifications release builds.',
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
