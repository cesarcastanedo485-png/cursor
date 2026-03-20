import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/app_strings.dart';
import '../../data/capabilities_catalog.dart';
import '../../data/capability_instruction_manual.dart';
import '../../data/local/secure_storage_service.dart';
import '../../providers/auth_provider.dart';
import '../../providers/capability_config_provider.dart';

class CapabilitiesScreen extends StatelessWidget {
  const CapabilitiesScreen({super.key});

  static final _docLinks = <String, Uri>{
    'YouTube API': Uri.parse('https://developers.google.com/youtube/v3'),
    'Alexa skills': Uri.parse('https://developer.amazon.com/alexa/console/ask'),
    'OBS WebSocket': Uri.parse('https://github.com/obsproject/obs-websocket/blob/master/docs/generated/protocol.md'),
    'Twilio SMS': Uri.parse('https://www.twilio.com/docs/sms'),
    'SendGrid email': Uri.parse('https://docs.sendgrid.com/for-developers/sending-email/api-getting-started'),
    'Meta Messenger': Uri.parse('https://developers.facebook.com/docs/messenger-platform'),
  };

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(AppStrings.capabilities),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Tools'),
              Tab(text: 'Instruction manual'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _ToolsTab(docLinks: _docLinks),
            _ManualTab(docLinks: _docLinks),
          ],
        ),
      ),
    );
  }
}

class _ToolsTab extends ConsumerWidget {
  const _ToolsTab({required this.docLinks});

  final Map<String, Uri> docLinks;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final configsAsync = ref.watch(allCapabilityConfigsProvider);

