import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'firebase_options.dart';
import 'services/notification_service.dart';

Future<void> main() async {
  final widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  var firebaseOk = false;
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      ).timeout(const Duration(seconds: 12));
    }
    firebaseOk = true;
  } on TimeoutException {
    debugPrint('[main] Firebase.initializeApp timed out — starting UI without push');
  } catch (e, st) {
    debugPrint('[main] Firebase.initializeApp failed — starting UI without push: $e');
    debugPrintStack(stackTrace: st);
  }

  if (firebaseOk) {
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  }

  runApp(
    const ProviderScope(
      child: _FirstFrameSplashRemoval(
        child: App(),
      ),
    ),
  );
}

/// Ensures the native splash from `flutter_native_splash` is removed after Flutter paints.
class _FirstFrameSplashRemoval extends StatefulWidget {
  const _FirstFrameSplashRemoval({required this.child});

  final Widget child;

  @override
  State<_FirstFrameSplashRemoval> createState() => _FirstFrameSplashRemovalState();
}

class _FirstFrameSplashRemovalState extends State<_FirstFrameSplashRemoval> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FlutterNativeSplash.remove();
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
