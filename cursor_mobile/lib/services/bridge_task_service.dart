import 'package:dio/dio.dart';

/// Service to submit agent tasks to Mordecai desktop bridge (saves Cloud API tokens).
class BridgeTaskService {
  BridgeTaskService({
    required this.mordecaiBaseUrl,
    String? bridgeSecret,
  })  : _bridgeSecret = bridgeSecret,
        _dio = Dio(BaseOptions(
          connectTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(seconds: 30),
          headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
        ));

  final String mordecaiBaseUrl;
  final String? _bridgeSecret;
  final Dio _dio;

  String get _baseUrl => mordecaiBaseUrl.endsWith('/')
      ? mordecaiBaseUrl.substring(0, mordecaiBaseUrl.length - 1)
      : mordecaiBaseUrl;

  Map<String, String> get _headers {
    final h = <String, String>{};
    final secret = _bridgeSecret?.trim();
    if (secret != null && secret.isNotEmpty) {
      h['X-Bridge-Secret'] = secret;
    }
    return h;
  }

  /// Submit a task to the desktop bridge. Returns taskId on success.
  Future<BridgeTaskResult> submitTask({
    required String prompt,
    required String repoUrl,
    String? branch,
    String intent = 'normal',
    String? fcmToken,
  }) async {
    try {
      final url = '$_baseUrl/api/bridge/tasks';
      final minuteBucket = DateTime.now().millisecondsSinceEpoch ~/ 60000;
      final dedupeKey =
          '${repoUrl.trim()}|${branch?.trim() ?? ''}|${intent.trim()}|${prompt.trim()}|$minuteBucket';
      final res = await _dio.post<Map<String, dynamic>>(
        url,
        data: {
          'prompt': prompt,
          'repoUrl': repoUrl,
          if (branch != null && branch.isNotEmpty) 'branch': branch,
          'intent': intent,
          if (fcmToken != null && fcmToken.isNotEmpty) 'fcmToken': fcmToken,
          'idempotencyKey': dedupeKey,
        },
        options: Options(headers: _headers),
      );
      final data = res.data;
      if (data == null) {
        return BridgeTaskResult.error('No response from server');
      }
      final taskId = data['taskId'] as String?;
      if (taskId == null || taskId.isEmpty) {
        return BridgeTaskResult.error('Invalid response: missing taskId');
      }
      return BridgeTaskResult.success(taskId: taskId);
    } on DioException catch (e) {
      final code = e.response?.statusCode;
      final msg = e.response?.data is Map
          ? (e.response!.data as Map)['error']?.toString()
          : null;
      if (code == 401) {
        return BridgeTaskResult.error('Bridge secret required or invalid');
      }
      if (code == 404 || code == 502 || code == 503) {
        return BridgeTaskResult.error(
          'Desktop bridge not available. Check Mordecai URL or use Cloud Agents.',
        );
      }
      return BridgeTaskResult.error(
        msg ?? e.message ?? 'Request failed (HTTP $code)',
      );
    } catch (e) {
      return BridgeTaskResult.error(e.toString());
    }
  }

  /// Lightweight readiness check for desktop bridge routing.
  Future<BridgeReadiness> checkReadiness() async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '$_baseUrl/api/bridge/ready',
        options: Options(
          headers: _headers,
          sendTimeout: const Duration(seconds: 4),
          receiveTimeout: const Duration(seconds: 4),
        ),
      );
      final data = res.data ?? const <String, dynamic>{};
      final ready = data['ready'] == true;
      return BridgeReadiness(ready: ready, reason: ready ? 'ready' : 'not_ready');
    } on DioException catch (e) {
      final code = e.response?.statusCode;
      if (code == 401) {
        return const BridgeReadiness(ready: false, reason: 'unauthorized');
      }
      return BridgeReadiness(
        ready: false,
        reason: 'http_${code ?? 'error'}',
      );
    } catch (_) {
      return const BridgeReadiness(ready: false, reason: 'unreachable');
    }
  }

  /// Best-effort telemetry so server can quantify bridge-vs-cloud routing.
  Future<void> reportLaunchRoute({
    required String path,
    String? fallbackReason,
  }) async {
    try {
      await _dio.post<Map<String, dynamic>>(
        '$_baseUrl/api/bridge/launch-telemetry',
        data: {
          'path': path,
          if (fallbackReason != null && fallbackReason.isNotEmpty)
            'fallbackReason': fallbackReason,
        },
        options: Options(headers: _headers),
      );
    } catch (_) {
      // Ignore telemetry failures.
    }
  }
}

class BridgeReadiness {
  const BridgeReadiness({required this.ready, required this.reason});
  final bool ready;
  final String reason;
}

class BridgeTaskResult {
  const BridgeTaskResult._({this.taskId, this.error});

  factory BridgeTaskResult.success({required String taskId}) =>
      BridgeTaskResult._(taskId: taskId);

  factory BridgeTaskResult.error(String error) =>
      BridgeTaskResult._(error: error);

  final String? taskId;
  final String? error;
}
