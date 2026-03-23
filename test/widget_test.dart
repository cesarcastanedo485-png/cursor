import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mordechaius_maximus/app.dart';
import 'package:mordechaius_maximus/data/local/secure_storage_service.dart';
import 'package:mordechaius_maximus/providers/auth_provider.dart';
import 'package:mordechaius_maximus/providers/backend_mode_provider.dart';
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

/// Onboarding not completed: builds [OnboardingScreen] only (no main shell / notification init).
/// Avoids the loading branch, which keeps a [CircularProgressIndicator] that never settles.
class _OnboardingNotDoneNotifier extends OnboardingStateNotifier {
  _OnboardingNotDoneNotifier()
      : super(_FakeSecureStorage(), skipInitialLoad: true) {
    state = const AsyncValue.data(false);
  }
}

/// Static theme; skips SharedPreferences to avoid CI timing issues.
class _TestThemeNotifier extends ThemeModeNotifier {
  _TestThemeNotifier() : super(skipInitialLoad: true);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('App builds', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({
      'app_backend_mode': 'private',
      'active_private_ai_id': 'llm',
    });
    final prefs = await SharedPreferences.getInstance();
    final preferences = PreferencesService(prefs);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          secureStorageProvider.overrideWith((ref) => _FakeSecureStorage()),
          preferencesProvider.overrideWith((ref) => Future.value(preferences)),
          backendStateProvider.overrideWith((ref) => BackendStateNotifier(ref)),
          onboardingStateProvider.overrideWith((ref) => _OnboardingNotDoneNotifier()),
          themeModeProvider.overrideWith((ref) => _TestThemeNotifier()),
        ],
        child: const App(),
      ),
    );
    await tester.pump();
    // SvgPicture / async layout may schedule extra frames after first pump.
    await tester.pump(const Duration(milliseconds: 16));
    expect(find.byType(MaterialApp), findsOneWidget);
  }, timeout: const Timeout(Duration(seconds: 30)));
}
