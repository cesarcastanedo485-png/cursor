import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/local/cache_service.dart';
import '../data/models/agent.dart';

final cacheServiceProvider = FutureProvider<CacheService>((ref) => CacheService.create());

/// Cached agents for offline display.
final cachedAgentsProvider = FutureProvider<List<Agent>>((ref) async {
  final cache = await ref.watch(cacheServiceProvider.future);
  return cache.getCachedAgents();
});

/// Last cache timestamp (for "Last updated" label).
final cacheTimestampProvider = FutureProvider<DateTime?>((ref) async {
  final cache = await ref.watch(cacheServiceProvider.future);
  return cache.getCachedTimestamp();
});
