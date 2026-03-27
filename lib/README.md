# Do not develop or run Flutter from this folder

The **real** Android/iOS app that CI builds and uploads is only under **`cursor_mobile/`** (see root [`README.md`](../README.md)).

This top-level `lib/`, `pubspec.yaml`, `android/`, and `ios/` tree is a **stale duplicate** (older version labels and missing Commissions/WebView fixes). Running `flutter run` from the repo root builds the wrong sources and will **not** match the APK on Google Drive.

Always:

```bash
cd cursor_mobile
flutter run
```
