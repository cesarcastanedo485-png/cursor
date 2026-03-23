import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Last payload from the notification layer (e.g. foreground FCM). Typed loosely until
/// Firebase is fully wired with [RemoteMessage].
final lastNotificationProvider = StateProvider<Object?>((ref) => null);

final notificationUnreadCountProvider = StateProvider<int>((ref) => 0);
