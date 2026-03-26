import 'package:dio/dio.dart';

/// Pings a running Mordecai Node server (same host as Commissions WebView).
class MordecaiHealthService {
  MordecaiHealthService._();

  static final RegExp _ipv4Regex = RegExp(r'^\d{1,3}(\.\d{1,3}){3}$');

  /// Validated/sanitized URL result for Commissions WebView usage.
  static MordecaiUrlValidation validateForCommissions(
    String raw, {
    bool assumeMobileDevice = true,
  }) {
    final normalized = normalizeBaseUrl(raw);
    if (normalized.isEmpty) {
      return const MordecaiUrlValidation(
        normalizedUrl: '',
        error: 'Enter your Mordecai URL first.',
      );
    }

    Uri uri;
    try {
      uri = Uri.parse(normalized);
    } catch (_) {
      return MordecaiUrlValidation(
        normalizedUrl: normalized,
        error: 'Invalid URL format. Use host or full https:// URL.',
      );
    }

    final scheme = uri.scheme.toLowerCase();
    if (scheme != 'http' && scheme != 'https') {
      return MordecaiUrlValidation(
        normalizedUrl: normalized,
        error: 'Unsupported URL scheme "$scheme". Use http or https.',
      );
    }
    if (uri.host.trim().isEmpty) {
      return MordecaiUrlValidation(
        normalizedUrl: normalized,
        error: 'URL is missing a host.',
      );
    }

    final host = uri.host.toLowerCase();
    final isLocalHost =
        host == 'localhost' || host == '127.0.0.1' || host == '0.0.0.0';
    final isIpv4 = _ipv4Regex.hasMatch(host);
    final privateIp = _isPrivateIpv4(host);
    final isHttp = scheme == 'http';
    final likelyBlocked = assumeMobileDevice && isHttp;

    String? warning;
    if (assumeMobileDevice && isLocalHost) {
      warning =
          'localhost/127.0.0.1 points to this phone, not your PC. Use your HTTPS tunnel URL.';
    } else if (likelyBlocked) {
      warning =
          'HTTP URLs are often blocked by mobile WebView. Use an HTTPS tunnel URL.';
    } else if (assumeMobileDevice && isIpv4 && !privateIp) {
      warning =
          'Public IP URLs can be unstable on mobile networks. Prefer an HTTPS tunnel URL.';
    }

    return MordecaiUrlValidation(
      normalizedUrl: normalized,
      warning: warning,
      likelyBlockedOnDevice: likelyBlocked,
    );
  }

  /// Trim, add scheme if missing, and coerce health endpoint URLs to app base URL.
  static String normalizeBaseUrl(String raw) {
    var u = raw.trim();
    if (u.isEmpty) return '';
    if (!RegExp(r'^https?://', caseSensitive: false).hasMatch(u)) {
      final lower = u.toLowerCase();
      final local = lower.startsWith('localhost') ||
          lower.startsWith('127.0.0.1') ||
          _ipv4Regex.hasMatch(lower);
      u = local ? 'http://$u' : 'https://$u';
    }
    while (u.endsWith('/')) {
      u = u.substring(0, u.length - 1);
    }
    // If user pasted a health endpoint URL, convert it back to base host URL
    // so WebView loads the commissions app instead of JSON health output.
    try {
      final uri = Uri.parse(u);
      final path = uri.path.toLowerCase();
      final healthPaths = <String>{'/health', '/api/commissions/health'};
      if (healthPaths.contains(path)) {
        u = uri.replace(path: '', query: null, fragment: null).toString();
        while (u.endsWith('/')) {
          u = u.substring(0, u.length - 1);
        }
      }
    } catch (_) {
      // Keep original normalized value if parsing fails.
    }
    return u;
  }

  /// Tries `/api/commissions/health` then `/health` (both return `{ ok: true }` on Mordecai).
  static Future<bool> isReachable(String rawBaseUrl) async {
    final validation = validateForCommissions(rawBaseUrl);
    final base = validation.normalizedUrl;
    if (!validation.isValid || base.isEmpty) return false;

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

  static bool _isPrivateIpv4(String host) {
    if (!_ipv4Regex.hasMatch(host)) return false;
    final parts = host.split('.').map(int.tryParse).toList();
    if (parts.length != 4 || parts.any((p) => p == null || p < 0 || p > 255)) {
      return false;
    }
    final a = parts[0]!;
    final b = parts[1]!;
    if (a == 10) return true;
    if (a == 172 && b >= 16 && b <= 31) return true;
    if (a == 192 && b == 168) return true;
    if (a == 127) return true;
    return false;
  }
}

class MordecaiUrlValidation {
  const MordecaiUrlValidation({
    required this.normalizedUrl,
    this.error,
    this.warning,
    this.likelyBlockedOnDevice = false,
  });

  final String normalizedUrl;
  final String? error;
  final String? warning;
  final bool likelyBlockedOnDevice;

  bool get isValid => error == null && normalizedUrl.isNotEmpty;
  bool get hasWarning => (warning ?? '').trim().isNotEmpty;
}
