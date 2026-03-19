import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/app_strings.dart';
import 'core/theme/app_theme.dart';
import 'core/router/app_router.dart';
import 'providers/auth_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/shell_providers.dart';
import 'screens/onboarding/onboarding_screen.dart';
import 'screens/cloud/cloud_agents_shell.dart';
import 'screens/private_ais/private_ais_screen.dart';
import 'screens/capabilities/capabilities_screen.dart';
import 'widgets/active_ai_banner.dart';

/// Root widget: onboarding gate + 3-tab shell (Cloud Agents / Private AIs / Capabilities).
class App extends ConsumerWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final onboarding = ref.watch(onboardingStateProvider);

    return MaterialApp(
      title: AppStrings.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      home: onboarding.when(
        data: (done) {
          if (done) return const _MainShell();
          return const OnboardingScreen();
        },
        loading: () => const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
        error: (_, __) => const OnboardingScreen(),
      ),
      onGenerateRoute: AppRouter.onGenerateRoute,
    );
  }
}

class _MainShell extends ConsumerStatefulWidget {
  const _MainShell();

  @override
  ConsumerState<_MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<_MainShell> {
  static const _tabs = [
    _TabData(Icons.cloud_rounded, AppStrings.cloudAgents, CloudAgentsShell()),
    _TabData(Icons.psychology_rounded, AppStrings.privateAis, PrivateAisScreen()),
    _TabData(Icons.auto_awesome_rounded, AppStrings.capabilities, CapabilitiesScreen()),
  ];

  @override
  Widget build(BuildContext context) {
    final index = ref.watch(mainShellTabProvider).clamp(0, _tabs.length - 1);

    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const ActiveAiBanner(),
          Expanded(
            child: IndexedStack(
              index: index,
              children: _tabs.map((t) => t.screen).toList(),
            ),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) => ref.read(mainShellTabProvider.notifier).state = i,
        destinations: _tabs
            .map(
              (t) => NavigationDestination(
                icon: Icon(t.icon),
                label: t.label,
              ),
            )
            .toList(),
      ),
    );
  }
}

class _TabData {
  const _TabData(this.icon, this.label, this.screen);
  final IconData icon;
  final String label;
  final Widget screen;
}
