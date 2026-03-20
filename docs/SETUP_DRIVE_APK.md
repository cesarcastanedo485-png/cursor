# APK Upload to Google Drive — Setup Guide

The GitHub Actions workflow uploads the built APK to a Google Drive folder. Service accounts **cannot** write to personal "My Drive" — you must use one of the options below.

---

## Option 1: Shared Drive (recommended)

Service accounts can write to Shared Drives when added as a member.

### Step 1: Create or use a Shared Drive

1. Open [Google Drive](https://drive.google.com).
2. In the left sidebar, click **Shared drives**.
3. Click **New** to create one, or use an existing Shared Drive.
4. Name it (e.g. `APKS` or `Mordechaius Maximus`).

### Step 2: Add the service account as a member

1. Right-click the Shared Drive → **Manage members**.
2. Add: `apk-uploader@gentle-shell-490808-m8.iam.gserviceaccount.com`  
   (Replace with your actual service account email from the JSON.)
3. Role: **Content manager** or **Writer**.

### Step 3: Create the APKS folder inside the Shared Drive

1. Open the Shared Drive.
2. Create a folder named `APKS` (or any name).
3. Open that folder and copy the ID from the URL:
   - `https://drive.google.com/drive/folders/<FOLDER_ID>`

### Step 4: Get the Shared Drive ID (optional but recommended)

1. Open the Shared Drive (not the APKS subfolder) in your browser.
2. URL format: `https://drive.google.com/drive/folders/<SHARED_DRIVE_ID>`
3. Copy that ID.

### Step 5: GitHub Secrets

| Secret | Value |
|--------|--------|
| `GDRIVE_SERVICE_ACCOUNT_JSON` | Full JSON key file contents |
| `GDRIVE_FOLDER_ID` | The **APKS folder** ID (from step 3) |
| `GDRIVE_SHARED_DRIVE_ID` | The **Shared Drive** ID (from step 4) — optional |

---

## Option 2: OAuth user credentials

Use your own Google account instead of a service account.

1. Create OAuth 2.0 credentials in [Google Cloud Console](https://console.cloud.google.com/apis/credentials).
2. Get a refresh token (requires a one-time OAuth flow).
3. Set secrets:
   - `GDRIVE_OAUTH_CLIENT_ID`
   - `GDRIVE_OAUTH_CLIENT_SECRET`
   - `GDRIVE_OAUTH_REFRESH_TOKEN`
   - `GDRIVE_FOLDER_ID` (any folder in your My Drive)
4. Set `GDRIVE_AUTH_MODE=oauth_user` or leave unset (script auto-detects).

---

## Option 3: Domain-wide delegation (Google Workspace only)

If you use Google Workspace and have admin access:

1. Enable domain-wide delegation for the service account.
2. Add `GDRIVE_IMPERSONATED_USER` = your Workspace user email.
3. Use a folder in that user's My Drive.

See: [Domain-wide delegation](https://developers.google.com/identity/protocols/oauth2/service-account#delegatingauthority)

---

## Quick check

- **"File not found"** → Folder ID wrong, or folder not shared / service account not a member.
- **"Service account target folder is in My Drive"** → Folder is in personal My Drive. Use Shared Drive (Option 1) or OAuth (Option 2).
- **Shared Drive mismatch** → `GDRIVE_SHARED_DRIVE_ID` does not match the Shared Drive that contains your folder. Fix the ID or remove the secret.
