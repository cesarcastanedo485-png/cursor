# Mordechaius Maximus — Workspace Review

Review of what’s working, what’s not cemented, and what’s needed to increase functionality. Many areas are functional; several are explicitly placeholder or future-only.

---

## 1. What’s working properly

### Auth & onboarding
- **API key** stored in `flutter_secure_storage`, test connection (GET /v0/agents), onboarding gate.
- **Connection diagnostics** (v2.0.1): open api.cursor.com in browser, DNS + HTTPS check from the app.
- **Friendly error** for network/DNS failures in test connection.
- **Reset API key & onboarding** from Settings.

### Cloud Agents (Cursor API)
- **Agents list**: GET /v0/agents, cached for offline; Home and My Agents show list with pull-to-refresh.
- **Agent detail**: GET /v0/agents/:id, polling every 5s, conversation + artifacts, follow-up message (POST messages/conversation).
- **Launch agent**: POST /v0/agents with repo URL, prompt, branch, model, create PR, image base64; navigates to detail.
- **Repos**: GET /v0/repositories, search, “Launch Agent on this Repo” prefills Launch tab.
- **Artifacts**: list + open/download via presigned URL in external browser.

### Private AIs (Ollama / OpenAI-compatible)
- **Presets**: LLM (Ollama, etc.) and Media (ComfyUI-style); URL + model + optional API key per preset.
- **Chat**: `LocalOpenAiService` POST /v1/chat/completions; persistent thread via Hive (`private_chat_repository`).
- **TTS**: Flutter TTS for assistant replies; image picker + video picker; cross-AI memory excerpts in UI.
- **Private media screen**: separate flow for “Studio” presets.
- **Backend mode**: Cloud vs Private with Active AI banner; Private mode uses cached agents only on Home.

### App shell & UX
- **Tabs**: Cloud Agents (Home, Launch, Repos, Settings), My Private AIs, Capabilities.
- **Theme**: Material 3, dark/light, persisted.
- **Routing**: named routes + `onGenerateRoute` for agent detail (arguments = agent id).
- **Error views**: retry buttons, cached data when API fails.
- **Loading**: skeletons and indicators.

### Data & infra
- **Models**: Agent, Conversation, Message, Artifact, LaunchRequest/Response, CursorRepository, PrivateAiPreset, PrivateAiStoredConfig.
- **Preferences**: local server defaults (host, Ollama/ComfyUI ports), backend mode, active private AI id, per-preset config.
- **Cache**: last agents list JSON for offline.
- **Android**: INTERNET in main manifest (release); VIEW https for url_launcher; build/copy APK script.

---

## 2. What’s not yet cemented / incomplete

### Capabilities tab — implemented (v2.0.2+)
- **Test** button: pings configured webhook URL; shows success or error. Real connectivity check.
- **Configure** button: stores API key, webhook URL, folder path per capability in `flutter_secure_storage`. Persistence + UI.
- **Execute** button: sends POST to webhook with action and payload. Smart home (lights, thermostat, Alexa) has action picker. Bridge script (`scripts/smarthome_bridge.py`) forwards to Home Assistant or IFTTT.

### Repos tab — 401 handling
- If Cursor API returns **401** (e.g. bad/expired key), Dio throws; error message is raw (“request options.valid status was configured to throw 401”). No user-friendly “Invalid or expired API key” or prompt to re-enter key in Settings.

### Agent detail — send message
- `_sendMessage` catches all exceptions and does nothing (`catch (_) {}`). User gets no feedback if follow-up fails (e.g. 401, 404, network).

### Home screen label
- App bar title is **“Cursor Mobile”** instead of `AppStrings.appName` (“Mordechaius Maximus”). Small inconsistency.

### API service — response shape
- Repos/agents/conversation/artifacts tolerate multiple response shapes (list vs map with key); if Cursor changes format, parsing could break. No explicit API version or contract tests.

### Private AIs — reachability
- No in-app check that the configured base URL is reachable before opening chat (unlike Cloud “Test connection”). User can open chat and only then see connection errors.

### Instruction manual
- **Capabilities → Instruction manual**: rich text (e.g. **bold**) in manual steps is plain text in the app (no Markdown/rich rendering). Doc links work.

---

## 3. What to do to increase functionality

### High impact, clear scope

| Area | Action |
|------|--------|
| **Capabilities → Configure** | Add a real “Configure” flow: store per-capability keys/URLs/paths in `flutter_secure_storage` (e.g. by capability id), and a simple form (e.g. in Settings or under Capabilities) to edit them. No need to call APIs yet — just persistence + UI. |
| **Capabilities → Test** | Option A: Add a “desktop bridge” concept — e.g. configurable base URL (like Private AIs) that the app calls for “Test” (e.g. POST /invoke with capability id). Option B: Keep as safe stub but add “Copy curl” / “Open docs” for power users. |
| **401 / auth errors** | In `ApiService` (or a Dio interceptor), catch 401 responses and either throw a clear `UnauthorizedException` or return a known error type. In Repos/Agents/Launch, show “Invalid or expired API key. Check Settings.” and a button to open Settings. |
| **Agent detail — send failure** | In `_sendMessage`, on exception show a SnackBar or inline error (e.g. “Couldn’t send. Check connection and API key.”) and optionally retry. |
| **Home app bar** | Use `AppStrings.appName` for the Cloud Agents home app bar title (or a dedicated “Home”/“Agents” string) so branding is consistent. |
| **Private AI — connection check** | Before opening a private chat (or in preset config), call a lightweight endpoint (e.g. GET baseUrl/ or /v1/models) and show “Can’t reach [url]” if it fails; optional “Continue anyway” for advanced users. |

### Medium impact

| Area | Action |
|------|--------|
| **Capabilities catalog** | Add a “Configured” indicator per tool when the app has stored config for that id (even if not used yet). |
| **Artifact download** | If Cursor returns non-presigned URLs or requires auth, add a download path that uses the same auth (e.g. Dio get with auth → save to path_provider → open file). |
| **Offline / cache** | Show “Last updated: …” on Home when showing cached agents; consider cache expiry (e.g. grey out or hide after 24h). |
| **Instruction manual** | Render step text as Markdown (e.g. `flutter_markdown`) so **bold** and links render. |

### Lower priority / polish

| Area | Action |
|------|--------|
| **API versioning** | Document or lock expected Cursor API response shapes; add a simple “API version” or health check if Cursor exposes one. |
| **Pull-to-refresh on Agent detail** | Already present; ensure conversation and artifacts refresh together. |
| **Deep links** | Optional: handle `mordechaius://agent/:id` to open agent detail. |
| **In-app update** | Optional: “Check for update” in Settings that opens a fixed URL (e.g. latest APK on Drive) so users don’t have to re-download from Drive manually. |

---

## 4. Summary

- **Solid:** Auth, onboarding, Cloud Agents (list, launch, detail, conversation, artifacts, repos), Private AIs (chat, TTS, image/video, persistence, backend mode), app shell, theme, routing, cache, Android release build.
- **Placeholder / not cemented:** 401 and send-message error handling; Home title; optional Private AI pre-check; Instruction manual rich text.
- **Next steps to increase functionality:** Implement Configure persistence and UI, improve 401 and send-message UX, unify Home title, add Private AI reachability check, then consider desktop bridge or “Test” integration for Capabilities.
