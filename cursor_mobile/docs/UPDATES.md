# App updates (v1)

## Option A — Google Play (recommended for public users)

Use **Play App Signing** and standard in-app or Play-driven updates. No custom Drive flow required.

## Option B — Side-loaded APK (this project)

Documented, tested path:

1. Build release APK on a machine with **enough free disk** (`flutter clean` if needed):
   ```powershell
   flutter build apk --release
   ```
2. Distribute the file from `build/app/outputs/flutter-apk/app-release.apk` (or use `scripts/copy_apk_for_phone.ps1`).
3. In the app, **Capabilities → Check for updates** (`drive_download`):
   - **Configure** → set **Folder path** to a **direct download URL** for the APK (e.g. Google Drive `uc?export=download&id=...`).
   - **Test** checks reachability; **Execute** downloads to a temp file and opens the installer (`open_file`).

### In-place upgrades (no uninstall)

Android replaces an existing app only when the new APK matches **both**:

1. **Same application ID** — this project uses `com.mordechaius.maximus` (do not change between releases).
2. **Same signing certificate** — every release you sideload must be signed with the **same upload keystore**. If one build is signed with the **debug** key and the next with your **release** key (or a different keystore), the system blocks the update and you must uninstall first.

**What we enforce in CI:** the **Build APK and Upload to Google Drive** workflow runs `flutter build apk --release` with `-PrequireReleaseSigning=true`, so GitHub will **fail** if `ANDROID_KEYSTORE_*` secrets are missing instead of producing a **debug-signed** release APK.

For local builds you install on your phone, use `android/key.properties` pointing at your **same** upload keystore every time (or use `scripts/copy_apk_for_phone.ps1` after a proper release build). Only use `useDebugSigningForRelease=true` in `local.properties` for disposable test installs.

Also bump **`version:`** in `pubspec.yaml` (the `+build` number must increase for Play-style rules; sideloading still benefits from a clear version).

### Limitations

- User may need to allow **install from unknown sources**.
- Google Drive links must be **direct** download URLs; virus-scan interstitials can break automated downloads.
- This path is **best-effort**; verify on a real device after each release.

## Option C — Trigger desktop upload from the phone

**Upload to Drive** (`drive_upload`) sends a webhook to your **desktop bridge**. The bridge can run `rclone` or a script to upload the latest APK from a fixed folder. This does **not** run Cursor automatically unless **you** script that on the PC; the app only signals the bridge.

See `scripts/CAPABILITIES_BRIDGE.md`.
