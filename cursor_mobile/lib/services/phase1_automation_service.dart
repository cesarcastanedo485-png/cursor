import 'package:dio/dio.dart';

class Phase1AutomationService {
  Phase1AutomationService({
    required String mordecaiBaseUrl,
    String? bridgeSecret,
  })  : _baseUrl = mordecaiBaseUrl.endsWith("/")
            ? mordecaiBaseUrl.substring(0, mordecaiBaseUrl.length - 1)
            : mordecaiBaseUrl,
        _bridgeSecret = bridgeSecret?.trim(),
        _dio = Dio(BaseOptions(
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 30),
          headers: const {
            "Content-Type": "application/json",
            "Accept": "application/json",
          },
        ));

  final String _baseUrl;
  final String? _bridgeSecret;
  final Dio _dio;

  Map<String, String> get _headers {
    final out = <String, String>{};
    if (_bridgeSecret != null && _bridgeSecret!.isNotEmpty) {
      out["X-Bridge-Secret"] = _bridgeSecret!;
    }
    return out;
  }

  Future<Phase1AutomationConfig> getConfig() async {
    final res = await _dio.get<Map<String, dynamic>>(
      "$_baseUrl/api/phase1/config",
      options: Options(headers: _headers),
    );
    final config = (res.data?["config"] as Map?)?.cast<String, dynamic>() ??
        const <String, dynamic>{};
    return Phase1AutomationConfig.fromJson(config);
  }

  Future<Phase1AutomationConfig> updateConfig(
      Phase1AutomationConfig next) async {
    final res = await _dio.post<Map<String, dynamic>>(
      "$_baseUrl/api/phase1/config",
      options: Options(headers: _headers),
      data: next.toJson(),
    );
    final config = (res.data?["config"] as Map?)?.cast<String, dynamic>() ??
        const <String, dynamic>{};
    return Phase1AutomationConfig.fromJson(config);
  }

  Future<Phase1AutomationStatus> getStatus() async {
    final res = await _dio.get<Map<String, dynamic>>(
      "$_baseUrl/api/phase1/status",
      options: Options(headers: _headers),
    );
    final status = (res.data?["status"] as Map?)?.cast<String, dynamic>() ??
        const <String, dynamic>{};
    return Phase1AutomationStatus.fromJson(status);
  }

  Future<List<Phase1RunSummary>> getRuns({int limit = 8}) async {
    final res = await _dio.get<Map<String, dynamic>>(
      "$_baseUrl/api/phase1/runs",
      queryParameters: {"limit": limit},
      options: Options(headers: _headers),
    );
    final rows = (res.data?["runs"] as List?) ?? const [];
    return rows
        .whereType<Map>()
        .map((row) => Phase1RunSummary.fromJson(row.cast<String, dynamic>()))
        .toList();
  }
}

class Phase1AutomationConfig {
  const Phase1AutomationConfig({
    required this.autoReplyEnabled,
    required this.clipPipelineEnabled,
    required this.enabledPlatforms,
    required this.autoReplyTemplate,
  });

  final bool autoReplyEnabled;
  final bool clipPipelineEnabled;
  final List<String> enabledPlatforms;
  final String autoReplyTemplate;

  factory Phase1AutomationConfig.defaults() => const Phase1AutomationConfig(
        autoReplyEnabled: true,
        clipPipelineEnabled: true,
        enabledPlatforms: ["facebook", "messenger", "tiktok", "youtube"],
        autoReplyTemplate:
            "Thanks for reaching out. We saw your message and will follow up shortly.",
      );

  factory Phase1AutomationConfig.fromJson(Map<String, dynamic> json) {
    final platforms = (json["enabledPlatforms"] as List?)
            ?.map((p) => p.toString().trim().toLowerCase())
            .where((p) => p.isNotEmpty)
            .toList() ??
        const <String>["facebook", "messenger", "tiktok", "youtube"];
    return Phase1AutomationConfig(
      autoReplyEnabled: json["autoReplyEnabled"] == true,
      clipPipelineEnabled: json["clipPipelineEnabled"] == true,
      enabledPlatforms: platforms,
      autoReplyTemplate: (json["autoReplyTemplate"] ?? "").toString().trim(),
    );
  }

  Map<String, dynamic> toJson() => {
        "autoReplyEnabled": autoReplyEnabled,
        "clipPipelineEnabled": clipPipelineEnabled,
        "enabledPlatforms": enabledPlatforms,
        "autoReplyTemplate": autoReplyTemplate,
      };

  Phase1AutomationConfig copyWith({
    bool? autoReplyEnabled,
    bool? clipPipelineEnabled,
    List<String>? enabledPlatforms,
    String? autoReplyTemplate,
  }) {
    return Phase1AutomationConfig(
      autoReplyEnabled: autoReplyEnabled ?? this.autoReplyEnabled,
      clipPipelineEnabled: clipPipelineEnabled ?? this.clipPipelineEnabled,
      enabledPlatforms: enabledPlatforms ?? this.enabledPlatforms,
      autoReplyTemplate: autoReplyTemplate ?? this.autoReplyTemplate,
    );
  }
}

class Phase1AutomationStatus {
  const Phase1AutomationStatus({
    required this.acceptedEvents,
    required this.dedupedEvents,
    required this.processedEvents,
    required this.pendingDeadLetters,
    required this.runHistoryCount,
  });

  final int acceptedEvents;
  final int dedupedEvents;
  final int processedEvents;
  final int pendingDeadLetters;
  final int runHistoryCount;

  factory Phase1AutomationStatus.fromJson(Map<String, dynamic> json) =>
      Phase1AutomationStatus(
        acceptedEvents: (json["acceptedEvents"] as num?)?.toInt() ?? 0,
        dedupedEvents: (json["dedupedEvents"] as num?)?.toInt() ?? 0,
        processedEvents: (json["processedEvents"] as num?)?.toInt() ?? 0,
        pendingDeadLetters: (json["pendingDeadLetters"] as num?)?.toInt() ?? 0,
        runHistoryCount: (json["runHistoryCount"] as num?)?.toInt() ?? 0,
      );
}

class Phase1RunSummary {
  const Phase1RunSummary({
    required this.runId,
    required this.eventType,
    required this.platform,
    required this.status,
    required this.finishedAt,
  });

  final String runId;
  final String eventType;
  final String platform;
  final String status;
  final String finishedAt;

  factory Phase1RunSummary.fromJson(Map<String, dynamic> json) =>
      Phase1RunSummary(
        runId: (json["runId"] ?? "").toString(),
        eventType: (json["eventType"] ?? "").toString(),
        platform: (json["platform"] ?? "").toString(),
        status: (json["status"] ?? "").toString(),
        finishedAt: (json["finishedAt"] ?? "").toString(),
      );
}
