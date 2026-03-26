# Mordechaius Maximus — Project Architecture

## Overview
Flutter app (Android/iOS): **Cloud Agents** (Cursor API), **My Private AIs** (OpenAI-compatible local), **Capabilities** (automation + manuals). Riverpod, Dio, Hive chat, secure storage.

## Tech Stack
- **Flutter** 3.29+ (Material 3, dark mode)
- **Riverpod** 2.5+ (hooks + codegen)
- **Dio** 5+ (HTTP + auth interceptors)
- **flutter_secure_storage** (API key)
- **path_provider**, **url_launcher**, **webview_flutter**, **image_picker**, **cached_network_image**, **lottie**

## Folder Structure

```
mordechaius-maximus/
├── lib/
│   ├── main.dart                    # App entry, MaterialApp, theme, routing
│   ├── app.dart                     # Root widget, bottom nav shell, onboarding gate
│   │
│   ├── core/
│   │   ├── constants.dart          # API base URL, app constants
│   │   ├── theme/
│   │   │   ├── app_theme.dart      # Material 3 dark/light theme
│   │   │   └── app_colors.dart     # Color palette
│   │   └── router/
│   │       └── app_router.dart     # GoRouter or named routes
│   │
│   ├── data/
│   │   ├── models/
│   │   │   ├── agent.dart           # Agent list/detail model
│   │   │   ├── conversation.dart   # Message, conversation model
│   │   │   ├── artifact.dart       # Artifact model
│   │   │   └── launch_request.dart  # POST /v0/agents body
│   │   ├── repositories/
│   │   │   └── agent_repository.dart # Optional: wraps API + cache
│   │   └── local/
│   │       ├── secure_storage_service.dart  # API key read/write
│   │       └── cache_service.dart          # Cached agents (offline)
│   │
│   ├── services/
│   │   └── api_service.dart        # Dio client, Basic Auth, all API endpoints
│   │
│   ├── providers/
│   │   ├── auth_provider.dart      # API key state, isConfigured, test
│   │   ├── agents_provider.dart    # List agents, agent by id
│   │   ├── cache_provider.dart     # Cached agents for offline
│   │   └── theme_provider.dart     # Dark/light mode
│   │
│   ├── screens/
│   │   ├── onboarding/
│   │   │   └── onboarding_screen.dart   # API key input, test, instructions
│   │   ├── home/
│   │   │   └── home_screen.dart         # Dashboard, recent agents list
│   │   ├── launch/
│   │   │   └── launch_agent_screen.dart # Repo URL, prompt, options, POST
│   │   ├── agents/
│   │   │   └── my_agents_screen.dart    # Full list, pull-to-refresh
│   │   ├── agent_detail/
│   │   │   └── agent_detail_screen.dart # Status, conversation, artifacts, follow-up
│   │   └── settings/
│   │       └── settings_screen.dart     # Re-test key, theme, about
│   │
│   └── widgets/
│       ├── agent_card.dart         # Card for agent in list
│       ├── chat_bubble.dart       # User/assistant message bubble
│       ├── artifact_tile.dart    # Artifact row with download
│       ├── loading_skeleton.dart  # Shimmer/skeleton
│       ├── error_view.dart        # Network/API error widget
│       └── pull_to_refresh_wrapper.dart
│
├── assets/
│   ├── images/
│   │   └── (app icon, splash assets)
│   ├── animations/
│   │   └── loading.json           # Lottie loading
│   └── (optional) fonts/
│
├── android/                        # Standard Flutter + minSdk 21+, permissions
├── ios/                            # Standard Flutter + permissions
├── pubspec.yaml
├── ARCHITECTURE.md                 # This file
└── README.md
```

## File Purposes (Summary)

| File | Purpose |
|------|--------|
| `main.dart` | `WidgetsFlutterBinding`, Hive, `ProviderScope`, `runApp(App())` |
| `app.dart` | Onboarding gate; `MaterialApp` + theme; main shell = **Active AI banner** + `IndexedStack` (Cloud Agents shell, Private AIs, Capabilities) + `NavigationBar`; named routes via `AppRouter` for push flows (e.g. agent detail) |
| `constants.dart` | `baseUrl = https://api.cursor.com`, route names |
| `app_theme.dart` | ThemeData dark/light, typography, component themes |
| `app_colors.dart` | Semantic colors (surface, primary, error, etc.) |
| `app_router.dart` | Route definitions (optional; can use Navigator with named routes in app.dart) |
| `agent.dart` | Agent(id, status, summary, repo, createdAt, etc.) from JSON |
| `conversation.dart` | Message(role, content), Conversation(messages) |
| `artifact.dart` | Artifact(id, name, type, url/presigned) |
| `launch_request.dart` | DTO for POST body (repo_url, prompt, model, branch, create_pr, image) |
| `secure_storage_service.dart` | Read/write API key via flutter_secure_storage |
| `cache_service.dart` | Save/load last agents list (JSON) via path_provider |
| `api_service.dart` | Dio instance, Basic Auth header, GET /v0/agents, GET /v0/agents/:id, GET conversation, GET artifacts, POST /v0/agents, artifact download URL |
| `auth_provider.dart` | apiKey (from storage), setApiKey, clearApiKey, testConnection (GET /v0/agents), isConfigured |
| `agents_provider.dart` | fetchAgents(), fetchAgent(id), launchAgent(request), sendMessage(id, content), refetch conversation/artifacts |
| `cache_provider.dart` | lastAgents, saveToCache, loadFromCache |
| `theme_provider.dart` | isDarkMode, toggle |
| `onboarding_screen.dart` | TextField (obscured) for API key, "Test connection", link to cursor.com/dashboard?tab=cloud-agents, save and proceed |
| `home_screen.dart` | List of recent agents (from API or cache), status badges, tap → agent detail |
| `launch_agent_screen.dart` | Repo URL, branch, prompt textarea, image picker, model dropdown, create PR toggle, "Launch" → POST, then navigate to detail |
| `my_agents_screen.dart` | Full agents list, pull-to-refresh |
| `agent_detail_screen.dart` | Poll status, conversation bubbles, input for follow-up, artifacts list with download, PR link |
| `settings_screen.dart` | Test key again, dark mode toggle, version, link to get key |
| `agent_card.dart` | Displays one agent (status, summary, repo), onTap → detail |
| `chat_bubble.dart` | User (right) / assistant (left) bubble |
| `artifact_tile.dart` | Name, type, tap to download/open |
| `loading_skeleton.dart` | Shimmer placeholder |
| `error_view.dart` | Message + retry button |
| `pull_to_refresh_wrapper.dart` | Wrapper with RefreshIndicator |

## API Authentication
- **Header:** `Authorization: Basic base64(apiKey + ":")`
- Dart: `base64Encode(utf8.encode('$apiKey:'))`
- Base URL: `https://api.cursor.com`

## Data Flow
1. User enters API key → stored in secure storage → test GET /v0/agents → if success, mark onboarding done.
2. Home/Agents: GET /v0/agents → display list; cache response for offline.
3. Launch: Build launch request → POST /v0/agents → get agent ID → navigate to Agent Detail.
4. Agent Detail: Poll GET /v0/agents/{id}, load GET conversation, GET artifacts; user can send follow-up; open artifact URLs in browser or download.

## Offline
- Cache last agents list in local JSON; when API fails, show cached list with "Last updated" and error banner.
- Clear error messages for network/API (401, 404, 5xx).
