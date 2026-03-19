import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../data/local/private_chat_repository.dart';

/// Overridden in main() after Hive.openBox.
final privateChatBoxProvider = Provider<Box<String>>((ref) => throw StateError('Hive box not ready'));

final privateChatRepositoryProvider = Provider<PrivateChatRepository>((ref) {
  final box = ref.watch(privateChatBoxProvider);
  return PrivateChatRepository(box);
});
