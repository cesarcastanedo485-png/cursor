import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants.dart';
import '../core/notification_type.dart';
import '../data/local/secure_storage_service.dart';
import '../firebase_options.dart';
import '../providers/auth_provider.dart';
import '../providers/notification_provider.dart';
import '../providers/preferences_provider.dart';
import 'api_service.dart';

/// Top-level handler for FCM when app is terminated/background.
/// Must be top-level (cannot be a class method).
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  }
  debugPrint('[Push] Background: ${message.messageId}');
}

const String _quickReplyActionId = 'quick_reply';

@pragma('vm:entry-point')
void localNotificationTapBackground(NotificationResponse response) {
  if (response.actionId == _quickReplyActionId) {
    final input = response.input?.trim() ?? '';
    final payload = NotificationService.decodePayload(response.payload);
    final agentId = payload['agentId'] ?? payload['id'] ?? '';
    if (agentId.isNotEmpty && input.isNotEmpty) {
      NotificationService.sendQuickReply(agentId, input);
    }
    return;
  }
  NotificationService.instance.handleNotificationResponse(response);
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
      onDidReceiveNotificationResponse: handleNotificationResponse,
      onDidReceiveBackgroundNotificationResponse: localNotificationTapBackground,
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

  void handleNotificationResponse(NotificationResponse response) {
    if (response.actionId == _quickReplyActionId) {
      final input = response.input?.trim() ?? '';
      final payload = decodePayload(response.payload);
      final agentId = payload['agentId'] ?? payload['id'] ?? '';
      if (agentId.isNotEmpty && input.isNotEmpty) {
        sendQuickReply(agentId, input);
        _navigateFromPayload('agent_running', agentId);
      }
      return;
    }
    final payload = decodePayload(response.payload);
    _navigateFromPayload(payload['type'] ?? '', payload['id'] ?? payload['agentId'] ?? '');
  }

  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    debugPrint('[Push] Foreground: ${message.messageId}');
    _onForegroundMessage?.call(message);

    final title = message.notification?.title ?? 'Mordechaius Maximus';
    final body = message.notification?.body ?? 'New notification';
    final data = message.data;
    final type = data['type']?.toString() ?? '';
    final id = data['id']?.toString() ?? data['agentId']?.toString() ?? '';
    final payload = jsonEncode({
      'type': type,
      'id': id,
      'agentId': id,
      'threadId': data['threadId']?.toString() ?? id,
      'eventId': data['eventId']?.toString() ?? '',
      'messagePreview': data['messagePreview']?.toString() ?? body,
    });
    final isAgentThread = id.isNotEmpty;
    final androidDetails = isAgentThread
        ? const AndroidNotificationDetails(
            'mordechaius_push',
            'Mordechaius Maximus',
            channelDescription: 'Agent completion, PR reviews, achievements',
            importance: Importance.high,
            priority: Priority.high,
            playSound: true,
            enableVibration: true,
            icon: '@mipmap/ic_launcher',
            actions: <AndroidNotificationAction>[
              AndroidNotificationAction(
                _quickReplyActionId,
                'Reply',
                showsUserInterface: false,
                inputs: <AndroidNotificationActionInput>[
                  AndroidNotificationActionInput(
                    label: 'Reply to agent',
                  ),
                ],
              ),
            ],
          )
        : _androidDetails;

    await _localNotifications.show(
      message.hashCode,
      title,
      body,
      NotificationDetails(
        android: androidDetails,
        iOS: const DarwinNotificationDetails(),
      ),
      payload: payload,
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
    final id = data['id']?.toString() ?? data['agentId']?.toString() ?? '';
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
    final prefs = await ref.read(preferencesProvider.future);
    final baseUrl = prefs.mordecaiCommissionsUrl.trim();
    if (baseUrl.isEmpty) return;
    final secret = await ref.read(secureStorageProvider).getMordecaiBridgeSecret();
    final notifPrefs = ref.read(agentNotificationPreferencesProvider);
    final uri = Uri.parse(
      '${baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl}/api/notifications/register-device',
    );
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 8);
    try {
      await _postRegisterDevice(client, uri, secret, token, notifPrefs).timeout(
        const Duration(seconds: 12),
        onTimeout: () => throw TimeoutException('register-device'),
      );
    } on TimeoutException {
      debugPrint('[Push] Token sync timed out (Mordecai URL may be down or tunnel expired)');
    } catch (e) {
      debugPrint('[Push] Token sync error: $e');
    } finally {
      client.close(force: true);
    }
  }

  Future<void> _postRegisterDevice(
    HttpClient client,
    Uri uri,
    String? secret,
    String token,
    AgentNotificationPreferences notifPrefs,
  ) async {
    final req = await client.postUrl(uri);
    req.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
    final trimmed = secret?.trim() ?? '';
    if (trimmed.isNotEmpty) {
      req.headers.set('X-Bridge-Secret', trimmed);
    }
    req.write(jsonEncode({
      'token': token,
      'preferences': notifPrefs.toJson(),
    }));
    final res = await req.close();
    if (res.statusCode < 200 || res.statusCode >= 300) {
      debugPrint('[Push] Token sync failed (${res.statusCode})');
    }
  }

  static Map<String, String> decodePayload(String? payload) {
    if (payload == null || payload.isEmpty) return const {};
    try {
      final decoded = jsonDecode(payload);
      if (decoded is Map<String, dynamic>) {
        return decoded.map((k, v) => MapEntry(k.toString(), v?.toString() ?? ''));
      }
    } catch (_) {
      final parts = payload.split('|');
      if (parts.length >= 2) {
        return {'type': parts[0], 'id': parts[1], 'agentId': parts[1]};
      }
    }
    return const {};
  }

  static Future<void> sendQuickReply(String agentId, String replyText) async {
    try {
      if (agentId.trim().isEmpty || replyText.trim().isEmpty) return;
      final storage = SecureStorageService();
      final key = await storage.getApiKey();
      final normalized = key?.trim() ?? '';
      if (normalized.isEmpty) return;
      final api = ApiService(apiKey: normalized);
      await api.sendMessage(agentId.trim(), replyText.trim());
    } catch (e) {
      debugPrint('[Push] Quick reply failed: $e');
    }
  }
}
