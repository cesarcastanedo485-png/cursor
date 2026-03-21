import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/agent.dart';
import '../data/models/artifact.dart';
import '../data/models/conversation.dart';
import '../data/models/launch_request.dart';
import 'auth_provider.dart';
import 'backend_mode_provider.dart';
import 'cache_provider.dart';

/// List of agents (from API when Cursor Cloud; cached-only when Private AI mode).
final agentsListProvider = FutureProvider.autoDispose<List<Agent>>((ref) async {
  final mode = ref.watch(appBackendModeProvider);
  final cache = await ref.watch(cacheServiceProvider.future);
  if (mode == AppBackendMode.privateLocal) {
    return cache.getCachedAgents();
  }
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
