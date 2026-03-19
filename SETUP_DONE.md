# Setup status

## Done for you

1. **Flutter SDK**
   - Downloaded: `flutter_windows_3.41.4-stable.zip` to your **Downloads** folder.
   - Extracted to: **`C:\Users\cmc\flutter`**
   - **PATH**: `C:\Users\cmc\flutter\bin` was added to your **user** PATH.

2. **Next step: new terminal**
   - Close any open terminals/PowerShell/CMD windows.
   - Open a **new** terminal (so it picks up the new PATH).
   - Run:
     ```powershell
     flutter doctor
     ```
   - Then:
     ```powershell
     cd C:\Users\cmc\cursor_mobile
     flutter pub get
     flutter run
     ```
   - When asked, choose your connected Android phone.

## Android Studio (you install once)

The Android Studio installer is large (~1.3 GB) and the official site uses a redirect. Download it yourself (one click):

- **Download Android Studio for Windows:**  
  https://developer.android.com/studio

Click **“Download Android Studio”**, accept the terms, and save the `.exe` to your Downloads folder. Run the installer and complete the wizard (install Android SDK when prompted). After that, `flutter doctor` will detect the Android toolchain.

## If you don’t have the `android` folder yet

In the project folder run once:

```powershell
cd C:\Users\cmc\cursor_mobile
flutter create . --project-name cursor_mobile
flutter pub get
flutter run
```

## Phone setup

1. On your Android phone: **Settings → About phone** → tap **Build number** 7 times.
2. **Settings → Developer options** → turn on **USB debugging**.
3. Connect the phone with USB and allow debugging when prompted.
4. Run `flutter run` and select your device.

### Install via Google Drive (APK, not workspace file)

- The app file is **`app-release.apk`** only. **Never** upload **`.code-workspace`** — that’s not the app.
- After `flutter build apk --release`, run:

  ```powershell
  cd C:\Users\cmc\cursor_mobile
  .\scripts\copy_apk_for_phone.ps1
  ```

  This copies **`MordechaiusMaximus-install.apk`** to your **Desktop** for easy upload. See **INSTALL_ON_PHONE.md**.
