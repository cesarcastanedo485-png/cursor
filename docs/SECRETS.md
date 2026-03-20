# Secrets & signing (v1)

## Android release signing

1. Create a keystore (one-time), e.g. in `android/`:
   ```powershell
   cd android
   keytool -genkey -v -keystore upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
   ```
2. Copy `android/key.properties.example` → `android/key.properties`.
3. Set **strong** `storePassword` and `keyPassword`. **Do not** use placeholder passwords in production.
4. `key.properties` and `*.jks` are **gitignored** — never commit them.

If `key.properties` is missing, release builds fall back to the **debug** keystore (fine for local testing only, not for Play Store).

## Environment variables (desktop bridge)

The Python bridge (`scripts/smarthome_bridge.py`) and optional email/Drive flows use env vars (e.g. `HA_URL`, `EMAIL_SMTP_HOST`, `RCLONE_CMD`). Document them in `scripts/CAPABILITIES_BRIDGE.md`; keep real values in your shell profile or a local `.env` that is **not** committed (`.env` is gitignored).

## Cursor Cloud Agents API key

Stored on-device with **flutter_secure_storage**. It is never written to the repo.

## Rotation checklist

- [ ] Play/App Store: keystore passwords rotated from any dev placeholder
- [ ] Revoke and re-issue any leaked SMTP or cloud tokens
- [ ] Re-scan repo: `git grep -i password` / secret scanning before pushing

## Google Drive upload auth (GitHub Actions)

The APK upload workflow supports two paths:

1. **Service account + Shared Drive** (recommended for service accounts)
   - Set `GDRIVE_SERVICE_ACCOUNT_JSON`, `GDRIVE_FOLDER_ID`, and `GDRIVE_SHARED_DRIVE_ID`.
   - Add the service-account email as a member of the Shared Drive (Editor or better).
   - Use a folder that belongs to that Shared Drive.

2. **OAuth user credentials** (real user storage quota)
   - Set `GDRIVE_OAUTH_CLIENT_ID`, `GDRIVE_OAUTH_CLIENT_SECRET`, `GDRIVE_OAUTH_REFRESH_TOKEN`, and `GDRIVE_FOLDER_ID`.
   - Use a folder accessible by that user account.

Optional upload targeting:

- `GDRIVE_TARGET_FILENAME`: force a stable file name in the folder (default: APK file basename).
- `GDRIVE_TARGET_FILE_ID`: update an exact existing Drive file ID in the folder (preserves file ID/share link).
  - Recommended when using a service account with a My Drive folder, to avoid new-file quota failures.

Optional for Workspace admins:

- **Domain-wide delegation impersonation** with service account:
  set `GDRIVE_IMPERSONATED_USER` (user email) and ensure domain-wide delegation is configured in Google Workspace.

Important: there is no separate paid "service account storage" quota. Shared Drive capacity comes from Workspace storage plans.

Official docs:

- Shared Drives + Drive API: https://developers.google.com/workspace/drive/api/guides/enable-shareddrives
- OAuth 2.0 for Google APIs: https://developers.google.com/identity/protocols/oauth2
- Domain-wide delegation: https://developers.google.com/identity/protocols/oauth2/service-account#delegatingauthority
