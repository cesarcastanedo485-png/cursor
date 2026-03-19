# Android / iOS configuration notes

After running `flutter create . --project-name mordechaius_maximus`, you may need to adjust the following.

## Android

- **minSdkVersion**: 21 or higher (default from `flutter create` is usually 21).
- **Permissions**: The app uses:
  - `INTERNET` (added by default)
  - `CAMERA` (for image_picker when attaching photos to launch)
  - `READ_EXTERNAL_STORAGE` / `READ_MEDIA_IMAGES` (for gallery picker on newer Android)

If camera or gallery fails, add in `android/app/src/main/AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.CAMERA" />
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" android:maxSdkVersion="32" />
<uses-permission android:name="android.permission.READ_MEDIA_IMAGES" />
```

## iOS

- **Minimum iOS**: 12.0 or as set by Flutter.
- **Permissions**: Add in `ios/Runner/Info.plist` for camera and photo library:

```xml
<key>NSCameraUsageDescription</key>
<string>Used to attach a photo when launching an agent.</string>
<key>NSPhotoLibraryUsageDescription</key>
<string>Used to attach an image when launching an agent.</string>
```

## Splash and app icon

- Replace `android/app/src/main/res/mipmap-*/ic_launcher.png` and `ios/Runner/Assets.xcassets/AppIcon.appiconset/` with your own icons.
- Customize the splash screen in the same platform folders if desired.
