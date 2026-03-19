import 'package:dio/dio.dart';

/// Thrown when the API returns 401 Unauthorized (invalid or expired API key).
class UnauthorizedException implements Exception {
  UnauthorizedException([this.message]);

  final String? message;

  @override
  String toString() =>
      message ?? 'Invalid or expired API key. Go to Settings (Cloud Agents tab) to update it.';
}

/// User-friendly message for API errors (401 → clear text; others → toString).
String apiErrorMessage(Object error) {
  if (error is DioException && error.error is UnauthorizedException) {
    return (error.error as UnauthorizedException).toString();
  }
  if (error is UnauthorizedException) return error.toString();
  return error.toString();
}

/// True if error is 401 / Unauthorized (show "Open Settings").
bool isUnauthorizedError(Object error) {
  return error is UnauthorizedException ||
      (error is DioException && error.error is UnauthorizedException);
}
