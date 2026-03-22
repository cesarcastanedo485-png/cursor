/// App-wide constants for Cursor Mobile.
library;

/// Cursor Cloud Agents API base URL.
const String apiBaseUrl = 'https://api.cursor.com';

/// Where users can obtain their Cloud Agents API key.
const String apiKeyHelpUrl =
    'https://cursor.com/dashboard?tab=cloud-agents';

/// Where users connect GitHub so repos appear in the app (Cloud Agents onboarding).
const String cursorConnectGithubUrl = 'https://cursor.com/onboard';

/// GitHub: manage personal access tokens (API keys).
const String githubTokensUrl = 'https://github.com/settings/tokens';

/// GitHub: connected applications (Cursor, OAuth apps).
const String githubConnectionsUrl = 'https://github.com/settings/connections';

/// GitHub: repo secrets (Actions) — replace {owner} and {repo} or use releasesUrl as base.
const String githubSecretsUrlTemplate = 'https://github.com/{owner}/{repo}/settings/secrets/actions';

/// APK downloads — replace with your repo. Default: cesarcastanedo485-png/cursor.
const String githubReleasesUrl = 'https://github.com/cesarcastanedo485-png/cursor/releases';

/// Route names for navigation.
abstract class AppRoutes {
  static const String onboarding = '/onboarding';
  static const String home = '/';
  static const String launch = '/launch';
  static const String agents = '/agents';
  static const String agentDetail = '/agent';
  static const String settings = '/settings';
  static const String about = '/about';
  static const String repos = '/repos';
  static const String achievements = '/achievements';
}

/// Cache key for last agents list (offline).
const String cacheKeyAgents = 'cached_agents';
const String cacheKeyTimestamp = 'cached_agents_timestamp';
