import 'dart:convert';
import 'package:dio/dio.dart';
import '../core/constants.dart';
import '../core/api_errors.dart';
import '../data/models/agent.dart';
import '../data/models/artifact.dart';
import '../data/models/conversation.dart';
import '../data/models/launch_request.dart';
import '../data/models/cursor_repository.dart';

/// Cursor Cloud Agents API client.
/// Base URL: https://api.cursor.com
/// Auth: Basic base64(apiKey + ":").
///
/// Use only for Cursor Cloud. Local/private AI uses [LocalOpenAiService].
class ApiService {
  ApiService({String? apiKey}) : _apiKey = apiKey {
    _dio = Dio(BaseOptions(
      baseUrl: apiBaseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
    ));
    _dio.interceptors.add(_UnauthInterceptor());
    if (_apiKey != null && _apiKey!.isNotEmpty) _addAuth();
  }

  String? _apiKey;
  late final Dio _dio;

  void setApiKey(String key) {
    _apiKey = key;
    _addAuth();
  }

  void clearApiKey() {
    _apiKey = null;
    _dio.interceptors.removeWhere((e) => e is _AuthInterceptor);
  }

  void _addAuth() {
    _dio.interceptors.removeWhere((e) => e is _AuthInterceptor);
    _dio.interceptors.add(_AuthInterceptor(_apiKey!));
  }

  /// GET /v0/repositories — linked GitHub repos (Cursor Cloud).
  Future<List<CursorRepository>> getRepositories() async {
    final r = await _dio.get<dynamic>('/v0/repositories');
    final data = r.data;
    if (data == null) return [];
    List<dynamic> list;
    if (data is List) {
      list = data;
    } else if (data is Map && data['repositories'] is List) {
      list = data['repositories'] as List<dynamic>;
    } else if (data is Map && data['data'] is List) {
      list = data['data'] as List<dynamic>;
    } else {
      return [];
    }
    return list
        .map((e) => CursorRepository.fromJson(e is Map<String, dynamic> ? e : Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  /// GET /v0/agents — list agents (verify key with this for "test connection").
  Future<List<Agent>> getAgents() async {
    final r = await _dio.get<dynamic>('/v0/agents');
    final data = r.data;
    if (data == null) return [];
    if (data is List) {
      return data.map((e) => Agent.fromJson(e as Map<String, dynamic>)).toList();
    }
    if (data is Map && data['agents'] != null) {
      final list = data['agents'] as List<dynamic>;
      return list.map((e) => Agent.fromJson(e as Map<String, dynamic>)).toList();
    }
    return [];
  }

  /// GET /v0/agents/:id — single agent detail.
  Future<Agent> getAgent(String id) async {
    final r = await _dio.get<Map<String, dynamic>>('/v0/agents/$id');
    return Agent.fromJson(r.data ?? {});
  }

  /// GET /v0/agents/:id/conversation — conversation history.
  Future<Conversation> getConversation(String agentId) async {
    final r = await _dio.get<dynamic>('/v0/agents/$agentId/conversation');
    final data = r.data;
    if (data is Map<String, dynamic>) return Conversation.fromJson(data);
    if (data is List) return Conversation.fromList(data);
    return const Conversation(messages: []);
  }

  /// GET /v0/agents/:id/artifacts — list artifacts.
  Future<List<Artifact>> getArtifacts(String agentId) async {
    final r = await _dio.get<dynamic>('/v0/agents/$agentId/artifacts');
    final data = r.data;
    if (data == null) return [];
    if (data is List) {
      return data.map((e) => Artifact.fromJson(e as Map<String, dynamic>)).toList();
    }
    if (data is Map && data['artifacts'] != null) {
      final list = data['artifacts'] as List<dynamic>;
      return list.map((e) => Artifact.fromJson(e as Map<String, dynamic>)).toList();
    }
    return [];
  }

  /// POST /v0/agents — launch new agent.
  Future<LaunchResponse> launchAgent(LaunchRequest request) async {
    final r = await _dio.post<Map<String, dynamic>>('/v0/agents', data: request.toJson());
    return LaunchResponse.fromJson(r.data ?? {});
  }

  /// POST /v0/agents/:id/messages (or /conversation) — send follow-up message.
  Future<void> sendMessage(String agentId, String content) async {
    try {
      await _dio.post('/v0/agents/$agentId/messages', data: {'content': content});
    } catch (_) {
      await _dio.post('/v0/agents/$agentId/conversation', data: {'message': content});
    }
  }

  /// Artifact download: use presigned URL from artifact; this returns the URL string.
  String? getArtifactDownloadUrl(Artifact a) => a.downloadUrl;
}

/// Interceptor that adds Basic Auth header.
class _AuthInterceptor extends Interceptor {
  _AuthInterceptor(this.apiKey);

  final String apiKey;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final credentials = '$apiKey:';
    final encoded = base64Encode(utf8.encode(credentials));
    options.headers['Authorization'] = 'Basic $encoded';
    handler.next(options);
  }
}

/// Interceptor that turns 401 into [UnauthorizedException].
class _UnauthInterceptor extends Interceptor {
  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    if (response.statusCode == 401) {
      handler.reject(
        DioException(
          requestOptions: response.requestOptions,
          response: response,
          type: DioExceptionType.badResponse,
          error: UnauthorizedException(),
        ),
      );
      return;
    }
    handler.next(response);
  }
}
