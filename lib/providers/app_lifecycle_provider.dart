import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// App lifecycle state. Used to keep connection stable when switching apps.
/// - [resumed]: app is in foreground, user can interact.
/// - [paused/inactive/detached]: app is in background or switching.
final appLifecycleProvider = StateProvider<AppLifecycleState>((ref) => AppLifecycleState.resumed);

/// True when app is in foreground (user can interact). Use to keep polling/connections active.
final isAppForegroundProvider = Provider<bool>((ref) {
  final state = ref.watch(appLifecycleProvider);
  return state == AppLifecycleState.resumed;
});
