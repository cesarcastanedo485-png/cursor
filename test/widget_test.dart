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
import 'package:shared_preferences/shared_preferences.dart';

class _FakeSecureStorage extends SecureStorageService {
  @override
  Future<bool> isOnboardingDone() async => true;

  @override
  Future<String?> getApiKey() async => null;
}

class _FakeBackendStateNotifier extends StateNotifier<BackendState> {
  _FakeBackendStateNotifier()
      : super(const BackendState(mode: AppBackendMode.privateLocal, activePrivateAiId: 'llm'));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('App builds', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({
      'app_backend_mode': 'private',
      'active_private_ai_id': 'llm',
    });

    final dir = await Directory.systemTemp.createTemp('mm_wt');
    Hive.init(dir.path);
    final box = await Hive.openBox<String>('mm_private_chat');
    addTearDown(() async {
      await box.close();
      await dir.delete(recursive: true);
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          privateChatBoxProvider.overrideWithValue(box),
          secureStorageProvider.overrideWith((ref) => _FakeSecureStorage()),
          backendStateProvider.overrideWith((ref) => _FakeBackendStateNotifier()),
        ],
        child: const App(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
