import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Unread notification count.
final notificationUnreadCountProvider = StateProvider<int>((ref) => 0);

/// Last received notification (for display).
final lastNotificationProvider = StateProvider<RemoteMessage?>((ref) => null);

/// Combined notification state: unread count + last notification.
/// Use [markAllRead] to reset unread count.
final notificationProvider = Provider<NotificationState>((ref) {
  final unread = ref.watch(notificationUnreadCountProvider);
  final last = ref.watch(lastNotificationProvider);
  return NotificationState(
    unreadCount: unread,
    lastNotification: last,
    markAllRead: () => ref.read(notificationUnreadCountProvider.notifier).state = 0,
  );
});

class NotificationState {
  const NotificationState({
    required this.unreadCount,
    required this.lastNotification,
    required this.markAllRead,
  });

  final int unreadCount;
  final RemoteMessage? lastNotification;
  final VoidCallback markAllRead;
}
