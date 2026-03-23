import 'package:dio/dio.dart';

/// Pings a running Mordecai Node server (same host as Commissions WebView).
class MordecaiHealthService {
  MordecaiHealthService._();

  /// Trim, add scheme if missing, strip trailing slashes.
  static String normalizeBaseUrl(String raw) {
    var u = raw.trim();
    if (u.isEmpty) return '';
    if (!RegExp(r'^https?://', caseSensitive: false).hasMatch(u)) {
      final lower = u.toLowerCase();
      final local = lower.startsWith('localhost') ||
          lower.startsWith('127.0.0.1') ||
          RegExp(r'^\d{1,3}(\.\d{1,3}){3}').hasMatch(lower);
      u = local ? 'http://$u' : 'https://$u';
    }
    while (u.endsWith('/')) {
      u = u.substring(0, u.length - 1);
    }
    return u;
  }

  /// Tries `/api/commissions/health` then `/health` (both return `{ ok: true }` on Mordecai).
  static Future<bool> isReachable(String rawBaseUrl) async {
    final base = normalizeBaseUrl(rawBaseUrl);
    if (base.isEmpty) return false;

    final dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 12),
        receiveTimeout: const Duration(seconds: 12),
        followRedirects: true,
        maxRedirects: 5,
        validateStatus: (s) => s != null && s >= 200 && s < 400,
        responseType: ResponseType.json,
      ),
    );

    for (final path in ['/api/commissions/health', '/health']) {
      try {
        final r = await dio.get<Object>('$base$path');
        final data = r.data;
        if (data is Map && data['ok'] == true) return true;
      } on DioException catch (_) {
        continue;
      } catch (_) {
        continue;
      }
    }
    return false;
  }
}
