import 'package:dio/dio.dart';

/// Thrown when the API returns 401 Unauthorized (invalid or expired API key).
class UnauthorizedException implements Exception {
  UnauthorizedException([this.message]);

  final String? message;

  @override
  String toString() =>
      message ?? 'Invalid or expired API key. Go to Settings (Cloud Agents tab) to update it.';
}

/// User-friendly message for API errors (401 → clear text; 503 → service unavailable; others → status + body or toString).
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
    
    // Handle 503 Service Unavailable
    if (code == 503) {
      return 'Cursor\'s servers are temporarily unavailable. Please try again in a few minutes.';
    }
    
    // Handle 400 Bad Request with better context
    if (code == 400) {
      final body = error.response!.data;
      String extra = '';
      if (body is Map && body['message'] != null) {
        extra = ': ${body['message']}';
      } else if (body is Map && body['error'] != null) {
        extra = ': ${body['error']}';
      } else if (body is String && body.isNotEmpty) {
        extra = ': ${body.length > 120 ? '${body.substring(0, 120)}…' : body}';
      }
      return 'Invalid request$extra. If this persists, try a simpler action first (e.g., list agents).';
    }
    
    final body = error.response!.data;
    String extra = '';
    if (body is Map && body['message'] != null) {
      extra = ': ${body['message']}';
    } else if (body is String && body.isNotEmpty) {
      extra = ': ${body.length > 120 ? '${body.substring(0, 120)}…' : body}';
    }
    return 'HTTP $code$extra';
  }
  
  // Handle network/timeout errors
  if (error is DioException) {
    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.sendTimeout) {
      return 'Request timed out. Check your connection and try again.';
    }
    if (error.type == DioExceptionType.connectionError) {
      return 'Cannot reach Cursor\'s servers. Check your internet connection.';
    }
  }
  
  return error.toString();
}

/// True if error is 401 / Unauthorized (show "Open Settings").
bool isUnauthorizedError(Object error) {
  return error is UnauthorizedException ||
      (error is DioException && error.error is UnauthorizedException) ||
      (error is DioException && error.response?.statusCode == 401);
}
