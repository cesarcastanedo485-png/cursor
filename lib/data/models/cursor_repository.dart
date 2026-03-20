/// GitHub / Cursor-linked repository from GET /v0/repositories.
class CursorRepository {
  const CursorRepository({
    required this.name,
    this.fullName,
    this.description,
    this.htmlUrl,
    this.cloneUrl,
    this.updatedAt,
  });

  final String name;
  final String? fullName;
  final String? description;
  final String? htmlUrl;
  final String? cloneUrl;
  final DateTime? updatedAt;

  String get repoUrl {
    if (htmlUrl != null && htmlUrl!.isNotEmpty) return htmlUrl!;
    if (cloneUrl != null && cloneUrl!.endsWith('.git')) {
      return cloneUrl!.replaceAll(RegExp(r'\.git$'), '');
    }
    if (fullName != null && fullName!.isNotEmpty) {
      return 'https://github.com/$fullName';
    }
    return 'https://github.com/$name';
  }

  static String? _ownerFromJson(dynamic v) {
    if (v is String) return v;
    if (v is Map) return (v['login'] ?? v['name'])?.toString();
    return null;
  }

  static CursorRepository fromJson(Map<String, dynamic> j) {
    DateTime? parsed;
    final u = j['updated_at'] ?? j['updatedAt'] ?? j['pushed_at'] ?? j['last_activity_at'];
    if (u is String) {
      parsed = DateTime.tryParse(u);
    }
    final owner = _ownerFromJson(j['owner']);
    final name = (j['name'] ?? j['repo'] ?? fullNameFrom(j) ?? 'repo').toString();
    final fullName = j['full_name'] as String? ?? j['fullName'] as String? ?? (owner != null ? '$owner/$name' : null);
    final repoUrlRaw = j['repository'] as String?;
    final htmlUrl = j['html_url'] as String? ?? j['htmlUrl'] as String? ?? j['url'] as String? ?? repoUrlRaw;
    return CursorRepository(
      name: name,
      fullName: fullName,
      description: j['description'] as String?,
      htmlUrl: htmlUrl,
      cloneUrl: j['clone_url'] as String? ?? j['cloneUrl'] as String?,
      updatedAt: parsed,
    );
  }

  static String? fullNameFrom(Map<String, dynamic> j) {
    final n = j['full_name'] ?? j['fullName'];
    if (n != null) return n.toString();
    final owner = _ownerFromJson(j['owner']);
    final name = j['name'] as String?;
    if (owner != null && name != null) return '$owner/$name';
    return null;
  }

  /// Build from a GitHub URL (e.g. https://github.com/owner/repo) for manual-add workaround.
  static CursorRepository? fromUrl(String url) {
    final s = url.trim();
    if (s.isEmpty) return null;
    String normalized = s;
    if (!normalized.startsWith('http')) normalized = 'https://github.com/$s';
    if (!normalized.contains('github.com')) return null;
    try {
      final uri = Uri.parse(normalized);
      final path = uri.pathSegments.where((e) => e.isNotEmpty).toList();
      if (path.length < 2) return null;
      final owner = path[0];
      final name = path[1].replaceAll(RegExp(r'\.git$'), '');
      final fullName = '$owner/$name';
      final htmlUrl = 'https://github.com/$fullName';
      return CursorRepository(
        name: name,
        fullName: fullName,
        htmlUrl: htmlUrl,
      );
    } catch (_) {
      return null;
    }
  }
}
