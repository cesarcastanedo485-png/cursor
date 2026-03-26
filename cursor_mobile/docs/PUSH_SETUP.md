# Push Notifications Setup — Mordechaius Maximus

## Prerequisites

1. **Firebase project** at [Firebase Console](https://console.firebase.google.com)
2. **FlutterFire CLI**: `dart pub global activate flutterfire_cli`
3. **Android**: `google-services.json` in `android/app/`
4. **iOS**: `GoogleService-Info.plist` in `ios/Runner/`

## Setup Steps

### 1. Configure Firebase

```bash
cd cursor_mobile
dart run flutterfire_cli:flutterfire configure
```

This generates `lib/firebase_options.dart` with your project credentials and creates/downloads `google-services.json` and `GoogleService-Info.plist`.

### 2. Install dependencies

```bash
flutter pub get
```

### 3. Run the app

```bash
flutter run
```

## Testing Steps

### Test 1: Get FCM token

1. Run the app and complete onboarding
2. Check logs for `[Push] FCM token: ...` — copy the full token

### Test 2: Firebase Console (quick test)

1. Firebase Console → Cloud Messaging → "Send your first message"
2. Enter notification title and body
3. Under "Target", choose "Send to single device" and paste the FCM token
4. Send — notification should appear on device

### Test 3: Data payload (deep link)

Use the Cloud Function or a tool to send a push with data:

```json
{
  "data": {
    "type": "agent_completed",
    "id": "agent_xyz"
  }
}
```

Tap the notification — app should open to agent detail for `agent_xyz`.

### Test 4: Foreground

1. Keep app open
2. Send a test push
3. Local notification should appear in the tray

### Test 5: Background

1. Send push while app is in background
2. Tap notification — app should open and navigate

### Test 6: Terminated

1. Force-close the app
2. Send push
3. Tap notification — app should launch and navigate

## Firebase Cloud Function (Agent Completed)

```bash
cd firebase
npm install
# Edit .firebaserc: set "default" to your project ID
firebase deploy --only functions
```

Then call the function:

```bash
curl -X POST https://YOUR_REGION-YOUR_PROJECT.cloudfunctions.net/sendAgentCompletedPush \
  -H "Content-Type: application/json" \
  -d '{"token":"YOUR_FCM_TOKEN","agentId":"agent_123","message":"Task finished"}'
```

## Gotchas (APK distribution)

- **Google Play Services**: Required. Devices without GMS (e.g. some Chinese phones) will not receive FCM.
- **Release build**: Add your release keystore SHA-1 to Firebase (Project Settings → Your apps → Android).
- **minSdk**: Firebase Messaging needs minSdk 21+. Flutter default is usually 21.
- **Android 13+**: `POST_NOTIFICATIONS` is requested at runtime in `NotificationService.init()`.
- **Supabase**: If `SUPABASE_URL` and `SUPABASE_ANON_KEY` are not set via `--dart-define`, token sync is skipped; app works with local storage only.

## Notification types and routes

| Payload `type`         | Route           |
|------------------------|-----------------|
| `agent_completed`      | `/agent` (id)   |
| `agent_error`          | `/agent` (id)   |
| `pr_review_requested`  | `/repos`        |
| `achievement_unlocked` | `/achievements` |
| default                | `/` (home)      |
