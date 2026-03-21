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
    // Cursor Cloud Agents API expects a nested request body.
    // Docs schema (high level):
    // {
    //   "prompt": { "text": "..." },
    //   "model": "default" | "...",
    //   "source": { "repository": "...", "ref": "..." },
    //   "target": { "autoCreatePr": true, "branchName": "..." }
    // }
    //
    // We intentionally omit image payloads for now because the API requires
    // per-image dimensions ("dimension": {width,height}) and this app doesn't
    // currently compute them during launch.
    final sourceRef = (ref != null && ref!.isNotEmpty) ? ref : null;

    final map = <String, dynamic>{
      'prompt': <String, dynamic>{
        'text': prompt,
      },
      'source': <String, dynamic>{
        'repository': repoUrl,
        if (sourceRef != null) 'ref': sourceRef,
      },
    };

    // Always send explicit PR intent so backend defaults cannot create a PR
    // when the user has not enabled that option.
    map['target'] = <String, dynamic>{
      'autoCreatePr': autoCreatePr,
      if (branchName != null && branchName!.isNotEmpty) 'branchName': branchName,
    };

    final chosenModel = (model ?? '').trim();
    if (chosenModel.isNotEmpty && chosenModel != 'default') {
      map['model'] = chosenModel;
    }

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
