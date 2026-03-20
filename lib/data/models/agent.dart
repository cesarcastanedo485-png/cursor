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

  static const Set<String> _runningStates = {
    'running',
    'in_progress',
    'processing',
    'working',
    'active',
  };
  static const Set<String> _pendingStates = {
    'queued',
    'pending',
    'created',
    'starting',
    'initializing',
    'waiting',
  };
  static const Set<String> _finishedStates = {
    'finished',
    'completed',
    'succeeded',
    'success',
    'done',
  };
  static const Set<String> _failedStates = {
    'failed',
    'error',
    'errored',
    'cancelled',
    'canceled',
    'aborted',
    'timeout',
    'timed_out',
  };

  String get normalizedStatus => status.trim().toLowerCase();
  static bool isRunningStatus(String value) => _runningStates.contains(value.trim().toLowerCase());
  static bool isPendingStatus(String value) => _pendingStates.contains(value.trim().toLowerCase());
  static bool isFinishedStatus(String value) => _finishedStates.contains(value.trim().toLowerCase());
  static bool isFailedStatus(String value) => _failedStates.contains(value.trim().toLowerCase());
  bool get isRunning => _runningStates.contains(normalizedStatus);
  bool get isPending => _pendingStates.contains(normalizedStatus);
  bool get isFinished => _finishedStates.contains(normalizedStatus);
  bool get isFailed => _failedStates.contains(normalizedStatus);
  bool get isActive => isRunning || isPending;
}
