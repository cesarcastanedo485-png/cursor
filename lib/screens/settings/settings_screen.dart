import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/app_strings.dart';
import '../../../core/constants.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/backend_mode_provider.dart';
import '../../../providers/repositories_provider.dart';
import '../../../providers/preferences_provider.dart';
import '../../../providers/theme_provider.dart';
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
  final _host = TextEditingController();
  final _ollamaPort = TextEditingController();
  final _comfyPort = TextEditingController();
  final _mordecaiUrl = TextEditingController();
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
    _host.dispose();
    _ollamaPort.dispose();
    _comfyPort.dispose();
    _mordecaiUrl.dispose();
    super.dispose();
  }

  Future<void> _loadPrefs() async {
    final prefs = await ref.read(preferencesProvider.future);
    if (!mounted) return;
    _host.text = prefs.localServerHost;
    _ollamaPort.text = prefs.localOllamaPort;
    _comfyPort.text = prefs.localComfyPort;
    _mordecaiUrl.text = prefs.mordecaiCommissionsUrl;
    setState(() => _prefsLoaded = true);
  }

  Future<void> _saveMordecaiUrl() async {
    final prefs = await ref.read(preferencesProvider.future);
    await prefs.setMordecaiCommissionsUrl(_mordecaiUrl.text.trim());
    ref.invalidate(preferencesProvider);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Mordecai URL saved. Commissions tab will load it.')),
    );
  }

  Future<void> _saveLocalDefaults() async {
    final prefs = await ref.read(preferencesProvider.future);
    await prefs.setLocalServerHost(_host.text.trim().isEmpty ? '192.168.1.100' : _host.text.trim());
    await prefs.setLocalOllamaPort(_ollamaPort.text.trim().isEmpty ? '11434' : _ollamaPort.text.trim());
    await prefs.setLocalComfyPort(_comfyPort.text.trim().isEmpty ? '8188' : _comfyPort.text.trim());
    await ref.read(backendStateProvider.notifier).refreshFromPrefs();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Local defaults saved. Update each Private AI URL in My Private AIs if needed.')),
    );
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

  Future<void> _openHelp() async {
    final uri = Uri.parse(apiKeyHelpUrl);
    if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
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

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: !_prefsLoaded
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                const SizedBox(height: 8),
                ListTile(
                  leading: const Icon(Icons.hub_rounded),
                  title: const Text('Connect GitHub'),
                  subtitle: const Text('Why repos may be missing + tips'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: _showConnectGithub,
                ),
                const Divider(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Text(
                    'API keys & secrets (tap to open)',
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
                  icon: Icons.link_rounded,
                  title: 'Connect GitHub to Cursor',
                  url: cursorConnectGithubUrl,
                ),
                const _LinkTile(
                  icon: Icons.token_rounded,
                  title: 'GitHub tokens (PAT)',
                  url: githubTokensUrl,
                ),
                const _LinkTile(
                  icon: Icons.extension_rounded,
                  title: 'GitHub connections',
                  url: githubConnectionsUrl,
                ),
                const _LinkTile(
                  icon: Icons.security_rounded,
                  title: 'Repo secrets (Actions)',
                  subtitle: 'For APK build',
                  url: 'https://github.com/cesarcastanedo485-png/cursor/settings/secrets/actions',
                ),
                const _LinkTile(
                  icon: Icons.download_rounded,
                  title: 'Download APK (Releases)',
                  url: githubReleasesUrl,
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Text(
                    'Commissions (Mordecai URL)',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: TextField(
                    controller: _mordecaiUrl,
                    decoration: const InputDecoration(
                      labelText: 'Mordecai URL',
                      hintText: 'https://yourserver.com or ngrok URL',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: FilledButton(
                    onPressed: _saveMordecaiUrl,
                    child: const Text('Save Mordecai URL'),
                  ),
                ),
                const Divider(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Text(
                    'Local private server defaults',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'Used as defaults when you add Private AIs (Ollama / ComfyUI on your LAN or Tailscale IP).',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: TextField(
                    controller: _host,
                    decoration: const InputDecoration(
                      labelText: 'Server IP or hostname',
                      hintText: '192.168.1.100',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _ollamaPort,
                          decoration: const InputDecoration(
                            labelText: 'Ollama port',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _comfyPort,
                          decoration: const InputDecoration(
                            labelText: 'ComfyUI port',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: FilledButton(
                    onPressed: _saveLocalDefaults,
                    child: const Text('Save local defaults'),
                  ),
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
                ListTile(
                  leading: const Icon(Icons.help_outline_rounded),
                  title: const Text('Get Cursor API key'),
                  subtitle: const Text('Dashboard → Cloud Agents'),
                  onTap: _openHelp,
                ),
                ListTile(
                  leading: const Icon(Icons.menu_book_rounded),
                  title: const Text('Private AIs setup'),
                  subtitle: const Text('See SETUP_PRIVATE_AIs.md in the project folder'),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Open SETUP_PRIVATE_AIs.md on your PC for Ollama, ComfyUI, and Tailscale steps.'),
                      ),
                    );
                  },
                ),
                const Divider(),
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
