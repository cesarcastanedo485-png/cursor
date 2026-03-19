import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
                      onPressed: () => _showTestDialog(context, c),
                      child: const Text('Test'),
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

  void _showTestDialog(BuildContext context, CapabilityItem c) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Test: ${c.title}'),
        content: const SingleChildScrollView(
          child: Text(
            'No real action is performed from this app (no SMS, post, or device action). '
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
              TextField(
                controller: apiKey,
                decoration: const InputDecoration(
                  labelText: 'API key (optional)',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                obscureText: true,
              ),
              const SizedBox(height: 12),
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
              const SizedBox(height: 12),
              TextField(
                controller: folderPath,
                decoration: const InputDecoration(
                  labelText: 'Folder path (e.g. for file watch)',
                  hintText: '/path/to/folder',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
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
