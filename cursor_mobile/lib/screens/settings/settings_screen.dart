import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/app_strings.dart';
import '../../../core/constants.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/repositories_provider.dart';
import '../../../providers/preferences_provider.dart';
import '../../../providers/theme_provider.dart';
import '../../../providers/bridge_task_provider.dart';
import '../../../providers/notification_provider.dart';
import '../../../providers/agents_provider.dart';
import '../../../providers/entitlements_provider.dart';
import '../../../services/mordecai_health_service.dart';
import '../../../widgets/connectivity_diagnostics.dart';

/// Settings: API, Connect GitHub hint, local server defaults, theme, reset.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _testing = false;
  String? _testResult;
  final _mordecaiUrl = TextEditingController();
  final _mordecaiBridgeSecret = TextEditingController();
  bool _prefsLoaded = false;
  PackageInfo? _packageInfo;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadPackageInfo());
  }

  Future<void> _loadPackageInfo() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (mounted) setState(() => _packageInfo = info);
    } catch (_) {
      // Web/desktop edge cases — footer falls back to app name only.
    }
  }

  @override
  void dispose() {
    _mordecaiUrl.dispose();
    _mordecaiBridgeSecret.dispose();
    super.dispose();
  }

  Future<void> _loadPrefs() async {
    final prefs = await ref.read(preferencesProvider.future);
    final storage = ref.read(secureStorageProvider);
    if (!mounted) return;
    _mordecaiUrl.text = prefs.mordecaiCommissionsUrl;
    final secret = await storage.getMordecaiBridgeSecret();
    _mordecaiBridgeSecret.text = secret ?? '';
    ref.read(agentNotificationPreferencesProvider.notifier).state =
        AgentNotificationPreferences(
      creating: prefs.notifAgentCreating,
      running: prefs.notifAgentRunning,
      finished: prefs.notifAgentFinished,
      expired: prefs.notifAgentExpired,
      assistantMessage: prefs.notifAssistantMessage,
    );
    setState(() => _prefsLoaded = true);
  }

  Future<void> _saveMordecaiUrl() async {
    final validation = MordecaiHealthService.validateForCommissions(
      _mordecaiUrl.text.trim(),
    );
    if (!validation.isValid) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(validation.error ?? 'Invalid Mordecai URL.')),
      );
      return;
    }
    if (validation.hasWarning) {
      final proceed = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Mordecai URL warning'),
              content: Text(validation.warning!),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Save anyway'),
                ),
              ],
            ),
          ) ??
          false;
      if (!proceed) return;
    }

    final prefs = await ref.read(preferencesProvider.future);
    await prefs.setMordecaiCommissionsUrl(validation.normalizedUrl);
    _mordecaiUrl.text = validation.normalizedUrl;
    ref.invalidate(preferencesProvider);
    ref.invalidate(bridgeTaskServiceProvider);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Mordecai URL saved. Commissions tab will load it.'),
      ),
    );
  }

  Future<void> _saveMordecaiBridgeSecret() async {
    final storage = ref.read(secureStorageProvider);
    await storage.setMordecaiBridgeSecret(
      _mordecaiBridgeSecret.text.trim().isEmpty ? null : _mordecaiBridgeSecret.text.trim(),
    );
    ref.invalidate(bridgeTaskServiceProvider);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Bridge secret saved.')),
    );
  }

  Future<void> _setNotificationPref({
    required String key,
    required bool value,
  }) async {
    final prefs = await ref.read(preferencesProvider.future);
    final current = ref.read(agentNotificationPreferencesProvider);
    switch (key) {
      case 'creating':
        await prefs.setNotifAgentCreating(value);
        ref.read(agentNotificationPreferencesProvider.notifier).state =
            AgentNotificationPreferences(
          creating: value,
          running: current.running,
          finished: current.finished,
          expired: current.expired,
          assistantMessage: current.assistantMessage,
        );
        break;
      case 'running':
        await prefs.setNotifAgentRunning(value);
        ref.read(agentNotificationPreferencesProvider.notifier).state =
            AgentNotificationPreferences(
          creating: current.creating,
          running: value,
          finished: current.finished,
          expired: current.expired,
          assistantMessage: current.assistantMessage,
        );
        break;
      case 'finished':
        await prefs.setNotifAgentFinished(value);
        ref.read(agentNotificationPreferencesProvider.notifier).state =
            AgentNotificationPreferences(
          creating: current.creating,
          running: current.running,
          finished: value,
          expired: current.expired,
          assistantMessage: current.assistantMessage,
        );
        break;
      case 'expired':
        await prefs.setNotifAgentExpired(value);
        ref.read(agentNotificationPreferencesProvider.notifier).state =
            AgentNotificationPreferences(
          creating: current.creating,
          running: current.running,
          finished: current.finished,
          expired: value,
          assistantMessage: current.assistantMessage,
        );
        break;
      case 'assistant_message':
        await prefs.setNotifAssistantMessage(value);
        ref.read(agentNotificationPreferencesProvider.notifier).state =
            AgentNotificationPreferences(
          creating: current.creating,
          running: current.running,
          finished: current.finished,
          expired: current.expired,
          assistantMessage: value,
        );
        break;
      default:
        break;
    }
    ref.invalidate(preferencesProvider);
    final updated = ref.read(agentNotificationPreferencesProvider);
    try {
      final streamService = await ref.read(agentStreamServiceProvider.future);
      await streamService?.registerDevice(updated);
    } catch (_) {}
  }

  Future<void> _testKey() async {
    setState(() {
      _testing = true;
      _testResult = null;
    });
    final err = await ref.read(apiKeyProvider.notifier).testConnection();
    if (!mounted) return;
    if (err == null) {
      ref.invalidate(repositoriesProvider);
    }
    setState(() {
      _testing = false;
      _testResult = err ?? 'Connection successful!';
    });
  }

  Future<void> _openCursorConnectGithub() async {
    final uri = Uri.parse(cursorConnectGithubUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _showConnectGithub() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Why don\'t I see my repos?'),
        content: const SingleChildScrollView(
          child: Text(
            'Repos in this app come from Cursor, not directly from GitHub. '
            'You must connect your GitHub account to Cursor first.\n\n'
            '1. Open the link below (on your computer is easiest).\n'
            '2. Sign in to Cursor and connect your GitHub account.\n'
            '3. Come back here and pull to refresh in My Repos.\n\n'
            'Your GitHub repos only show up after that connection is done.',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              _openCursorConnectGithub();
            },
            child: const Text('Connect GitHub in Cursor'),
          ),
        ],
      ),
    );
  }

  Future<void> _resetOnboarding() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset API Key'),
        content: const Text(
          'This will clear your saved API key and show the onboarding screen again. Continue?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Reset')),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(apiKeyProvider.notifier).clearKey();
      await ref.read(onboardingStateProvider.notifier).reset();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_prefsLoaded) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadPrefs());
    }

    final themeMode = ref.watch(themeModeProvider);
    final isDark = themeMode == ThemeMode.dark;
    final notifPrefs = ref.watch(agentNotificationPreferencesProvider);
    final pro = ref.watch(isProProvider);
    final prefsAsync = ref.watch(preferencesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: !_prefsLoaded
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                const SizedBox(height: 8),
                ListTile(
                  leading: const Icon(Icons.hub_rounded),
                  title: const Text('Connect GitHub to Cursor'),
                  subtitle: const Text('Why repos show up here · step-by-step'),
                  trailing: IconButton(
                    tooltip: 'Open Cursor (browser)',
                    icon: const Icon(Icons.open_in_new_rounded),
                    onPressed: _openCursorConnectGithub,
                  ),
                  onTap: _showConnectGithub,
                ),
                const Divider(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Text(
                    'Quick links',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                const _LinkTile(
                  icon: Icons.vpn_key_rounded,
                  title: 'Cursor API key',
                  subtitle: 'Dashboard → Cloud Agents',
                  url: apiKeyHelpUrl,
                ),
                const _LinkTile(
                  icon: Icons.token_rounded,
                  title: 'GitHub tokens (PAT)',
                  url: githubTokensUrl,
                ),
                const _LinkTile(
                  icon: Icons.extension_rounded,
                  title: 'GitHub connected apps',
                  url: githubConnectionsUrl,
                ),
                _LinkTile(
                  icon: Icons.security_rounded,
                  title: 'Repo secrets (Actions)',
                  subtitle: 'CI / APK builds',
                  url: githubDefaultActionsSecretsUrl,
                ),
                const _LinkTile(
                  icon: Icons.download_rounded,
                  title: 'Download APK',
                  subtitle: 'GitHub Releases',
                  url: githubReleasesUrl,
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Text(
                    'Mordecai server',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: TextField(
                    controller: _mordecaiUrl,
                    decoration: const InputDecoration(
                      labelText: 'Public URL',
                      hintText: 'https://your-tunnel.trycloudflare.com',
                      helperText:
                          'HTTPS only on phone. Dev: run_with_repo_env.ps1 fills this from repo .env.',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: FilledButton(
                    onPressed: _saveMordecaiUrl,
                    child: const Text('Save URL'),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Text(
                    'Bridge secret',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: TextField(
                    controller: _mordecaiBridgeSecret,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'MORDECAI_BRIDGE_SECRET',
                      hintText: 'Must match the Node server .env value',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: FilledButton(
                    onPressed: _saveMordecaiBridgeSecret,
                    child: const Text('Save bridge secret'),
                  ),
                ),
                const Divider(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Text(
                    'Agent notification toggles',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                SwitchListTile(
                  secondary: const Icon(Icons.fiber_new_rounded),
                  title: const Text('Agent creating'),
                  subtitle: const Text('Notify when an agent starts'),
                  value: notifPrefs.creating,
                  onChanged: (v) => _setNotificationPref(key: 'creating', value: v),
                ),
                SwitchListTile(
                  secondary: const Icon(Icons.sync_rounded),
                  title: const Text('Agent running'),
                  subtitle: const Text('Notify while an agent is actively working'),
                  value: notifPrefs.running,
                  onChanged: (v) => _setNotificationPref(key: 'running', value: v),
                ),
                SwitchListTile(
                  secondary: const Icon(Icons.check_circle_rounded),
                  title: const Text('Agent finished'),
                  subtitle: const Text('Notify when work completes'),
                  value: notifPrefs.finished,
                  onChanged: (v) => _setNotificationPref(key: 'finished', value: v),
                ),
                SwitchListTile(
                  secondary: const Icon(Icons.error_outline_rounded),
                  title: const Text('Agent expired'),
                  subtitle: const Text('Notify if agent becomes invalid/expired'),
                  value: notifPrefs.expired,
                  onChanged: (v) => _setNotificationPref(key: 'expired', value: v),
                ),
                SwitchListTile(
                  secondary: const Icon(Icons.chat_bubble_outline_rounded),
                  title: const Text('Assistant messages'),
                  subtitle: const Text('Notify on each new assistant message'),
                  value: notifPrefs.assistantMessage,
                  onChanged: (v) => _setNotificationPref(key: 'assistant_message', value: v),
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.vpn_key_rounded),
                  title: const Text('Test Cursor API connection'),
                  subtitle: Text(_testResult ?? (_testing ? 'Testing…' : 'Cloud Agents API key')),
                  trailing: _testing
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : IconButton(
                          icon: const Icon(Icons.play_arrow_rounded),
                          onPressed: _testing ? null : _testKey,
                        ),
                ),
                if (_testResult != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      _testResult!,
                      style: TextStyle(
                        color: _testResult == 'Connection successful!'
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.error,
                        fontSize: 13,
                      ),
                    ),
                  ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: ConnectivityDiagnosticsCard(),
                ),
                const Divider(),
                SwitchListTile(
                  secondary: const Icon(Icons.dark_mode_rounded),
                  title: const Text('Dark mode'),
                  value: isDark,
                  onChanged: (v) => ref.read(themeModeProvider.notifier).setDark(v),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: Text(
                    'Mordechaius Pro',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.workspace_premium_outlined),
                  title: const Text('Pro status'),
                  subtitle: Text(
                    pro
                        ? 'Active — thank you!'
                        : 'Unlock unlimited launch presets, OLED theme, and more when store SKUs are live.',
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.restore_rounded),
                  title: const Text('Restore purchases'),
                  subtitle: const Text('After subscribing on this store account'),
                  onTap: () async {
                    await ref.read(billingServiceProvider).restorePurchases();
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Restore complete. Pro unlocks when the billing backend is configured.')),
                    );
                  },
                ),
                SwitchListTile(
                  secondary: const Icon(Icons.contrast_rounded),
                  title: const Text('OLED black (dark theme)'),
                  subtitle: Text(
                    pro
                        ? 'Use true black surfaces when dark mode is on'
                        : 'Requires Mordechaius Pro',
                  ),
                  value: pro && (prefsAsync.valueOrNull?.preferAmoledTheme ?? false),
                  onChanged: pro
                      ? (v) async {
                          final p = await ref.read(preferencesProvider.future);
                          await p.setPreferAmoledTheme(v);
                          ref.invalidate(preferencesProvider);
                        }
                      : null,
                ),
                ListTile(
                  leading: const Icon(Icons.info_outline_rounded),
                  title: const Text('About'),
                  subtitle: const Text('Version & APK change log'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.of(context).pushNamed(AppRoutes.about),
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.logout_rounded),
                  title: const Text('Reset API key & onboarding'),
                  onTap: _resetOnboarding,
                ),
                const SizedBox(height: 24),
                Center(
                  child: Text(
                    _packageInfo == null
                        ? AppStrings.appName
                        : '${AppStrings.appName} v${_packageInfo!.version} (build ${_packageInfo!.buildNumber})',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _LinkTile extends StatelessWidget {
  const _LinkTile({
    required this.icon,
    required this.title,
    required this.url,
    this.subtitle,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final String url;

  Future<void> _openUrl(BuildContext context) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: subtitle != null ? Text(subtitle!) : null,
      trailing: const Icon(Icons.open_in_new_rounded, size: 18),
      onTap: () => _openUrl(context),
    );
  }
}
