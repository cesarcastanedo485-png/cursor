import 'package:flutter/material.dart';
import '../constants.dart';
import '../../screens/onboarding/onboarding_screen.dart';
import '../../screens/home/home_screen.dart';
import '../../screens/launch/launch_agent_screen.dart';
import '../../screens/agents/my_agents_screen.dart';
import '../../screens/agent_detail/agent_detail_screen.dart';
import '../../screens/settings/settings_screen.dart';
import '../../screens/settings/about_screen.dart';

/// Simple named route map (no go_router dependency for routing logic).
class AppRouter {
  static Route<dynamic>? onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case AppRoutes.onboarding:
        return MaterialPageRoute(builder: (_) => const OnboardingScreen());
      case AppRoutes.home:
        return MaterialPageRoute(builder: (_) => const HomeScreen());
      case AppRoutes.launch:
        return MaterialPageRoute(builder: (_) => const LaunchAgentScreen());
      case AppRoutes.agents:
        return MaterialPageRoute(builder: (_) => const MyAgentsScreen());
      case AppRoutes.settings:
        return MaterialPageRoute(builder: (_) => const SettingsScreen());
      case AppRoutes.about:
        return MaterialPageRoute(builder: (_) => const AboutScreen());
      case AppRoutes.agentDetail:
        final id = settings.arguments as String?;
        return MaterialPageRoute(
          builder: (_) => AgentDetailScreen(agentId: id ?? ''),
        );
      default:
        return MaterialPageRoute(builder: (_) => const HomeScreen());
    }
  }
}
