import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Coordinates push / local notification hooks. FCM registration can be added once
/// `google-services.json` and Firebase init are configured for this app ID.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  static GlobalKey<NavigatorState>? _navigatorKey;

  static void setNavigatorKey(GlobalKey<NavigatorState> key) {
    _navigatorKey = key;
  }

  static GlobalKey<NavigatorState>? get navigatorKey => _navigatorKey;

  void Function(Object? message)? _onForeground;

  void setForegroundCallback(void Function(Object? message) cb) {
    _onForeground = cb;
  }

  Future<void> init(WidgetRef ref) async {
    // No-op until FCM + Firebase.initializeApp are set up for Android/iOS.
  }

  static bool get hasPendingNavigation => false;

  static void handlePendingInitialMessage() {}
}
