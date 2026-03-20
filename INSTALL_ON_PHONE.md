# Install Mordechaius Maximus on Your Phone (via GitHub)

Use this flow to build/download the APK from GitHub Actions, then install it on your Android phone.

**v2.0.1+** adds **Connection check** on onboarding and Settings (open `api.cursor.com` in browser + DNS/HTTPS from the app) and fixes **release builds missing `INTERNET` permission** (could cause “Failed host lookup” only in the installed APK).

---

## 1. Build APK in GitHub Actions

**Use this file:** the artifact APK from the latest workflow run (named like `MordechaiusMaximus-<branch>-<sha>.apk`)
**Do not use:** `.code-workspace` or any other file — those are not the app.

1. Push your changes to GitHub.
2. Open your repository on GitHub.
3. Go to **Actions** → **Build APK and Upload to GitHub**.
4. Open the latest run for your branch.
5. Download the artifact (`apk-<branch>-<sha>`), then extract it if your browser downloads a ZIP.

---

## 2. Download and install on your Android phone

1. Move the downloaded APK to your phone (USB, cloud storage, or direct mobile browser download).
2. Open **Files** or **Downloads** and tap the APK.
3. Tap **Install**. If prompted, allow installation from this source.
4. If your phone blocks the install: **Settings → Apps → Special app access** (or **Install unknown apps**) → allow the app you used for download (Files/Chrome/etc.) to install apps.

---

## Rebuild and update (new versions)

When you change the app and want a fresh APK:

- Preferred: push changes and download the newest GitHub Actions artifact.
- Local fallback: build and copy manually from your computer:

```powershell
cd C:\Users\cmc\mordechaius-maximus
flutter build apk --release
.\scripts\copy_apk_for_phone.ps1
```

If you use the local fallback path, copy/install the new APK file from your Desktop to your phone and install again.
