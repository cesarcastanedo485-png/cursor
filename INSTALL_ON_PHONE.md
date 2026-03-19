# Install Mordechaius Maximus on Your Phone (via Google Drive)

Use this flow to build the APK, upload it to Google Drive, then download and install it on your Android phone.

**v2.0.1+** adds **Connection check** on onboarding and Settings (open `api.cursor.com` in browser + DNS/HTTPS from the app) and fixes **release builds missing `INTERNET` permission** (could cause “Failed host lookup” only in the installed APK).

---

## 1. Build and prepare the APK on your PC

**Use this file:** **`MordechaiusMaximus-install.apk`** (or `app-release.apk`)  
**Do not use:** `.code-workspace` or any other file — those are not the app.

From your project folder:

```powershell
cd C:\Users\cmc\cursor_mobile
.\scripts\copy_apk_for_phone.ps1 -Build
```

This builds the release APK and copies it to:

**`Desktop\MordechaiusMaximus-install.apk`**

(If the APK already exists, you can run without `-Build` to only copy.)

---

## 2. Upload to Google Drive (on your PC)

1. Open [Google Drive](https://drive.google.com) in your browser (same account you use on your phone).
2. Upload **`Desktop\MordechaiusMaximus-install.apk`** (drag and drop or **New → File upload**).
3. Keep the file there so you can redownload it anytime on your phone.

---

## 3. Download and install on your Android phone

1. Open the **Google Drive** app (or drive.google.com in Chrome).
2. Find **MordechaiusMaximus-install.apk**.
3. Tap the **⋮** (three dots) next to it → **Download** (or **Make available offline**).
4. Open **Files** or **Downloads** and tap **MordechaiusMaximus-install.apk**.
5. Tap **Install**. If prompted, allow installation from this source.
6. If your phone blocks the install: **Settings → Apps → Special app access** (or **Install unknown apps**) → allow **Files** or **Chrome** or **Google Drive** to install apps.

---

## Rebuild and update (new versions)

When you change the app and want a fresh APK in Drive:

```powershell
cd C:\Users\cmc\cursor_mobile
flutter build apk --release
.\scripts\copy_apk_for_phone.ps1
```

Then upload the new **`Desktop\MordechaiusMaximus-install.apk`** to Google Drive (replace the old one or use a new name). On your phone, download the new APK and install again.
