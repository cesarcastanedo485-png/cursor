/// Request body for POST /v0/agents (launch agent).
class LaunchRequest {
  const LaunchRequest({
    required this.repoUrl,
    required this.prompt,
    this.ref,
    this.branchName,
    this.model,
    this.autoCreatePr = false,
    this.imageBase64,
  });

  final String repoUrl;
  final String prompt;
  final String? ref; // branch/tag/ref
  final String? branchName;
  final String? model; // e.g. "default", "claude-4-sonnet"
  final bool autoCreatePr;
  final String? imageBase64; // optional image attachment (base64)

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'repo_url': repoUrl,
      'prompt': prompt,
      'auto_create_pr': autoCreatePr,
    };
    if (ref != null && ref!.isNotEmpty) map['ref'] = ref;
    if (branchName != null && branchName!.isNotEmpty) map['branch_name'] = branchName;
    if (model != null && model!.isNotEmpty) map['model'] = model;
    if (imageBase64 != null && imageBase64!.isNotEmpty) map['image'] = imageBase64;
    return map;
  }
}

/// Response from POST /v0/agents.
class LaunchResponse {
  const LaunchResponse({required this.agentId});

  final String agentId;

  factory LaunchResponse.fromJson(Map<String, dynamic> json) {
    return LaunchResponse(
      agentId: json['agent_id'] as String? ?? json['id'] as String? ?? '',
    );
  }
}
