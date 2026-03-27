import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/local/launch_presets_store.dart';
import '../data/models/launch_preset.dart';

final launchPresetsStoreProvider = FutureProvider<LaunchPresetsStore>((ref) => LaunchPresetsStore.create());

final launchPresetsNotifierProvider =
    AsyncNotifierProvider<LaunchPresetsNotifier, List<LaunchPreset>>(LaunchPresetsNotifier.new);

class LaunchPresetsNotifier extends AsyncNotifier<List<LaunchPreset>> {
  @override
  Future<List<LaunchPreset>> build() async {
    final store = await ref.watch(launchPresetsStoreProvider.future);
    return store.load();
  }

  Future<bool> addPreset(LaunchPreset preset, {required int maxAllowed}) async {
    final cur = await future;
    if (cur.length >= maxAllowed) return false;
    final store = await ref.read(launchPresetsStoreProvider.future);
    final next = [...cur, preset];
    await store.save(next);
    state = AsyncData(next);
    return true;
  }

  Future<void> removePreset(String id) async {
    final cur = await future;
    final store = await ref.read(launchPresetsStoreProvider.future);
    final next = cur.where((e) => e.id != id).toList();
    await store.save(next);
    state = AsyncData(next);
  }

  Future<void> updatePreset(LaunchPreset updated) async {
    final cur = await future;
    final store = await ref.read(launchPresetsStoreProvider.future);
    final next = cur.map((e) => e.id == updated.id ? updated : e).toList();
    await store.save(next);
    state = AsyncData(next);
  }

  Future<void> recordUsed(String id) async {
    final cur = await future;
    final now = DateTime.now().millisecondsSinceEpoch;
    final store = await ref.read(launchPresetsStoreProvider.future);
    final next = cur.map((e) => e.id == id ? e.copyWith(lastUsedAtMs: now) : e).toList();
    await store.save(next);
    state = AsyncData(next);
  }
}

/// Presets ordered by last used (desc), then name.
List<LaunchPreset> sortedLaunchPresets(List<LaunchPreset> list) {
  final copy = [...list];
  copy.sort((a, b) {
    final au = a.lastUsedAtMs ?? a.updatedAtMs;
    final bu = b.lastUsedAtMs ?? b.updatedAtMs;
    final c = bu.compareTo(au);
    if (c != 0) return c;
    return a.name.toLowerCase().compareTo(b.name.toLowerCase());
  });
  return copy;
}
