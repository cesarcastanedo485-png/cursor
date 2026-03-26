# Mordechaius Maximus

Flutter app (Android & iOS) for **Cursor Pro Cloud Agents**

## GitHub (optional for the APK, useful for Cursor & backup)

The app **does not require** a GitHub repo to install or run.  
Remote **`origin`:** `https://github.com/cesarcastanedo485-png/cursor` — see **[GITHUB_SETUP_NOW.md](GITHUB_SETUP_NOW.md)** for setup notes.

### Automatic source ZIP on every push (mobile-friendly)

This repo now includes a GitHub Actions workflow at **`.github/workflows/source-zip-on-push.yml`**.

On every push, GitHub creates a downloadable ZIP artifact of the current commit.

Quick mobile flow:

1. Push your changes.
2. Open your repo on GitHub → **Actions** → **Source ZIP on Push**.
3. Open the latest run and download the artifact named like `source-<branch>-<sha>`.

---

Flutter app (Android & iOS) for **Cursor Pro Cloud Agents**, **Capabilities** (automation + instruction manual), and **Commissions** (Mordecai phased workflow in a WebView, with a server health check first).

**Architecture:** **Cloud Agents** uses `api.cursor.com` (Dio + Basic Auth). **Capabilities** use configurable webhooks and optional desktop bridges. **Commissions** loads your Mordecai URL after verifying `/api/commissions/health` or `/health`.

## Windows: C:, D:, and E: paths

Examples in this repo use different drives; all are valid depending on your setup:

| Drive | Typical use |
|--------|----------------|
| **C:** | Flutter SDK (`C:\Users\<you>\flutter`), classic clones (`C:\Users\<you>\cursor_mobile` or `mordechaius-maximus`). |
| **D:** | **Mordecai server only:** `COMMISSIONS_WORKSPACE` for commission folders (e.g. `D:\MordecaiCommissions`) — see repo root `README.md`. |
| **E:** | **Cursor backups:** e.g. `E:\CursorBackup_2026-03-22\mordecai-maximus\cursor_mobile` (open this folder in Cursor). |

The mobile app itself has no hard-coded drive letters; only your **PC** paths and **server** `.env` do.

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

## Release APK & install on phone (Google Drive)

Automatic path (default):

- Pushing to GitHub runs **`.github/workflows/apk_to_drive.yml`** on every branch.
- The workflow builds the release APK in GitHub Actions and uploads it to your Drive folder using `GDRIVE_*` secrets.
- Keep `GDRIVE_FOLDER_ID` plus OAuth secrets (`GDRIVE_OAUTH_CLIENT_ID`, `GDRIVE_OAUTH_CLIENT_SECRET`, `GDRIVE_OAUTH_REFRESH_TOKEN`) configured in repo secrets.

To build the APK and get it on your phone via Google Drive:

```powershell
.\scripts\copy_apk_for_phone.ps1 -Build
```

This builds the release APK and copies **`MordechaiusMaximus-install.apk`** to your **Desktop**. Upload that file to Google Drive, then on your phone: open Drive → find the file → ⋮ → Download → open from Files/Downloads → Install.

**Full steps:** **[INSTALL_ON_PHONE.md](INSTALL_ON_PHONE.md)** — use the **`.apk`** file only (not `.code-workspace`).

Manual build and copy:

```powershell
flutter build apk --release
.\scripts\copy_apk_for_phone.ps1
```

Output APK: **`build/app/outputs/flutter-apk/app-release.apk`** → copied to **`Desktop\MordechaiusMaximus-install.apk`**.

## Tabs

| Tab | Contents |
|-----|----------|
| **Cloud Agents** | Agents, Launch, My Repos, Settings (API keys, Mordecai URL, GitHub tips). |
| **Capabilities** | Tools (SMS, OBS, smart home, etc.) + **Instruction manual**. |
| **Commissions** | Mordecai web app; set **Mordecai URL** in Settings — app confirms server is up, then loads the workflow. |

## Branding assets

- **`assets/mm_logo.svg`** — in-app MM logo (onboarding).
- **`assets/images/mm_icon_512.png`** — regenerate: `python scripts/gen_mm_icon.py` (needs `pip install Pillow`).
- **Launcher & splash:** after changing the PNG, run:

  ```bash
  dart run flutter_launcher_icons
  dart run flutter_native_splash:create
  ```

## Tech

Flutter, Material 3, Riverpod, Dio, flutter_secure_storage, shared_preferences, Firebase Messaging, flutter_svg, url_launcher, webview_flutter.
