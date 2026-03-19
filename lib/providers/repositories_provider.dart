import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/cursor_repository.dart';
import 'auth_provider.dart';

/// Cursor Cloud repositories (requires API key + network).
final repositoriesProvider = FutureProvider.autoDispose<List<CursorRepository>>((ref) async {
  final key = ref.watch(apiKeyProvider).valueOrNull;
  if (key == null || key.isEmpty) {
    throw Exception('Add your Cursor API key in Settings to load repositories.');
  }
  final api = ref.watch(apiServiceProvider);
  api.setApiKey(key);
  return api.getRepositories();
});
