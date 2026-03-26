# Mordechaius Maximus: Single Source of Truth

## 1) Project identity (name confusion resolved)

- Folder name can be `cursor_mobile` (legacy).
- App identity is `Mordechaius Maximus`.
- Android package ID is `com.mordechaius.maximus`.
- Current release line in app config is `2.0.8+18`.
- "My Private AIs" is removed in this release line.

## 2) What is actually git-enabled on this machine right now

- This workspace root is git-enabled:
  - `E:\CursorBackup_2026-03-22\mordecai-maximus\.git`
- `cursor_mobile` is **not** a separate git clone here:
  - `E:\CursorBackup_2026-03-22\mordecai-maximus\cursor_mobile` has no `.git` directory.
- The root repo currently has no GitHub remote set in `.git/config`.

## 3) Why pushing failed

- GitHub Actions failed with:
  - `Invalid workflow file ... Required property is missing: type`
- We fixed that locally in:
  - `cursor_mobile/.github/workflows/apk_to_drive.yml`
  - Added `type: string` for `workflow_call.inputs`:
    - `app_name`
    - `apk_filename`
    - `upload_to_drive`

## 4) Drive/APK pipeline status (logic)

Local workflow now includes:

- Valid `workflow_call.inputs` schema.
- Build with enforced release signing:
  - `flutter build apk --release -- -PrequireReleaseSigning=true`
- Drive upload condition supports:
  - push on `main`/`master`
  - `workflow_dispatch`
  - `workflow_call`
- SHA short syntax fixed where applicable:
  - `${GITHUB_SHA:0:7}`

## 5) Fastest way to recover and push (recommended)

Use a real clone of your GitHub repo, then copy this fixed workflow file into it:

```powershell
cd C:\Users\cmc\source\repos
git clone https://github.com/cesarcastanedo485-png/cursor.git
cd cursor
```

Copy in this fixed file from backup workspace:

```powershell
copy "E:\CursorBackup_2026-03-22\mordecai-maximus\cursor_mobile\.github\workflows\apk_to_drive.yml" ".github\workflows\apk_to_drive.yml"
```

Commit and push:

```powershell
git add .github/workflows/apk_to_drive.yml
git commit -m "fix(actions): add workflow_call input types and stabilize APK->Drive flow"
git push origin main
```

Then run GitHub Actions manually:

- Actions -> `.github/workflows/apk_to_drive.yml` -> **Run workflow** (branch `main`).
- Confirm logs include:
  - `Drive folder access OK: APKS (...)`
  - `Uploaded new APK ...` or `Updated existing Google Drive APK ...`

## 6) If Android asks to uninstall old app

This means signature mismatch between installed APK and new APK.

Keep these consistent every release:

- Same package ID: `com.mordechaius.maximus`
- Same upload keystore signing cert
- Increasing version/build in `pubspec.yaml`

CI is now configured to fail instead of producing a debug-signed "release" when signing is missing.

