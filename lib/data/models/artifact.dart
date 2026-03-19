/// Artifact from GET /v0/agents/:id/artifacts (with optional presigned download URL).
class Artifact {
  const Artifact({
    required this.id,
    required this.name,
    this.type,
    this.url,
    this.presignedUrl,
    this.mimeType,
  });

  final String id;
  final String name;
  final String? type; // e.g. "file", "image"
  final String? url;
  final String? presignedUrl; // use for download if present
  final String? mimeType;

  factory Artifact.fromJson(Map<String, dynamic> json) {
    return Artifact(
      id: json['id'] as String? ?? json['artifact_id'] as String? ?? '',
      name: json['name'] as String? ?? json['filename'] as String? ?? 'artifact',
      type: json['type'] as String?,
      url: json['url'] as String? ?? json['download_url'] as String?,
      presignedUrl: json['presigned_url'] as String? ?? json['url'] as String?,
      mimeType: json['mime_type'] as String? ?? json['content_type'] as String?,
    );
  }

  /// URL to use for opening/downloading (presigned preferred).
  String? get downloadUrl => presignedUrl ?? url;

  bool get isImage =>
      (mimeType?.startsWith('image/') ?? false) ||
      (type?.toLowerCase() == 'image') ||
      _imageExtensions.any((e) => name.toLowerCase().endsWith(e));
  static const _imageExtensions = ['.png', '.jpg', '.jpeg', '.gif', '.webp', '.svg'];
}
