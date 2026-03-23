import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants.dart';
import '../core/notification_type.dart';
import '../providers/auth_provider.dart';
import '../firebase_options.dart';

/// Top-level handler for FCM when app is terminated/background.
/// Must be top-level (cannot be a class method).
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  debugPrint('[Push] Background: ${message.messageId}');
}

/// Singleton service for FCM push notifications.
/// Handles foreground, background, terminated states + deep linking.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  static RemoteMessage? _pendingInitialMessage;
  static GlobalKey<NavigatorState>? _navigatorKey;

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  static const AndroidNotificationDetails _androidDetails = AndroidNotificationDetails(
    'mordechaius_push',
    'Mordechaius Maximus',
    channelDescription: 'Agent completion, PR reviews, achievements',
    importance: Importance.high,
    priority: Priority.high,
    playSound: true,
    enableVibration: true,
    icon: '@mipmap/ic_launcher',
  );

  /// Set the navigator key from App (for deep linking).
  static void setNavigatorKey(GlobalKey<NavigatorState> key) {
    _navigatorKey = key;
  }

  /// Init after auth/onboarding. Call from _MainShellWithBottomNav.
  Future<void> init(WidgetRef ref) async {
    // CURSOR: next step — request permission first
    final messaging = FirebaseMessaging.instance;
    final settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    if (settings.authorizationStatus != AuthorizationStatus.authorized &&
        settings.authorizationStatus != AuthorizationStatus.provisional) {
      debugPrint('[Push] Permission denied: ${settings.authorizationStatus}');
      return;
    }

    // CURSOR: next step — init local notifications for foreground display
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings =
        InitializationSettings(android: androidInit, iOS: DarwinInitializationSettings());
    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    const androidChannel = AndroidNotificationChannel(
      'mordechaius_push',
      'Mordechaius Maximus',
      description: 'Agent completion, PR reviews, achievements',
      importance: Importance.high,
    );
    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidChannel);

    // CURSOR: next step — foreground handler
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // CURSOR: next step — background/terminated tap handler
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);

    final initialMessage = await messaging.getInitialMessage();
    if (initialMessage != null) {
      _pendingInitialMessage = initialMessage;
      debugPrint('[Push] Pending initial message: ${initialMessage.messageId}');
    }

    // CURSOR: next step — get token and sync to backend
    String? token;
    try {
      token = await messaging.getToken();
    } catch (e) {
      debugPrint('[Push] Failed to get token: $e');
    }
    if (token != null) {
      final storage = ref.read(secureStorageProvider);
      await storage.setFcmToken(token);
      debugPrint('[Push] FCM token: ${token.substring(0, 20)}...');
      await _syncTokenToBackend(ref, token);
    }

    messaging.onTokenRefresh.listen((newToken) async {
      await ref.read(secureStorageProvider).setFcmToken(newToken);
      await _syncTokenToBackend(ref, newToken);
    });
  }

  void _onNotificationTapped(NotificationResponse response) {
    final payload = response.payload;
    if (payload != null && payload.isNotEmpty) {
      try {
        // Payload format: "type|id" e.g. "agent_completed|agent_xyz"
        final parts = payload.split('|');
        final type = parts.isNotEmpty ? parts[0] : '';
        final id = parts.length > 1 ? parts[1] : '';
        _navigateFromPayload(type, id);
      } catch (_) {}
    }
  }

  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    debugPrint('[Push] Foreground: ${message.messageId}');
    _onForegroundMessage?.call(message);

    final title = message.notification?.title ?? 'Mordechaius Maximus';
    final body = message.notification?.body ?? 'New notification';
    final data = message.data;
    final type = data['type']?.toString() ?? '';
    final id = data['id']?.toString() ?? '';
    final payload = type.isNotEmpty ? '$type|$id' : '';

    await _localNotifications.show(
      message.hashCode,
      title,
      body,
      const NotificationDetails(
        android: _androidDetails,
        iOS: DarwinNotificationDetails(),
      ),
      payload: payload.isNotEmpty ? payload : null,
    );
  }

  void _handleMessageOpenedApp(RemoteMessage message) {
    debugPrint('[Push] Opened app from: ${message.messageId}');
    _handleNotificationPayload(message.data);
  }

  /// Check and consume pending initial message (app launched from terminated via notification).
  static void handlePendingInitialMessage() {
    final msg = _pendingInitialMessage;
    if (msg != null) {
      _pendingInitialMessage = null;
      instance._handleNotificationPayload(msg.data);
    }
  }

  /// Whether there is a pending navigation from a cold start.
  static bool get hasPendingNavigation => _pendingInitialMessage != null;

  void Function(RemoteMessage)? _onForegroundMessage;

  /// Optional: called when a message is received in foreground (for provider updates).
  void setForegroundCallback(void Function(RemoteMessage)? cb) {
    _onForegroundMessage = cb;
  }

  void _handleNotificationPayload(Map<String, dynamic> data) {
    final typeStr = data['type']?.toString() ?? '';
    final id = data['id']?.toString() ?? '';
    _navigateFromPayload(typeStr, id);
  }

  void _navigateFromPayload(String typeStr, String id) {
    final type = NotificationType.fromString(typeStr);
    final path = type.routePath;
    final navigator = _navigatorKey?.currentState;
    if (navigator == null) return;

    switch (path) {
      case AppRoutes.agentDetail:
        if (id.isNotEmpty) {
          navigator.pushNamed(AppRoutes.agentDetail, arguments: id);
        } else {
          navigator.pushNamed(AppRoutes.home);
        }
        break;
      case AppRoutes.repos:
        navigator.pushNamed(AppRoutes.repos);
        break;
      case AppRoutes.achievements:
        navigator.pushNamed(AppRoutes.achievements);
        break;
      default:
        navigator.pushNamed(AppRoutes.home);
    }
  }

  Future<void> _syncTokenToBackend(WidgetRef ref, String token) async {
    const supabaseUrl = String.fromEnvironment('SUPABASE_URL', defaultValue: '');
    const supabaseKey = String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: '');
    if (supabaseUrl.isEmpty || supabaseKey.isEmpty) return;

    try {
      // CURSOR: next step — upsert to Supabase fcm_tokens when configured.
      // Use SupabaseClient.from(supabaseUrl, supabaseKey) and insert/upsert to fcm_tokens.
      debugPrint('[Push] Supabase sync skipped (add SUPABASE_URL + SUPABASE_ANON_KEY if needed)');
    } catch (e) {
      debugPrint('[Push] Token sync error: $e');
    }
  }
}
