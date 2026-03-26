# Rename this workspace (later)

Planned renames when you're ready:

---

## 1. Folder: `cursor_mobile` → `mordechaius-maximus`

The folder is currently **cursor_mobile**. To rename it to **mordechaius-maximus** (to match the app):

1. **Close Cursor** (or close this workspace tab). The folder cannot be renamed while it's open in Cursor.

2. **Rename the folder** in PowerShell (run from any location):
   ```powershell
   Rename-Item -Path "C:\Users\cmc\cursor_mobile" -NewName "mordechaius-maximus"
   ```

3. **Reopen in Cursor:** **File → Open Folder** → `C:\Users\cmc\mordechaius-maximus`

4. **If you use Git:** No change needed. The repo lives inside the folder; remote URL is unchanged.

---

## 2. Display name (optional, later): "Mordechaius Maximus" → "Mordecai's Maximus"

If you want the app to show **Mordecai's Maximus** on the phone (home bar, settings, etc.): edit **`lib/core/app_strings.dart`** (`appName`), then **`android/app/src/main/AndroidManifest.xml`** `android:label`, **`ios/Runner/Info.plist`** display name, and **`web/manifest.json`** `name`. Rebuild the APK.

---

**Optional:** Delete this file after you've done the renames.
