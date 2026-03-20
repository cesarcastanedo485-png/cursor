# Install Mordechaius Maximus on Your Phone (via GitHub Releases)

Use this flow to build the APK in GitHub Actions, then download and install it on your Android phone.

**v2.0.1+** adds **Connection check** on onboarding and Settings (open `api.cursor.com` in browser + DNS/HTTPS from the app) and fixes **release builds missing `INTERNET` permission** (could cause “Failed host lookup” only in the installed APK).

---

## 1. Push changes so GitHub builds the APK

From your project folder:

```powershell
cd C:\Users\cmc\mordechaius-maximus
git push origin main
```

GitHub workflow: **`.github/workflows/apk_to_github.yml`**  
It builds the APK and updates the prerelease **Latest APK** (`latest-apk`).

---

## 2. Download the APK from GitHub on your phone

1. Open your repo on GitHub in mobile browser.
2. Go to **Releases**.
3. Open **Latest APK**.
4. Download the `MordechaiusMaximus-*.apk` asset.

---

## 3. Install on your Android phone

1. Open **Files** or **Downloads** and tap the downloaded APK.
5. Tap **Install**. If prompted, allow installation from this source.
6. If your phone blocks the install: **Settings → Apps → Special app access** (or **Install unknown apps**) → allow **Files** or **Chrome** to install apps.

---

## Rebuild and update (new versions)

When you change the app and want a fresh APK:

```powershell
cd C:\Users\cmc\mordechaius-maximus
git push origin main
```

Then open **Releases → Latest APK**, download the newest asset, and install again.
