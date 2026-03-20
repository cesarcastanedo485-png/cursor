import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/app_strings.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'providers/auth_provider.dart';
import 'providers/shell_providers.dart';
import 'providers/theme_provider.dart';
import 'screens/capabilities/capabilities_screen.dart';
import 'screens/cloud/cloud_agents_shell.dart';
import 'screens/onboarding/onboarding_screen.dart';
import 'screens/private_ais/private_ais_screen.dart';
import 'widgets/active_ai_banner.dart';

/// Root widget: theme, onboarding gate, main shell (Cloud Agents / Private AIs / Capabilities).
class App extends ConsumerWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final onboardingAsync = ref.watch(onboardingStateProvider);

    return MaterialApp(
      title: AppStrings.appName,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      debugShowCheckedModeBanner: false,
      onGenerateRoute: AppRouter.onGenerateRoute,
      home: onboardingAsync.when(
        data: (done) => done ? const _MainShellWithBottomNav() : const OnboardingScreen(),
        loading: () => const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
        error: (e, st) => Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Could not load setup state',
                    style: Theme.of(context).textTheme.titleMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    e.toString(),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: () => ref.invalidate(onboardingStateProvider),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MainShellWithBottomNav extends ConsumerWidget {
  const _MainShellWithBottomNav();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tab = ref.watch(mainShellTabProvider).clamp(0, 2);

    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const ActiveAiBanner(),
          Expanded(
            child: IndexedStack(
              index: tab,
              children: const [
                CloudAgentsShell(),
                PrivateAisScreen(),
                CapabilitiesScreen(),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (i) => ref.read(mainShellTabProvider.notifier).state = i,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.cloud_outlined),
            selectedIcon: Icon(Icons.cloud_rounded),
            label: AppStrings.cloudAgents,
          ),
          NavigationDestination(
            icon: Icon(Icons.psychology_outlined),
            selectedIcon: Icon(Icons.psychology_rounded),
            label: AppStrings.privateAis,
          ),
          NavigationDestination(
            icon: Icon(Icons.extension_outlined),
            selectedIcon: Icon(Icons.extension_rounded),
            label: AppStrings.capabilities,
          ),
        ],
      ),
    );
  }
}
