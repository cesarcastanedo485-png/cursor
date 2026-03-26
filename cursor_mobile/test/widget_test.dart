import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mordechaius_maximus/app.dart';
import 'package:mordechaius_maximus/data/local/secure_storage_service.dart';
import 'package:mordechaius_maximus/providers/auth_provider.dart';
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

  testWidgets('App builds', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final preferences = PreferencesService(prefs);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          secureStorageProvider.overrideWith((ref) => _FakeSecureStorage()),
          preferencesProvider.overrideWith((ref) => Future.value(preferences)),
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
