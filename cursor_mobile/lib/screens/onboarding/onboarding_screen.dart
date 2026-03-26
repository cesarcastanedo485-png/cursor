import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/app_strings.dart';
import '../../../core/constants.dart';
import '../../../providers/auth_provider.dart';
import '../../../widgets/connectivity_diagnostics.dart';

/// Onboarding: API key input, test connection, link to get key.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _keyController = TextEditingController();
  final _keyFocus = FocusNode();
  bool _obscure = true;
  bool _testing = false;
  String? _testError;
  bool _didPrefillKey = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _didPrefillKey) return;
      final v = ref.read(apiKeyProvider).valueOrNull;
      if (v != null && v.isNotEmpty) {
        setState(() {
          _keyController.text = v;
          _didPrefillKey = true;
        });
      }
    });
  }

  @override
  void dispose() {
    _keyController.dispose();
    _keyFocus.dispose();
    super.dispose();
  }

  Future<void> _testConnection() async {
    final key = _keyController.text.trim();
    if (key.isEmpty) {
      setState(() => _testError = 'Please enter your API key');
      return;
    }
    setState(() {
      _testing = true;
      _testError = null;
    });
    final notifier = ref.read(apiKeyProvider.notifier);
    await notifier.setKey(key);
    final err = await notifier.testConnection();
    if (!mounted) return;
    setState(() {
      _testing = false;
      _testError = err;
    });
    if (err == null) {
      await ref.read(onboardingStateProvider.notifier).complete();
    }
  }

  Future<void> _saveAndContinue() async {
    final key = _keyController.text.trim();
    if (key.isEmpty) {
      setState(() => _testError = 'Please enter your API key');
      return;
    }
    final notifier = ref.read(apiKeyProvider.notifier);
    await notifier.setKey(key);
    await ref.read(onboardingStateProvider.notifier).complete();
  }

  Future<void> _openHelp() async {
    final uri = Uri.parse(apiKeyHelpUrl);
    if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final keyAsync = ref.watch(apiKeyProvider);

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (keyAsync.hasError)
              MaterialBanner(
                content: Text(
                  'Could not read secure storage: ${keyAsync.error}',
                  style: const TextStyle(fontSize: 13),
                ),
                actions: [
                  TextButton(
                    onPressed: () => ref.invalidate(apiKeyProvider),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
              const SizedBox(height: 24),
              SvgPicture.asset(
                'assets/mm_logo.svg',
                width: 104,
                height: 104,
              ),
              const SizedBox(height: 16),
              Text(
                AppStrings.appName,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Connect your Cursor Pro API for Cloud Agents',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              Text(
                'API Key',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _keyController,
                focusNode: _keyFocus,
                obscureText: _obscure,
                decoration: InputDecoration(
                  hintText: 'Paste your Cloud Agents API key',
                  suffixIcon: IconButton(
                    icon: Icon(_obscure ? Icons.visibility_rounded : Icons.visibility_off_rounded),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
                onChanged: (_) => setState(() => _testError = null),
              ),
              if (_testError != null) ...[
                const SizedBox(height: 12),
                Text(
                  _testError!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 13),
                ),
              ],
              const SizedBox(height: 24),
              const ConnectivityDiagnosticsCard(),
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: _openHelp,
                icon: const Icon(Icons.help_outline_rounded, size: 20),
                label: const Text('Where do I get my API key?'),
              ),
              const SizedBox(height: 8),
              Text(
                'Go to Cursor Dashboard → Cloud Agents to copy your API key.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 32),
              FilledButton.icon(
                onPressed: _testing ? null : _testConnection,
                icon: _testing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check_circle_outline_rounded, size: 20),
                label: Text(_testing ? 'Testing…' : 'Test connection'),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: _testing ? null : _saveAndContinue,
                child: const Text('Save and continue without testing'),
              ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
