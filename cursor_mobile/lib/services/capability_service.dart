import 'package:dio/dio.dart';
import '../data/local/secure_storage_service.dart';

/// Invokes capabilities via configured webhooks. Used by Test and Execute actions.
class CapabilityService {
  CapabilityService(CapabilityConfigProvider storage) : _storage = storage, _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 30),
    headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
  ));

  final CapabilityConfigProvider _storage;
  final Dio _dio;

  /// Ping a capability's webhook to verify connectivity. Sends a minimal payload.
  /// Returns null on success, error message on failure.
  Future<String?> pingWebhook(String capabilityId) async {
    final config = await _storage.getCapabilityConfig(capabilityId);
    final url = config?.webhookUrl.trim();
    if (url == null || url.isEmpty) {
      return 'No webhook URL configured. Use Configure to add one.';
    }
    if (!_isValidUrl(url)) {
      return 'Invalid webhook URL. Use https:// or http:// with a valid host.';
    }
    try {
      await _dio.post(
        url,
        data: {
          'action': 'ping',
          'capability': capabilityId,
          'source': 'mordechaius_maximus',
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
      return null;
    } on DioException catch (e) {
      return _formatDioError(e, 'Is your bridge/server running and reachable?');
    } catch (e) {
      return e.toString();
    }
  }

  static bool _isValidUrl(String s) {
    try {
      final uri = Uri.parse(s);
      return (uri.scheme == 'http' || uri.scheme == 'https') && uri.host.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  static String _formatDioError(DioException e, String timeoutHint) {
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.sendTimeout) {
      return 'Request timed out. $timeoutHint';
    }
    if (e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.connectionTimeout) {
      final msg = e.message ?? e.error?.toString() ?? '';
      if (msg.contains('Connection refused') || msg.contains('Failed host lookup')) {
        return 'Cannot reach server. $timeoutHint';
      }
    }
    if (e.response != null) {
      final data = e.response!.data;
      final body = data is Map ? (data['error'] ?? data['message'] ?? data) : data;
      return 'Server responded ${e.response!.statusCode}: $body';
    }
    return e.message ?? e.error?.toString() ?? e.toString();
  }

  /// Execute a capability action. Sends the full payload to the webhook.
  /// Returns null on success, error message on failure.
  Future<String?> execute(
    String capabilityId, {
    String? action,
    Map<String, dynamic>? payload,
  }) async {
    final config = await _storage.getCapabilityConfig(capabilityId);
    final url = config?.webhookUrl.trim();
    if (url == null || url.isEmpty) {
      return 'No webhook URL configured. Use Configure to add one.';
    }
    if (!_isValidUrl(url)) {
      return 'Invalid webhook URL. Use https:// or http:// with a valid host.';
    }
    final body = <String, dynamic>{
      'action': action ?? 'execute',
      'capability': capabilityId,
      'source': 'mordechaius_maximus',
      'timestamp': DateTime.now().toIso8601String(),
      if (config != null && config.apiKey.isNotEmpty) 'api_key': config.apiKey,
      if (config != null && config.folderPath.isNotEmpty) 'folder_path': config.folderPath,
      ...?payload,
    };
    try {
      await _dio.post(url, data: body);
      return null;
    } on DioException catch (e) {
      return _formatDioError(e, 'Is your bridge/server running?');
    } catch (e) {
      return e.toString();
    }
  }
}
