# Fast testing (emulator & USB) + release APK for Drive

## 1. Test on Android emulator (recommended dev loop)

### Start the emulator

**Option A — Android Studio (most reliable on Windows)**  
1. Open **Android Studio** → **More Actions** → **Virtual Device Manager** (or **Tools → Device Manager**).  
2. Find **Medium Phone API 36** (or any AVD) → **Play** ▶.  
3. Wait until the phone home screen appears.

**Option B — Command line**  
```powershell
cd C:\Users\cmc\mordechaius-maximus
C:\Users\cmc\flutter\bin\flutter.bat emulators --launch Medium_Phone_API_36
```
If that fails with a generic error, use Option A and cold boot the AVD (**▼ → Cold Boot Now**).

### Run the app with hot reload

```powershell
cd C:\Users\cmc\mordechaius-maximus
C:\Users\cmc\flutter\bin\flutter.bat devices
# You should see something like: sdk gphone64 ... • emulator-5554 • android-arm64
C:\Users\cmc\flutter\bin\flutter.bat run
```

- Press **`r`** in the terminal for **hot reload** after code changes.  
- Press **`R`** for **hot restart**.  
- Press **`q`** to quit.

### Test and debug (while `flutter run` is active)

| Action | How |
|--------|-----|
| **Hot reload** | Press **`r`** in the terminal — applies code changes in a few seconds without restarting the app. Use after editing Dart/UI. |
| **Hot restart** | Press **`R`** — full restart (state resets). Use when hot reload isn’t enough (e.g. changed `initState`, globals). |
| **Quit** | Press **`q`** — stops the app and exits `flutter run`. |
| **See logs** | The same terminal shows `print()` / `debugPrint()` and Flutter framework messages. Scroll up to see errors and stack traces. |
| **Breakpoints** | In VS Code/Cursor: open a Dart file, click in the gutter next to a line number to set a breakpoint. With **Run → Start Debugging** (or **F5**) and **Dart: Flutter** selected, execution stops there. |
| **Flutter DevTools** | When the app is running, the terminal prints a link like `http://127.0.0.1:9100?uri=...` — open it in a browser for widgets inspector, performance, network, and logs. Or run `flutter pub global run devtools` and connect to the running app. |

**Quick loop:** Edit code in Cursor → save → press **`r`** in the terminal → check the emulator. No rebuild or reinstall.

### One-shot script (after emulator is already running)

```powershell
cd C:\Users\cmc\mordechaius-maximus
.\scripts\run_on_emulator.ps1
```

---

## 2. Test on a physical phone (USB)

1. Enable **Developer options** → **USB debugging** on the phone.  
2. Connect USB → allow debugging when prompted.  
3. `flutter devices` should list the phone.  
4. `flutter run` — same hot reload as the emulator.

---

## 3. Release APK for Google Drive (not for daily dev)

```powershell
cd C:\Users\cmc\mordechaius-maximus
.\scripts\copy_apk_for_phone.ps1 -Build
```

Output: **`Desktop\MordechaiusMaximus-install.apk`** → upload to Google Drive.

---

## Troubleshooting

| Issue | What to try |
|--------|-------------|
| `flutter emulators --launch` exits with code 1 | Start the AVD from **Android Studio Device Manager** instead. |
| Emulator slow / Vulkan warnings | In AVD **Edit** → **Show Advanced Settings** → try **Graphics: Software** (slower but more compatible). |
| `flutter devices` has no Android | Emulator not fully booted; wait for home screen, run `adb devices`. |
| Hyper-V / virtualization | Ensure **Windows Hypervisor Platform** and virtualization are enabled in BIOS/Windows features. |

### “HAXM is not installed” (Intel HAXM)

Android Studio may show this even on **Windows 10/11**. You usually **do not need HAXM** anymore.

- **HAXM** = old Intel-only accelerator. It **does not work** if **Hyper-V** or **WSL2** is on (common on dev PCs).
- **Modern default:** the emulator uses **Windows Hypervisor Platform (WHPX)** / **Hyper-V** instead — faster and the right path for current API images.

**What to do**

1. Turn on Windows features (run `optionalfeatures` or **Settings → Apps → Optional features → More Windows features**):
   - **Windows Hypervisor Platform**
   - **Virtual Machine Platform** (if listed)
   - **Hyper-V** (Pro/Enterprise; optional if WHPX alone works)
2. Reboot, then start the AVD again from **Device Manager**.
3. **Ignore** the HAXM prompt if the emulator starts and `flutter devices` shows it.

**Only consider HAXM** if you are on an older setup with **no** Hyper-V and an **Intel** CPU — and even then, WHPX is usually preferred. **Do not** install HAXM and Hyper-V together; pick one acceleration path.

---

## Why use the emulator for testing?

- **No** upload to Drive, **no** manual install for every change.  
- **Hot reload** in seconds instead of a full APK cycle.  
- Use **release APK + Drive** when you want a real install test or to update your phone.
