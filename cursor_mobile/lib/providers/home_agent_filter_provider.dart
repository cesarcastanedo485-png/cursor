import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/agent.dart';

/// Home (Agents) list filter — client-side only.
enum HomeAgentFilter { all, active, finished, failed }

final homeAgentFilterProvider = StateProvider<HomeAgentFilter>((ref) => HomeAgentFilter.all);

List<Agent> filterAgentsForHome(List<Agent> agents, HomeAgentFilter f) {
  switch (f) {
    case HomeAgentFilter.all:
      return agents;
    case HomeAgentFilter.active:
      return agents.where((a) => a.isActive).toList();
    case HomeAgentFilter.finished:
      return agents.where((a) => a.isFinished).toList();
    case HomeAgentFilter.failed:
      return agents.where((a) => a.isFailed).toList();
  }
}
