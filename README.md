# Mordechaius Maximus

Flutter app (Android & iOS) for **Cursor Pro Cloud Agents**

## GitHub (recommended for APK delivery, Cursor, and backup)

The app **does not require** a GitHub repo to install or run, but GitHub Actions is the easiest way to get fresh APK builds from any push.
Remote **`origin`:** `https://github.com/cesarcastanedo485-png/cursor` — see **[GITHUB_SETUP_NOW.md](GITHUB_SETUP_NOW.md)** for setup notes.

### Automatic source ZIP on every push (mobile-friendly)

This repo now includes a GitHub Actions workflow at **`.github/workflows/source-zip-on-push.yml`**.

On every push, GitHub creates a downloadable ZIP artifact of the current commit.

Quick mobile flow:

1. Push your changes.
2. Open your repo on GitHub → **Actions** → **Source ZIP on Push**.
3. Open the latest run and download the artifact named like `source-<branch>-<sha>`.

---

Flutter app (Android & iOS) for **Cursor Pro Cloud Agents** (tab: **Cloud Agents**), **My Private AIs** (local Ollama / ComfyUI), and **Capabilities** (automation tools + instruction manual).

**Architecture:** **Cloud Agents** mode uses `api.cursor.com` (Dio + Basic Auth). **Private** mode uses OpenAI-compatible `LocalOpenAiService`. Top **Active AI** banner shows which backend is active. Private chats use **Hive** (`mm_private_chat`) with cross-AI memory excerpts. **flutter_tts**, **image_picker**, **video_player** on per-AI chat.

## Prerequisites

- **Flutter 3.29+** — [Install Flutter](https://docs.flutter.dev/get-started/install)
- **Cursor Pro** + Cloud Agents API key — [Dashboard](https://cursor.com/dashboard?tab=cloud-agents)
- **Windows:** Developer Mode (symlinks) if `flutter pub get` warns about plugins.

## Release quality (v1)

- **Pre-push / local gate:** `.\scripts\pre_push.ps1` — `pub get`, `analyze`, `test`
- **CI:** `.github/workflows/flutter_ci.yml` — analyze + test on push/PR
- **Checklist:** `docs/RELEASE_CHECKLIST.md`
- **Secrets / signing:** `docs/SECRETS.md` — copy `android/key.properties.example` → `android/key.properties` (not committed)
- **Updates:** `docs/UPDATES.md` | **Privacy template:** `docs/PRIVACY_POLICY_TEMPLATE.md` | **Cursor ToS note:** `docs/DISTRIBUTION_AND_CURSOR_TOS.md`
- **Beta vs v1:** see top of `docs/RELEASE_CHECKLIST.md`

## Run

```bash
cd cursor_mobile
flutter pub get
flutter run
```

**Faster dev loop (emulator or USB):** start an AVD in **Android Studio → Device Manager**, then `flutter run` — use **hot reload** (`r`). See **[DEV_LOOP.md](DEV_LOOP.md)** and `.\scripts\run_on_emulator.ps1`.

## Release APK & install on phone (GitHub Actions)

Every push triggers **Build APK and Upload to GitHub** (`.github/workflows/apk_to_github.yml`).

Quick flow:

1. Push your changes to GitHub.
2. Open **GitHub → Actions → Build APK and Upload to GitHub**.
3. Open the latest run and download the APK artifact (`apk-<branch>-<sha>`).
4. Install the downloaded `.apk` on your phone from Files/Downloads.

**Full steps:** **[INSTALL_ON_PHONE.md](INSTALL_ON_PHONE.md)** — use the **`.apk`** file only (not `.code-workspace`).

Manual local build is still available:

```powershell
flutter build apk --release
.\scripts\copy_apk_for_phone.ps1
```

Output APK: **`build/app/outputs/flutter-apk/app-release.apk`** (or copied to **`Desktop\MordechaiusMaximus-install.apk`** via script).

## Tabs

| Tab | Contents |
|-----|----------|
| **Cloud Agents** | Agents, Launch, My Repos, Settings (Connect GitHub, local IP/ports). |
| **My Private AIs** | Five presets; **Chat** / **Studio**; configure URL + model + optional key. |
| **Capabilities** | Tools (SMS, Messenger, TikTok, Opus, OBS, social, smart home, YouTube) + **Instruction manual** (OAuth, Alexa, OBS, APIs). |

## Private AIs setup

**[SETUP_PRIVATE_AIs.md](SETUP_PRIVATE_AIs.md)** — Ollama, ComfyUI, Tailscale/LAN.

Optional: `.\scripts\complete_private_ai_setup.ps1`

## Branding assets

- **`assets/mm_logo.svg`** — in-app MM logo (onboarding).
- **`assets/images/mm_icon_512.png`** — regenerate: `python scripts/gen_mm_icon.py` (needs `pip install Pillow`).
- **Launcher & splash:** after changing the PNG, run:

  ```bash
  dart run flutter_launcher_icons
  dart run flutter_native_splash:create
  ```

## Tech

Flutter, Material 3, Riverpod, Dio, Hive, flutter_secure_storage, flutter_svg, flutter_tts, url_launcher, webview_flutter.
