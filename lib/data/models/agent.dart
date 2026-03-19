/// Agent model for list and detail (GET /v0/agents, GET /v0/agents/:id).
class Agent {
  const Agent({
    required this.id,
    required this.status,
    this.summary,
    this.repoName,
    this.repoUrl,
    this.createdAt,
    this.updatedAt,
    this.pullRequestUrl,
    this.branchName,
  });

  final String id;
  final String status; // e.g. "running", "finished", "failed"
  final String? summary;
  final String? repoName;
  final String? repoUrl;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? pullRequestUrl;
  final String? branchName;

  factory Agent.fromJson(Map<String, dynamic> json) {
    return Agent(
      id: json['id'] as String? ?? '',
      status: json['status'] as String? ?? 'unknown',
      summary: json['summary'] as String?,
      repoName: json['repo_name'] as String? ?? json['repository'] as String?,
      repoUrl: json['repo_url'] as String? ?? json['repository_url'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'] as String)
          : null,
      pullRequestUrl: json['pull_request_url'] as String? ?? json['pr_url'] as String?,
      branchName: json['branch_name'] as String? ?? json['branch'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'status': status,
      'summary': summary,
      'repo_name': repoName,
      'repo_url': repoUrl,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'pull_request_url': pullRequestUrl,
      'branch_name': branchName,
    };
  }

  bool get isRunning => status.toLowerCase() == 'running';
  bool get isFinished => status.toLowerCase() == 'finished';
  bool get isFailed => status.toLowerCase() == 'failed';
}
