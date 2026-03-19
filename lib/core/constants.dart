/// App-wide constants for Cursor Mobile.
library;

/// Cursor Cloud Agents API base URL.
const String apiBaseUrl = 'https://api.cursor.com';

/// Where users can obtain their Cloud Agents API key.
const String apiKeyHelpUrl =
    'https://cursor.com/dashboard?tab=cloud-agents';

/// Where users connect GitHub so repos appear in the app (Cloud Agents onboarding).
const String cursorConnectGithubUrl = 'https://cursor.com/onboard';

/// Route names for navigation.
abstract class AppRoutes {
  static const String onboarding = '/onboarding';
  static const String home = '/';
  static const String launch = '/launch';
  static const String agents = '/agents';
  static const String agentDetail = '/agent';
  static const String settings = '/settings';
}

/// Cache key for last agents list (offline).
const String cacheKeyAgents = 'cached_agents';
const String cacheKeyTimestamp = 'cached_agents_timestamp';
