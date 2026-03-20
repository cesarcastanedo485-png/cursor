# Mordechaius bridge — smart home, email, Drive upload

Run **`smarthome_bridge.py`** (same script; name is legacy).

## Email (Send email capability)

Set before `python smarthome_bridge.py`:

- `EMAIL_SMTP_HOST` — e.g. `smtp.gmail.com`
- `EMAIL_SMTP_PORT` — default `587`
- `EMAIL_FROM` — your address (must match login)
- `EMAIL_PASSWORD` — app password for Gmail, or SMTP password

Gmail: enable 2FA → create an **App password** → use it as `EMAIL_PASSWORD`.

## Upload to Drive

1. Install [rclone](https://rclone.org) and run `rclone config` to add Google Drive.
2. Set **`RCLONE_CMD`** to the full copy command, e.g.  
   `rclone copy "C:/Users/you/cursor_mobile/build/app/outputs/flutter-apk/app-release.apk" gdrive:Mordechaius --drive-use-trash=false`
3. Or set **`DRIVE_APK_PATH`** as default APK path and use `RCLONE_CMD` with `{apk}` placeholder.

Until `RCLONE_CMD` is set, the bridge returns an error explaining what to configure.

## Check for updates (phone)

No bridge. In the app, **Configure** → paste a **direct** Google Drive download URL:

`https://drive.google.com/uc?export=download&id=FILE_ID`

Replace `FILE_ID` from the file’s share link.