    if (configsAsync.hasError) {
      return ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Icon(Icons.error_outline_rounded, size: 48, color: Theme.of(context).colorScheme.error),
          const SizedBox(height: 12),
          Text(
            'Could not load capability settings',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            configsAsync.error.toString(),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => ref.invalidate(allCapabilityConfigsProvider),
            child: const Text('Retry'),
          ),
        ],
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: kCapabilitiesCatalog.length + 1,
      itemBuilder: (context, i) {
        if (i == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text(
              'Automation hooks: use Manual for setup steps; Configure stores API keys and URLs; Test is a safe check (real actions need a desktop bridge).',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          );
        }
        final c = kCapabilitiesCatalog[i - 1];
        final config = configsAsync.valueOrNull?[c.id];
        final isConfigured = config?.isConfigured ?? false;

        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(c.title, style: Theme.of(context).textTheme.titleSmall),
                    ),
                    if (isConfigured)
                      Chip(
                        label: Text(
                          'Configured',
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: Theme.of(context).colorScheme.primary,
                              ),
                        ),
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                  ],
                ),
                Text(c.summary, style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: [
                    FilledButton.tonal(
                      onPressed: () => _showTestDialog(context, ref, c, config),
                      child: const Text('Test'),
                    ),
                    if (isConfigured)
                      FilledButton(
                        onPressed: () => _showExecuteOrActionPicker(context, ref, c),
                        child: const Text('Execute'),
                      ),
                    OutlinedButton(
                      onPressed: () => _showManualSheet(context, c),
                      child: const Text('Manual'),
                    ),
                    TextButton(
                      onPressed: () => _showConfigureSheet(context, ref, c, config),
                      child: const Text('Configure'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showTestDialog(
    BuildContext context,
    WidgetRef ref,
    CapabilityItem c,
    CapabilityConfig? config,
  ) async {
    // Check for updates: test download URL reachability
    if (c.id == 'drive_download') {
      final downloadUrl = config?.folderPath.trim() ?? '';
      if (downloadUrl.isEmpty) {
        if (!context.mounted) return;
        showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text('Test: ${c.title}'),
            content: const Text(
              'Add the direct download URL in Configure (Folder path). '
              'Use: https://drive.google.com/uc?export=download&id=FILE_ID',
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
            ],
          ),
        );
        return;
      }
      try {
        showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => const AlertDialog(
            content: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)),
                SizedBox(width: 16),
                Text('Checking URL…'),
              ],
            ),
          ),
        );
        final dio = Dio(BaseOptions(
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 15),
          followRedirects: true,
          maxRedirects: 5,
          validateStatus: (code) => code != null && code < 500,
        ));
        // Google Drive often rejects HEAD; use small ranged GET
        await dio.get<void>(
          downloadUrl,
          options: Options(headers: const {'Range': 'bytes=0-0'}),
        );
        if (!context.mounted) return;
        Navigator.pop(context);
        showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text('Test: ${c.title}'),
            content: const Text('Download URL is reachable. You can use Execute to download and install.'),
            actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))],
          ),
        );
      } catch (e) {
        if (!context.mounted) return;
        Navigator.pop(context);
        showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text('Test: ${c.title}'),
            content: Text('URL check failed: $e'),
            actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))],
          ),
        );
      }
      return;
    }
    final hasWebhook = config?.webhookUrl.trim().isNotEmpty ?? false;
    if (hasWebhook) {
      // Actually ping the webhook to verify connectivity
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => const AlertDialog(
          content: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 16),
              Text('Testing webhook…'),
            ],
          ),
        ),
      );
      final service = ref.read(capabilityServiceProvider);
      final err = await service.pingWebhook(c.id);
      if (!context.mounted) return;
      Navigator.pop(context);
      showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('Test: ${c.title}'),
          content: Text(
            err == null
                ? 'Webhook responded successfully. Your bridge/server is reachable.'
                : 'Ping failed: $err',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } else {
      showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('Test: ${c.title}'),
          content: const SingleChildScrollView(
            child: Text(
              'Add a webhook URL in Configure to test connectivity. '
              'For real automation, set up a desktop bridge or server using the Instruction manual tab, '
              'then add credentials in Configure.',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(ctx);
                launchUrl(
                  Uri.parse('https://github.com/obsproject/obs-websocket'),
                  mode: LaunchMode.externalApplication,
                );
              },
              child: const Text('Open docs'),
            ),
          ],
        ),
      );
    }
  }

  static const _smartHomeCapabilityIds = {'smarthome_lights', 'smarthome_thermostat', 'smarthome_alexa'};

  Future<void> _showExecuteOrActionPicker(
    BuildContext context,
    WidgetRef ref,
    CapabilityItem c,
  ) async {
    // Email: show To/Subject/Body form
    if (c.id == 'email') {
      await _showEmailFormAndSend(context, ref, c);
      return;
    }
    // Upload to Drive: send webhook
    if (c.id == 'drive_upload') {
      await _executeCapability(context, ref, c, action: 'upload_apk', actionLabel: 'Upload to Drive');
      return;
    }
    // Check for updates: download from URL and install
    if (c.id == 'drive_download') {
      await _executeCheckForUpdates(context, ref, c);
      return;
    }
    if (!_smartHomeCapabilityIds.contains(c.id)) {
      await _executeCapability(context, ref, c, action: 'run', actionLabel: null);
      return;
    }
    final actions = _getSmartHomeActions(c.id);
    if (actions.isEmpty) {
      await _executeCapability(context, ref, c, action: 'run', actionLabel: null);
      return;
    }
    final picked = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Choose action', style: Theme.of(ctx).textTheme.titleMedium),
            ),
            ...actions.map(
              (a) => ListTile(
                title: Text(a.label),
                onTap: () => Navigator.pop(ctx, a.action),
              ),
            ),
          ],
        ),
      ),
    );
    if (!context.mounted || picked == null) return;
    await _executeCapability(context, ref, c, action: picked, actionLabel: actions.firstWhere((a) => a.action == picked).label);
  }

  static List<({String action, String label})> _getSmartHomeActions(String id) {
    switch (id) {
      case 'smarthome_lights':
        return [
          (action: 'lights_on', label: 'Turn on lights'),
          (action: 'lights_off', label: 'Turn off lights'),
          (action: 'lights_dim_50', label: 'Dim to 50%'),
          (action: 'lights_dim_100', label: 'Brightness 100%'),
        ];
      case 'smarthome_thermostat':
        return [
          (action: 'thermostat_70', label: 'Set to 70°F'),
          (action: 'thermostat_72', label: 'Set to 72°F'),
          (action: 'thermostat_74', label: 'Set to 74°F'),
          (action: 'thermostat_heat', label: 'Switch to Heat'),
          (action: 'thermostat_cool', label: 'Switch to Cool'),
        ];
      case 'smarthome_alexa':
        return [
          (action: 'alexa_routine', label: 'Run Alexa routine'),
          (action: 'alexa_volume_up', label: 'Volume up'),
          (action: 'alexa_volume_down', label: 'Volume down'),
        ];
      default:
        return [];
    }
  }

  Future<void> _showEmailFormAndSend(
    BuildContext context,
    WidgetRef ref,
    CapabilityItem c,
  ) async {
    final to = TextEditingController();
    final subject = TextEditingController();
    final body = TextEditingController();

    final send = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 8,
          bottom: MediaQuery.viewInsetsOf(ctx).bottom + 16,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Send email', style: Theme.of(ctx).textTheme.titleLarge),
              const SizedBox(height: 16),
              TextField(
                controller: to,
                decoration: const InputDecoration(
                  labelText: 'To',
                  hintText: 'recipient@example.com',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: subject,
                decoration: const InputDecoration(
                  labelText: 'Subject',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: body,
                decoration: const InputDecoration(
                  labelText: 'Body',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                maxLines: 4,
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Send'),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
            ],
          ),
        ),
      ),
    );

    if (!context.mounted || send != true) return;

    final payload = <String, dynamic>{
      'capability_title': c.title,
      'email_to': to.text.trim(),
      'email_subject': subject.text.trim(),
      'email_body': body.text.trim(),
    };
    await _executeCapability(
      context,
      ref,
      c,
      action: 'send_email',
      actionLabel: null,
      extraPayload: payload,
    );
  }

  Future<void> _executeCheckForUpdates(
    BuildContext context,
    WidgetRef ref,
    CapabilityItem c,
  ) async {
    final storage = ref.read(secureStorageProvider);
    final config = await storage.getCapabilityConfig('drive_download');
    final downloadUrl = config?.folderPath.trim();
    if (downloadUrl == null || downloadUrl.isEmpty) {
      if (!context.mounted) return;
      showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(c.title),
          content: const Text(
            'Add a download URL in Configure first (direct link to your APK on Google Drive).',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    final parsed = Uri.tryParse(downloadUrl);
    if (parsed == null ||
        (parsed.scheme != 'http' && parsed.scheme != 'https') ||
        parsed.host.isEmpty) {
      if (!context.mounted) return;
      showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(c.title),
          content: const Text(
            'Invalid download URL. Use a direct link (e.g. https://drive.google.com/uc?export=download&id=FILE_ID).',
          ),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))],
        ),
      );
      return;
    }

    if (!context.mounted) return;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const AlertDialog(
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)),
            SizedBox(width: 16),
            Text('Downloading…'),
          ],
        ),
      ),
    );

    var loadingDialogPopped = false;
    void popLoading() {
      if (loadingDialogPopped || !context.mounted) return;
      loadingDialogPopped = true;
      Navigator.of(context).pop();
    }

    String? err;
    try {
      final dio = Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 120),
        followRedirects: true,
        maxRedirects: 5,
      ));
      final dir = await getTemporaryDirectory();
      final path = '${dir.path}/mordechaius_maximus_update.apk';
      await dio.download(downloadUrl, path);
      popLoading();
      if (!context.mounted) return;

      final result = await OpenFile.open(path);
      if (!context.mounted) return;
      if (result.type != ResultType.done) {
        err = result.message.isNotEmpty
            ? result.message
            : 'Could not open installer. Allow install from unknown sources if prompted.';
      }
    } on DioException catch (e) {
      err = 'Download failed: ${e.message ?? e.type}';
      popLoading();
    } catch (e) {
      err = e.toString();
      popLoading();
    }

    if (!context.mounted) return;
    if (err != null) {
      showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(c.title),
          content: Text(err!),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))],
        ),
      );
    }
  }

  Future<void> _executeCapability(
    BuildContext context,
    WidgetRef ref,
    CapabilityItem c, {
    String? action,
    String? actionLabel,
    Map<String, dynamic>? extraPayload,
  }) async {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const AlertDialog(
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 16),
            Text('Executing…'),
          ],
        ),
      ),
    );
    final service = ref.read(capabilityServiceProvider);
    final payload = <String, dynamic>{
      'capability_title': c.title,
      if (extraPayload == null) ...{
        'smart_home_action': action ?? 'run',
        if (actionLabel != null) 'smart_home_action_label': actionLabel,
      },
      ...?extraPayload,
    };
    final err = await service.execute(c.id, action: action ?? 'execute', payload: payload);
    if (!context.mounted) return;
    Navigator.pop(context);
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Execute: ${c.title}'),
        content: Text(
          err == null
              ? 'Command sent to your bridge/server. Check your desktop or server for results.'
              : 'Execution failed: $err',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showManualSheet(BuildContext context, CapabilityItem c) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.95,
        builder: (_, scroll) => ListView(
          controller: scroll,
          padding: const EdgeInsets.all(20),
          children: [
            Text(c.title, style: Theme.of(ctx).textTheme.titleLarge),
            const SizedBox(height: 12),
            ...c.manualSteps.map(
              (s) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('• '),
                    Expanded(child: Text(s)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showConfigureSheet(
    BuildContext context,
    WidgetRef ref,
    CapabilityItem c,
    CapabilityConfig? initial,
  ) async {
    final apiKey = TextEditingController(text: initial?.apiKey ?? '');
    final webhookUrl = TextEditingController(text: initial?.webhookUrl ?? '');
    final folderPath = TextEditingController(text: initial?.folderPath ?? '');

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 8,
          bottom: MediaQuery.viewInsetsOf(ctx).bottom + 16,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(c.title, style: Theme.of(ctx).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(
                'Stored securely. Used when you add a desktop bridge or server.',
                style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                      color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 16),
              if (c.id != 'drive_download')
                TextField(
                  controller: apiKey,
                  decoration: InputDecoration(
                    labelText: c.id == 'email' ? 'API key (optional — e.g. SendGrid if bridge uses it)' : 'API key (optional)',
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                  obscureText: true,
                ),
              if (c.id != 'drive_download') const SizedBox(height: 12),
              if (c.id != 'drive_download')
                TextField(
                  controller: webhookUrl,
                  decoration: const InputDecoration(
                    labelText: 'Webhook URL',
                    hintText: 'https://…',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  keyboardType: TextInputType.url,
                ),
              if (c.id != 'drive_download') const SizedBox(height: 12),
              TextField(
                controller: folderPath,
                decoration: InputDecoration(
                  labelText: switch (c.id) {
                    'drive_download' => 'Download URL (Drive direct link)',
                    'drive_upload' => 'APK path on PC (optional)',
                    _ => 'Folder path (e.g. for file watch)',
                  },
                  hintText: switch (c.id) {
                    'drive_download' => 'https://drive.google.com/uc?export=download&id=…',
                    'drive_upload' => r'C:\path\to\app-release.apk',
                    _ => '/path/to/folder',
                  },
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
                keyboardType: c.id == 'drive_download' ? TextInputType.url : TextInputType.text,
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () async {
                  final storage = ref.read(secureStorageProvider);
                  await storage.setCapabilityConfig(
                    c.id,
                    CapabilityConfig(
                      apiKey: apiKey.text.trim(),
                      webhookUrl: webhookUrl.text.trim(),
                      folderPath: folderPath.text.trim(),
                    ),
                  );
                  ref.invalidate(allCapabilityConfigsProvider);
                  if (ctx.mounted) Navigator.pop(ctx);
                },
                child: const Text('Save'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ManualTab extends StatelessWidget {
  const _ManualTab({required this.docLinks});

  final Map<String, Uri> docLinks;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Platform setup guides for the Tools tab. Mordechaius Maximus runs hooks; full automation usually needs a secure desktop or cloud bridge.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: 16),
        Text('Quick doc links', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: docLinks.entries
              .map(
                (e) => ActionChip(
                  label: Text(e.key),
                  onPressed: () => launchUrl(e.value, mode: LaunchMode.externalApplication),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 24),
        ...kCapabilityInstructionManual.map(
          (m) => Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ExpansionTile(
              title: Text(m.title, style: Theme.of(context).textTheme.titleSmall),
              children: [
                for (var j = 0; j < m.steps.length; j++)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${j + 1}. ', style: Theme.of(context).textTheme.labelLarge),
                          Expanded(
                            child: _richStepText(context, m.steps[j]),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Renders step text with **bold** as bold.
  Widget _richStepText(BuildContext context, String text) {
    final spans = <InlineSpan>[];
    var i = 0;
    while (i < text.length) {
      final start = text.indexOf('**', i);
      if (start == -1) {
        spans.add(TextSpan(text: text.substring(i), style: Theme.of(context).textTheme.bodyMedium));
        break;
      }
      spans.add(TextSpan(text: text.substring(i, start), style: Theme.of(context).textTheme.bodyMedium));
      final end = text.indexOf('**', start + 2);
      if (end == -1) {
        spans.add(TextSpan(text: text.substring(start), style: Theme.of(context).textTheme.bodyMedium));
        break;
      }
      spans.add(TextSpan(
        text: text.substring(start + 2, end),
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
      ));
      i = end + 2;
    }
    return RichText(text: TextSpan(children: spans, style: Theme.of(context).textTheme.bodyMedium));
  }
}
