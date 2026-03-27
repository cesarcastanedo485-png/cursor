import 'package:uuid/uuid.dart';

import '../../core/agent_intent.dart';

/// Saved launch form values (local only). [prompt] is the raw user text (not intent-wrapped).
class LaunchPreset {
  const LaunchPreset({
    required this.id,
    required this.name,
    required this.repoUrl,
    required this.branch,
    required this.prompt,
    required this.intentName,
    required this.model,
    required this.autoCreatePr,
    required this.useDesktop,
    required this.createdAtMs,
    required this.updatedAtMs,
    this.lastUsedAtMs,
  });

  final String id;
  final String name;
  final String repoUrl;
  final String branch;
  final String prompt;

  /// [AgentIntent.name] string.
  final String intentName;
  final String model;
  final bool autoCreatePr;
  final bool useDesktop;
  final int createdAtMs;
  final int updatedAtMs;
  final int? lastUsedAtMs;

  AgentIntent get intent => _parseIntent(intentName);

  factory LaunchPreset.create({
    required String name,
    required String repoUrl,
    required String branch,
    required String prompt,
    required AgentIntent intent,
    required String model,
    required bool autoCreatePr,
    required bool useDesktop,
  }) {
    final now = DateTime.now().millisecondsSinceEpoch;
    return LaunchPreset(
      id: const Uuid().v4(),
      name: name,
      repoUrl: repoUrl,
      branch: branch,
      prompt: prompt,
      intentName: intent.name,
      model: model,
      autoCreatePr: autoCreatePr,
      useDesktop: useDesktop,
      createdAtMs: now,
      updatedAtMs: now,
      lastUsedAtMs: null,
    );
  }

  LaunchPreset copyWith({
    String? name,
    String? repoUrl,
    String? branch,
    String? prompt,
    AgentIntent? intent,
    String? model,
    bool? autoCreatePr,
    bool? useDesktop,
    int? lastUsedAtMs,
    int? updatedAtMs,
  }) {
    final now = DateTime.now().millisecondsSinceEpoch;
    return LaunchPreset(
      id: id,
      name: name ?? this.name,
      repoUrl: repoUrl ?? this.repoUrl,
      branch: branch ?? this.branch,
      prompt: prompt ?? this.prompt,
      intentName: intent?.name ?? intentName,
      model: model ?? this.model,
      autoCreatePr: autoCreatePr ?? this.autoCreatePr,
      useDesktop: useDesktop ?? this.useDesktop,
      createdAtMs: createdAtMs,
      updatedAtMs: updatedAtMs ?? now,
      lastUsedAtMs: lastUsedAtMs ?? this.lastUsedAtMs,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'repoUrl': repoUrl,
      'branch': branch,
      'prompt': prompt,
      'intentName': intentName,
      'model': model,
      'autoCreatePr': autoCreatePr,
      'useDesktop': useDesktop,
      'createdAtMs': createdAtMs,
      'updatedAtMs': updatedAtMs,
      'lastUsedAtMs': lastUsedAtMs,
    };
  }

  factory LaunchPreset.fromJson(Map<String, dynamic> json) {
    return LaunchPreset(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'Untitled',
      repoUrl: json['repoUrl'] as String? ?? '',
      branch: json['branch'] as String? ?? '',
      prompt: json['prompt'] as String? ?? '',
      intentName: json['intentName'] as String? ?? AgentIntent.normal.name,
      model: json['model'] as String? ?? 'auto',
      autoCreatePr: json['autoCreatePr'] as bool? ?? false,
      useDesktop: json['useDesktop'] as bool? ?? true,
      createdAtMs: (json['createdAtMs'] as num?)?.toInt() ?? 0,
      updatedAtMs: (json['updatedAtMs'] as num?)?.toInt() ?? 0,
      lastUsedAtMs: (json['lastUsedAtMs'] as num?)?.toInt(),
    );
  }
}

AgentIntent _parseIntent(String raw) {
  for (final v in AgentIntent.values) {
    if (v.name == raw) return v;
  }
  return AgentIntent.normal;
}
