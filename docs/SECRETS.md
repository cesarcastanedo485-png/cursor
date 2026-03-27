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

For Phase 1 automation, treat these as secrets too:

- `MORDECAI_BRIDGE_SECRET` (desktop bridge/task auth)
- `MORDECAI_PHASE1_INGEST_TOKEN` (recommended dedicated auth for `/api/phase1/events`)
- Platform access tokens used by your webhook ingest workers (Meta/TikTok/YouTube)
- Connector envs (as used): `MORDECAI_META_PAGE_ACCESS_TOKEN`, `MORDECAI_YOUTUBE_ACCESS_TOKEN`

## Cursor Cloud Agents API key

Stored on-device with **flutter_secure_storage**. It is never written to the repo.

## Rotation checklist

- [ ] Play/App Store: keystore passwords rotated from any dev placeholder
- [ ] Revoke and re-issue any leaked SMTP or cloud tokens
- [ ] Rotate bridge + Phase 1 ingest secrets after any exposure
- [ ] Re-scan repo: `git grep -i password` / secret scanning before pushing

## Google Drive upload auth (GitHub Actions)

**Step-by-step:** See `docs/SETUP_DRIVE_APK.md`.

The APK upload workflow uses OAuth to upload to your personal Drive folder. Set these secrets:

- `GDRIVE_OAUTH_CLIENT_ID`
- `GDRIVE_OAUTH_CLIENT_SECRET`
- `GDRIVE_OAUTH_REFRESH_TOKEN`
- `GDRIVE_FOLDER_ID`

Run `scripts/get_drive_refresh_token.py` locally to obtain the refresh token.
