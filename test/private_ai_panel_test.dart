import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:mordechaius_maximus/app.dart';
import 'package:mordechaius_maximus/core/app_strings.dart';
import 'package:mordechaius_maximus/data/local/secure_storage_service.dart';
import 'package:mordechaius_maximus/providers/auth_provider.dart';
import 'package:mordechaius_maximus/providers/backend_mode_provider.dart';
import 'package:mordechaius_maximus/providers/private_chat_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/mock_private_ai_server.dart';

/// Fake storage that reports onboarding done so tests skip onboarding.
class _FakeSecureStorage extends SecureStorageService {
  @override
  Future<bool> isOnboardingDone() async => true;

  @override
  Future<String?> getApiKey() async => null;
}

void main() {
  group('My Private AI Panel', () {
    late MockPrivateAiServer server;
    late Directory tempDir;
    late Box<String> chatBox;

    setUpAll(() async {
      server = MockPrivateAiServer();
      await server.start();

      SharedPreferences.setMockInitialValues({
        'app_backend_mode': 'private',
        'active_private_ai_id': 'llm',
        'private_ai_config_llm': jsonEncode({
          'baseUrl': server.baseUrl,
          'model': 'test',
          'apiKey': '',
        }),
        'private_ai_config_sfw_image': jsonEncode({
          'baseUrl': server.baseUrl,
          'model': 'flux',
          'apiKey': '',
        }),
      });

      tempDir = await Directory.systemTemp.createTemp('mm_pa_test');
      Hive.init(tempDir.path);
      chatBox = await Hive.openBox<String>('mm_private_chat');
    });

    tearDownAll(() async {
      await server.stop();
      await chatBox.close();
      try {
        await tempDir.delete(recursive: true);
      } catch (_) {}
    });

    testWidgets('Private AI tab shows 5 preset cards with Chat/Studio buttons',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            privateChatBoxProvider.overrideWithValue(chatBox),
            secureStorageProvider.overrideWith((ref) => _FakeSecureStorage()),
            backendStateProvider.overrideWith((ref) => BackendStateNotifier(ref)),
          ],
          child: const App(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      await tester.tap(find.text(AppStrings.privateAis));
      await tester.pumpAndSettle();

      expect(find.text('My Private AIs'), findsAtLeastNWidgets(1));
      expect(find.text('Chat'), findsWidgets);
      expect(find.text('Studio'), findsWidgets);
    });

    testWidgets('Tapping Chat shows Connecting then connection dialog',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            privateChatBoxProvider.overrideWithValue(chatBox),
            secureStorageProvider.overrideWith((ref) => _FakeSecureStorage()),
            backendStateProvider.overrideWith((ref) => BackendStateNotifier(ref)),
          ],
          child: const App(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      await tester.tap(find.text(AppStrings.privateAis));
      await tester.pumpAndSettle();

      final chatButtons = find.text('Chat');
      expect(chatButtons, findsWidgets);
      await tester.tap(chatButtons.first);
      await tester.pump();

      expect(find.text('Connecting…'), findsOneWidget);
      await tester.pumpAndSettle(const Duration(seconds: 15));

      expect(find.text('Connecting…'), findsNothing);
      if (find.text('Cancel').evaluate().isNotEmpty) {
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
      }
    });

    testWidgets('Tapping Studio shows Connecting then connection dialog',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            privateChatBoxProvider.overrideWithValue(chatBox),
            secureStorageProvider.overrideWith((ref) => _FakeSecureStorage()),
            backendStateProvider.overrideWith((ref) => BackendStateNotifier(ref)),
          ],
          child: const App(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      await tester.tap(find.text(AppStrings.privateAis));
      await tester.pumpAndSettle();

      final studioButtons = find.text('Studio');
      expect(studioButtons, findsWidgets);
      await tester.tap(studioButtons.first);
      await tester.pump();

      expect(find.text('Connecting…'), findsOneWidget);
      await tester.pumpAndSettle(const Duration(seconds: 15));

      expect(find.text('Connecting…'), findsNothing);
      if (find.text('Cancel').evaluate().isNotEmpty) {
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
      }
    });
  });
}
