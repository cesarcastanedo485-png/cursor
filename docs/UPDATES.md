# App updates (v1)

## Option A — Google Play (recommended for public users)

Use **Play App Signing** and standard in-app or Play-driven updates. No custom APK hosting flow required.

## Option B — Side-loaded APK (this project)

Documented, tested path:

1. Push code to GitHub (or run workflow manually).
2. Open **Actions → Build APK and Upload to GitHub** and download artifact `apk-<branch>-<sha>`.
3. Install the extracted APK on Android.
4. In the app, **Capabilities → Check for updates** (`drive_download`):
   - **Configure** → set **Folder path** to a direct APK URL (for example, a GitHub release asset URL).
   - **Test** checks reachability; **Execute** downloads to a temp file and opens the installer (`open_file`).

### Limitations

- User may need to allow **install from unknown sources**.
- Direct-download URL behavior depends on host; always test your chosen URL on device.
- This path is **best-effort**; verify on a real device after each release.

## Option C — Trigger desktop upload from the phone (optional legacy)

**Upload to Drive** (`drive_upload`) sends a webhook to your **desktop bridge**. The bridge can run `rclone` or a script to upload the latest APK from a fixed folder. This does **not** run Cursor automatically unless **you** script that on the PC; the app only signals the bridge.

See `scripts/CAPABILITIES_BRIDGE.md`.
