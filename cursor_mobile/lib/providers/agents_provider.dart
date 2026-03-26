import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/agent.dart';
import '../data/models/artifact.dart';
import '../data/models/conversation.dart';
import '../data/models/launch_request.dart';
import '../services/agent_stream_service.dart';
import 'auth_provider.dart';
import 'bridge_task_provider.dart';
import 'cache_provider.dart';
import 'notification_provider.dart';
import 'preferences_provider.dart';

/// List of agents from Cursor Cloud API.
final agentsListProvider = FutureProvider.autoDispose<List<Agent>>((ref) async {
  final cache = await ref.watch(cacheServiceProvider.future);
  await ref.watch(apiBootstrapProvider.future);
  final api = ref.watch(apiServiceProvider);
  final list = await api.getAgents();
  if (list.isNotEmpty) await cache.saveAgents(list);
  return list;
});

/// Single agent by ID (for detail screen). Polling can be done by ref.invalidate.
final agentDetailProvider = FutureProvider.autoDispose.family<Agent?, String>((ref, id) async {
  if (id.isEmpty) return null;
  await ref.watch(apiBootstrapProvider.future);
  final api = ref.watch(apiServiceProvider);
  return api.getAgent(id);
});

/// Conversation for an agent.
final conversationProvider = FutureProvider.autoDispose.family<Conversation, String>((ref, agentId) async {
  if (agentId.isEmpty) return const Conversation(messages: []);
  await ref.watch(apiBootstrapProvider.future);
  final api = ref.watch(apiServiceProvider);
  return api.getConversation(agentId);
});

/// Artifacts for an agent.
final artifactsProvider = FutureProvider.autoDispose.family<List<Artifact>, String>((ref, agentId) async {
  if (agentId.isEmpty) return [];
  await ref.watch(apiBootstrapProvider.future);
  final api = ref.watch(apiServiceProvider);
  return api.getArtifacts(agentId);
});

/// Launch agent: POST /v0/agents. Returns agent ID on success.
final launchAgentProvider = FutureProvider.autoDispose.family<String?, LaunchRequest>((ref, request) async {
  await ref.watch(apiBootstrapProvider.future);
  final api = ref.watch(apiServiceProvider);
  final res = await api.launchAgent(request);
  ref.invalidate(agentsListProvider);
  return res.agentId.isNotEmpty ? res.agentId : null;
});

void invalidateAgentData(Ref ref, String agentId) {
  if (agentId.isEmpty) return;
  ref.invalidate(agentDetailProvider(agentId));
  ref.invalidate(conversationProvider(agentId));
  ref.invalidate(artifactsProvider(agentId));
  ref.invalidate(agentsListProvider);
}

void invalidateAgentDataFromWidget(WidgetRef ref, String agentId) {
  if (agentId.isEmpty) return;
  ref.invalidate(agentDetailProvider(agentId));
  ref.invalidate(conversationProvider(agentId));
  ref.invalidate(artifactsProvider(agentId));
  ref.invalidate(agentsListProvider);
}

final agentStreamConnectedProvider =
    StateProvider.autoDispose.family<bool, String>((ref, agentId) => false);

final agentStreamServiceProvider =
    FutureProvider.autoDispose<AgentStreamService?>((ref) async {
  final prefs = await ref.watch(preferencesProvider.future);
  final baseUrl = prefs.mordecaiCommissionsUrl.trim();
  if (baseUrl.isEmpty) return null;
  final storage = ref.watch(secureStorageProvider);
  final bridgeSecret = await storage.getMordecaiBridgeSecret();
  final fcmToken = await ref.watch(fcmTokenProvider.future);
  return AgentStreamService(
    mordecaiBaseUrl: baseUrl,
    bridgeSecret: bridgeSecret,
    fcmToken: fcmToken,
  );
});

final agentLiveEventsProvider =
    StreamProvider.autoDispose.family<AgentStreamEvent, String>((ref, agentId) async* {
  if (agentId.trim().isEmpty) return;
  final service = await ref.watch(agentStreamServiceProvider.future);
  if (service == null) return;
  final notificationPrefs = ref.watch(agentNotificationPreferencesProvider);

  try {
    await service.registerDevice(notificationPrefs);
    await service.watchAgent(agentId: agentId, preferences: notificationPrefs);
  } catch (_) {}

  ref.read(agentStreamConnectedProvider(agentId).notifier).state = true;
  ref.onDispose(() {
    ref.read(agentStreamConnectedProvider(agentId).notifier).state = false;
  });

  await for (final event
      in service.streamAgent(agentId: agentId, preferences: notificationPrefs)) {
    if (event.isConnectedSignal) {
      ref.read(agentStreamConnectedProvider(agentId).notifier).state = true;
      continue;
    }
    if (event.type == 'agent_running' && event.heartbeat) {
      continue;
    }
    invalidateAgentData(ref, agentId);
    yield event;
  }
});
