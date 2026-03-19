import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../data/models/artifact.dart';

/// One artifact row: name, type, tap to open/download.
class ArtifactTile extends StatelessWidget {
  const ArtifactTile({
    super.key,
    required this.artifact,
    this.onTap,
  });

  final Artifact artifact;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final url = artifact.downloadUrl;
    return ListTile(
      leading: Icon(
        artifact.isImage ? Icons.image_rounded : Icons.code_rounded,
        color: Theme.of(context).colorScheme.primary,
      ),
      title: Text(
        artifact.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: artifact.type != null ? Text(artifact.type!) : null,
      trailing: const Icon(Icons.download_rounded),
      onTap: onTap ?? (url != null ? () => _openUrl(url) : null),
    );
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
