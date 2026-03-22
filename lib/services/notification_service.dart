import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Push notification / FCM hookup. Initializes without Firebase until
/// `google-services.json` and `Firebase.initializeApp()` are added.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  static GlobalKey<NavigatorState>? _navigatorKey;

  static void setNavigatorKey(GlobalKey<NavigatorState> key) {
    _navigatorKey = key;
  }

  static GlobalKey<NavigatorState>? get navigatorKey => _navigatorKey;

  void Function(String message)? _foreground;

  void setForegroundCallback(void Function(String message) cb) {
    _foreground = cb;
  }

  /// Called when a notification arrives in the foreground (reserved for FCM).
  void notifyForeground(String message) {
    _foreground?.call(message);
  }

  Future<void> init(WidgetRef ref) async {
    // Wire FirebaseMessaging.onMessage etc. when Firebase is configured.
  }

  static bool get hasPendingNavigation => false;

  static void handlePendingInitialMessage() {}
}
