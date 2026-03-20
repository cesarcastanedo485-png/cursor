# APK Upload to Google Drive — Setup Guide

The GitHub Actions workflow uploads the built APK to a folder in your personal Google Drive using OAuth.

---

## Required GitHub Secrets

Set these in your repo: **Settings → Secrets and variables → Actions**

| Secret | Value |
|--------|--------|
| `GDRIVE_OAUTH_CLIENT_ID` | From Google Cloud OAuth client |
| `GDRIVE_OAUTH_CLIENT_SECRET` | From Google Cloud OAuth client |
| `GDRIVE_OAUTH_REFRESH_TOKEN` | From one-time OAuth flow (see below) |
| `GDRIVE_FOLDER_ID` | Folder ID from your Drive URL |

---

## Step 1: Create OAuth credentials

1. Go to [Google Cloud Console → APIs & Services → Credentials](https://console.cloud.google.com/apis/credentials).
2. Click **Create Credentials** → **OAuth client ID**.
3. If prompted, configure the OAuth consent screen. Add your email as a **Test user**.
4. **Application type:** Select **Desktop app**.
5. **Name:** e.g. `Mordechaius Maximus - APK Drive Upload`.
6. Click **Create**. Copy the **Client ID** and **Client Secret**.

---

## Step 2: Get a refresh token

Run the script locally (one-time):

```powershell
cd C:\Users\cmc\cursor_mobile
pip install google-auth-oauthlib
$env:GDRIVE_OAUTH_CLIENT_ID = "your-client-id"
$env:GDRIVE_OAUTH_CLIENT_SECRET = "your-client-secret"
python scripts/get_drive_refresh_token.py
```

Sign in with your Google account in the browser. Copy the printed refresh token.

---

## Step 3: Get your Drive folder ID

1. In [Google Drive](https://drive.google.com), create or open a folder for the APKs.
2. Open the folder. The URL is: `https://drive.google.com/drive/folders/<FOLDER_ID>`
3. Copy the `<FOLDER_ID>` part.

---

## Step 4: Add secrets to GitHub

Add all four secrets to your repo. Then push to trigger the workflow; the APK will upload to your Drive folder.
