import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:mordechaius_maximus/app.dart';
import 'package:mordechaius_maximus/providers/private_chat_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('App builds', (WidgetTester tester) async {
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
        ],
        child: const App(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
