import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'core/apk_release_log.dart';
import 'core/app_strings.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'providers/auth_provider.dart';
import 'providers/agents_provider.dart';
import 'providers/notification_provider.dart';
import 'providers/preferences_provider.dart';
import 'providers/shell_providers.dart';
import 'providers/theme_provider.dart';
import 'screens/capabilities/capabilities_screen.dart';
import 'screens/cloud/cloud_agents_shell.dart';
import 'screens/commissions/commissions_screen.dart';
import 'screens/onboarding/onboarding_screen.dart';
import 'screens/whats_new/whats_new_screen.dart';
import 'services/notification_service.dart';

/// Global key for deep linking from push notifications.
final navigatorKey = GlobalKey<NavigatorState>();

/// Root widget: theme, onboarding gate, main shell (Cloud Agents / Capabilities / Commissions).
class App extends ConsumerWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final onboardingAsync = ref.watch(onboardingStateProvider);

    NotificationService.setNavigatorKey(navigatorKey);

    return MaterialApp(
      navigatorKey: navigatorKey,
      title: AppStrings.appName,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      debugShowCheckedModeBanner: false,
      onGenerateRoute: AppRouter.onGenerateRoute,
      home: onboardingAsync.when(
        data: (done) => done ? const _PostOnboardingGate() : const OnboardingScreen(),
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

enum _PostOnboardingState { loading, whatsNew, main }

class _PostOnboardingGate extends ConsumerStatefulWidget {
  const _PostOnboardingGate();

  @override
  ConsumerState<_PostOnboardingGate> createState() => _PostOnboardingGateState();
}

class _PostOnboardingGateState extends ConsumerState<_PostOnboardingGate> {
  _PostOnboardingState _state = _PostOnboardingState.loading;
  List<ApkReleaseEntry> _whatsNewEntries = [];
  PackageInfo? _packageInfo;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _check());
  }

  Future<void> _check() async {
    try {
      final info = await PackageInfo.fromPlatform();
      final prefs = await ref.read(preferencesProvider.future);
      final lastSeen = prefs.lastSeenVersion;

      if (lastSeen == null || lastSeen.isEmpty) {
        await prefs.setLastSeenVersion('${info.version}+${info.buildNumber}');
        if (!mounted) return;
        setState(() {
          _state = _PostOnboardingState.main;
          _packageInfo = info;
        });
        return;
      }

      final show = await shouldShowWhatsNew(info, lastSeen);
      if (!mounted) return;
      if (show) {
        final currentBuild = int.tryParse(info.buildNumber) ?? 0;
        final entries = getNewerReleaseEntries(lastSeen, currentBuild);
        setState(() {
          _state = _PostOnboardingState.whatsNew;
          _whatsNewEntries = entries;
          _packageInfo = info;
        });
      } else {
        setState(() {
          _state = _PostOnboardingState.main;
          _packageInfo = info;
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _state = _PostOnboardingState.main);
    }
  }

  void _onWhatsNewDismiss() async {
    if (_packageInfo == null) return;
    final prefs = await ref.read(preferencesProvider.future);
    await prefs.setLastSeenVersion('${_packageInfo!.version}+${_packageInfo!.buildNumber}');
    ref.invalidate(preferencesProvider);
    if (!mounted) return;
    setState(() => _state = _PostOnboardingState.main);
  }

  @override
  Widget build(BuildContext context) {
    switch (_state) {
      case _PostOnboardingState.loading:
        return const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        );
      case _PostOnboardingState.whatsNew:
        return WhatsNewScreen(
          entries: _whatsNewEntries,
          onDismiss: _onWhatsNewDismiss,
        );
      case _PostOnboardingState.main:
        return const _MainShellWithBottomNav();
    }
  }
}

class _MainShellWithBottomNav extends ConsumerWidget {
  const _MainShellWithBottomNav();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Start API-key hydration early so first cloud tab load does not flash auth errors.
    ref.watch(apiBootstrapProvider);
    return const _NotificationInit(
      child: _MainShellBody(),
    );
  }
}

class _NotificationInit extends ConsumerStatefulWidget {
  const _NotificationInit({required this.child});

  final Widget child;

  @override
  ConsumerState<_NotificationInit> createState() => _NotificationInitState();
}

class _NotificationInitState extends ConsumerState<_NotificationInit> {
  bool _initDone = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  Future<void> _init() async {
    if (_initDone || !mounted) return;
    _initDone = true;
    final prefs = await ref.read(preferencesProvider.future);
    ref.read(agentNotificationPreferencesProvider.notifier).state =
        AgentNotificationPreferences(
      creating: prefs.notifAgentCreating,
      running: prefs.notifAgentRunning,
      finished: prefs.notifAgentFinished,
      expired: prefs.notifAgentExpired,
      assistantMessage: prefs.notifAssistantMessage,
    );
    NotificationService.instance.setForegroundCallback((msg) {
      if (!mounted) return;
      ref.read(lastNotificationProvider.notifier).state = msg;
      ref.read(notificationUnreadCountProvider.notifier).update((n) => n + 1);
      final agentId = (msg.data['agentId'] ?? msg.data['id'] ?? '').toString();
      if (agentId.isNotEmpty) {
        invalidateAgentDataFromWidget(ref, agentId);
      }
    });
    await NotificationService.instance.init(ref);
    if (!mounted) return;
    if (NotificationService.hasPendingNavigation) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        NotificationService.handlePendingInitialMessage();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

class _MainShellBody extends ConsumerWidget {
  const _MainShellBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tab = ref.watch(mainShellTabProvider).clamp(0, 2);
    return Scaffold(
      body: IndexedStack(
        index: tab,
        children: const [
          CloudAgentsShell(),
          CapabilitiesScreen(),
          CommissionsScreen(),
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
            icon: Icon(Icons.extension_outlined),
            selectedIcon: Icon(Icons.extension_rounded),
            label: AppStrings.capabilities,
          ),
          NavigationDestination(
            icon: Icon(Icons.handyman_outlined),
            selectedIcon: Icon(Icons.handyman_rounded),
            label: AppStrings.commissions,
          ),
        ],
      ),
    );
  }
}
