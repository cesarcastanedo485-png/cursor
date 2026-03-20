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

## GitHub Actions secrets (APK workflow)

The APK workflow (`.github/workflows/apk_to_github.yml`) only requires signing secrets if you want release signing in CI:

- `ANDROID_KEYSTORE_BASE64`
- `ANDROID_KEYSTORE_PASSWORD`
- `ANDROID_KEY_ALIAS`
- `ANDROID_KEY_PASSWORD`

If these are missing, the workflow still runs and may fall back to debug signing depending on Gradle config.
