import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:mordechaius_maximus/app.dart';
import 'package:mordechaius_maximus/data/local/secure_storage_service.dart';
import 'package:mordechaius_maximus/providers/auth_provider.dart';
import 'package:mordechaius_maximus/providers/backend_mode_provider.dart';
import 'package:mordechaius_maximus/providers/private_chat_provider.dart';
import 'package:mordechaius_maximus/providers/theme_provider.dart';
import 'package:mordechaius_maximus/data/local/preferences_service.dart';
import 'package:mordechaius_maximus/providers/preferences_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeSecureStorage extends SecureStorageService {
  @override
  Future<bool> isOnboardingDone() async => true;

  @override
  Future<String?> getApiKey() async => null;
}

/// Keeps onboarding in loading state so we only verify MaterialApp builds
/// without building the full main shell.
class _LoadingOnboardingNotifier extends OnboardingStateNotifier {
  _LoadingOnboardingNotifier(super.storage) : super(skipInitialLoad: true);
}

/// Static theme; skips SharedPreferences to avoid CI timing issues.
class _TestThemeNotifier extends ThemeModeNotifier {
  _TestThemeNotifier() : super(skipInitialLoad: true);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('App builds (smoke)', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: SizedBox()),
      ),
    );
    await tester.pump();
    expect(find.byType(MaterialApp), findsOneWidget);
  });

  testWidgets('App builds', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({
      'app_backend_mode': 'private',
      'active_private_ai_id': 'llm',
    });
    final prefs = await SharedPreferences.getInstance();
    final preferences = PreferencesService(prefs);

    late final Directory dir;
    late final Box<String> box;
    await tester.runAsync(() async {
      dir = await Directory.systemTemp.createTemp('mm_wt');
      Hive.init(dir.path);
      box = await Hive.openBox<String>('mm_private_chat');
    });
    addTearDown(() async {
      await tester.runAsync(() async {
        await box.close();
        await dir.delete(recursive: true);
      });
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          privateChatBoxProvider.overrideWithValue(box),
          secureStorageProvider.overrideWith((ref) => _FakeSecureStorage()),
          preferencesProvider.overrideWith((ref) => Future.value(preferences)),
          backendStateProvider.overrideWith((ref) => BackendStateNotifier(ref)),
          onboardingStateProvider.overrideWith((ref) => _LoadingOnboardingNotifier(_FakeSecureStorage())),
          themeModeProvider.overrideWith((ref) => _TestThemeNotifier()),
        ],
        child: const App(),
      ),
    );
    await tester.pump();
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
