/// Optional compile-time Mordecai settings (local dev).
///
/// Pass from repo root `.env` via [run_with_repo_env.ps1](run_with_repo_env.ps1), e.g.:
/// `.\run_with_repo_env.ps1`
///
/// Flags: `--dart-define=MORDECAI_BASE_URL=...` and `--dart-define=MORDECAI_BRIDGE_SECRET=...`
class MordecaiCompileDefaults {
  MordecaiCompileDefaults._();

  static const String baseUrl = String.fromEnvironment(
    'MORDECAI_BASE_URL',
    defaultValue: '',
  );

  static const String bridgeSecret = String.fromEnvironment(
    'MORDECAI_BRIDGE_SECRET',
    defaultValue: '',
  );
}
