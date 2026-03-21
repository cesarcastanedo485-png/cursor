import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/agent_intent.dart';

/// Main shell: 0 Cloud Agents, 1 Private AIs, 2 Capabilities.
final mainShellTabProvider = StateProvider<int>((ref) => 0);

/// Cloud Agents sub-tab: 0 Home, 1 Launch, 2 Repos, 3 Settings.
final cloudAgentsSubTabProvider = StateProvider<int>((ref) => 0);

/// Incremented whenever Launch tab should clear previous draft input.
final launchTabResetCounterProvider = StateProvider<int>((ref) => 0);

final launchRepoPrefillProvider = StateProvider<String?>((ref) => null);
final launchIntentPrefillProvider = StateProvider<AgentIntent?>((ref) => null);
