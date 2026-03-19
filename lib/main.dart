import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'app.dart';
import 'providers/private_chat_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  final chatBox = await Hive.openBox<String>('mm_private_chat');
  runApp(
    ProviderScope(
      overrides: [
        privateChatBoxProvider.overrideWithValue(chatBox),
      ],
      child: const App(),
    ),
  );
}
