import 'package:dio/dio.dart';

/// Thrown when the API returns 401 Unauthorized (invalid or expired API key).
class UnauthorizedException implements Exception {
  UnauthorizedException([this.message]);

  final String? message;

  @override
  String toString() =>
      message ?? 'Invalid or expired API key. Go to Settings (Cloud Agents tab) to update it.';
}

/// User-friendly message for API errors (401 → clear text; others → status + body or toString).
String apiErrorMessage(Object error) {
  if (error is DioException && error.error is UnauthorizedException) {
    return (error.error as UnauthorizedException).toString();
  }
  if (error is UnauthorizedException) return error.toString();
  if (error is DioException && error.response?.statusCode == 401) {
    return UnauthorizedException().toString();
  }
  if (error is DioException && error.response != null) {
    final code = error.response!.statusCode;
    final body = error.response!.data;
    String extra = '';
    if (body is Map && body['message'] != null) {
      extra = ': ${body['message']}';
    } else if (body is String && body.isNotEmpty) {
      extra = ': ${body.length > 120 ? '${body.substring(0, 120)}…' : body}';
    }
    return 'HTTP $code$extra';
  }
  return error.toString();
}

/// True if error is 401 / Unauthorized (show "Open Settings").
bool isUnauthorizedError(Object error) {
  return error is UnauthorizedException ||
      (error is DioException && error.error is UnauthorizedException) ||
      (error is DioException && error.response?.statusCode == 401);
}
