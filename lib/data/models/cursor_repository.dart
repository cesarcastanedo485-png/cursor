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

  static CursorRepository fromJson(Map<String, dynamic> j) {
    DateTime? parsed;
    final u = j['updated_at'] ?? j['updatedAt'] ?? j['pushed_at'] ?? j['last_activity_at'];
    if (u is String) {
      parsed = DateTime.tryParse(u);
    }
    return CursorRepository(
      name: (j['name'] ?? j['repo'] ?? j['repository'] ?? fullNameFrom(j) ?? 'repo').toString(),
      fullName: j['full_name'] as String? ?? j['fullName'] as String?,
      description: j['description'] as String?,
      htmlUrl: j['html_url'] as String? ?? j['htmlUrl'] as String? ?? j['url'] as String?,
      cloneUrl: j['clone_url'] as String? ?? j['cloneUrl'] as String?,
      updatedAt: parsed,
    );
  }

  static String? fullNameFrom(Map<String, dynamic> j) {
    final n = j['full_name'] ?? j['fullName'];
    return n?.toString();
  }
}
