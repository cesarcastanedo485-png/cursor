# App updates (v1)

## Option A — Google Play (recommended for public users)

Use **Play App Signing** and standard in-app or Play-driven updates. No custom Drive flow required.

## Option B — Side-loaded APK via GitHub (this project)

Documented, tested path:

1. Build release APK on a machine with **enough free disk** (`flutter clean` if needed):
   ```powershell
   flutter build apk --release
   ```
2. Push to `main`/`master` so CI builds and publishes APK:
   - Workflow: `.github/workflows/apk_to_github.yml`
   - Download from GitHub **Releases → Latest APK**
3. In the app, **Capabilities → Check for updates** (`drive_download`):
   - **Configure** → set **Folder path** to a **direct download URL** for the APK (e.g. Google Drive `uc?export=download&id=...`).
   - **Test** checks reachability; **Execute** downloads to a temp file and opens the installer (`open_file`).

### Limitations

- User may need to allow **install from unknown sources**.
- If you still use Google Drive for in-app update links, links must be **direct** download URLs; virus-scan interstitials can break automated downloads.
- This path is **best-effort**; verify on a real device after each release.

## Option C — Trigger desktop upload from the phone

**Upload to Drive** (`drive_upload`) sends a webhook to your **desktop bridge**. The bridge can run `rclone` or a script to upload the latest APK from a fixed folder. This does **not** run Cursor automatically unless **you** script that on the PC; the app only signals the bridge.

See `scripts/CAPABILITIES_BRIDGE.md`.
