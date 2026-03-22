import 'package:flutter_riverpod/flutter_riverpod.dart';

final lastNotificationProvider = StateProvider<String?>((ref) => null);

final notificationUnreadCountProvider =
    StateNotifierProvider<NotificationUnreadNotifier, int>(
  (ref) => NotificationUnreadNotifier(),
);

class NotificationUnreadNotifier extends StateNotifier<int> {
  NotificationUnreadNotifier() : super(0);

  void update(int Function(int n) fn) {
    state = fn(state);
  }
}
