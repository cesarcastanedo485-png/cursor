import 'package:dio/dio.dart';

/// Local OpenAI-compatible API (Ollama, vLLM, proxies to ComfyUI, etc.).
/// Base URL should include scheme and port, e.g. http://192.168.1.100:11434
class LocalOpenAiService {
  LocalOpenAiService({
    required String baseUrl,
    required this.model,
    this.apiKey,
  }) : _base = _normalizeBase(baseUrl) {
    _dio = Dio(BaseOptions(
      baseUrl: _base,
      connectTimeout: const Duration(seconds: 120),
      receiveTimeout: const Duration(seconds: 120),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (apiKey != null && apiKey!.isNotEmpty) 'Authorization': 'Bearer $apiKey',
      },
    ));
  }

  final String model;
  final String? apiKey;
  final String _base;
  late final Dio _dio;

  static String _normalizeBase(String url) {
    var u = url.trim();
    if (u.isEmpty) return 'http://127.0.0.1:11434';
    if (!u.startsWith('http://') && !u.startsWith('https://')) {
      u = 'http://$u';
    }
    return u.replaceAll(RegExp(r'/$'), '');
  }

  /// POST /v1/chat/completions (text or multimodal user parts).
  Future<String> chatCompletion(List<Map<String, dynamic>> messages) async {
    final r = await _dio.post<Map<String, dynamic>>(
      '/v1/chat/completions',
      data: {
        'model': model,
        'messages': messages,
        'stream': false,
      },
    );
    final data = r.data;
    if (data == null) throw Exception('Empty response');
    final choices = data['choices'] as List<dynamic>?;
    if (choices == null || choices.isEmpty) throw Exception('No choices in response');
    final msg = choices.first as Map<String, dynamic>;
    final m = msg['message'] as Map<String, dynamic>?;
    return m?['content'] as String? ?? msg['text'] as String? ?? data.toString();
  }

  /// Try OpenAI images API (some gateways expose this).
  Future<String?> imageGenerations(String prompt, {String size = '512x512'}) async {
    try {
      final r = await _dio.post<Map<String, dynamic>>(
        '/v1/images/generations',
        data: {
          'model': model,
          'prompt': prompt,
          'n': 1,
          'size': size,
        },
      );
      final data = r.data;
      final list = data?['data'] as List<dynamic>?;
      if (list != null && list.isNotEmpty) {
        final first = list.first as Map<String, dynamic>;
        return first['url'] as String? ?? first['b64_json'] as String?;
      }
    } catch (_) {
      rethrow;
    }
    return null;
  }

  /// Lightweight reachability check.
  Future<bool> ping() async {
    try {
      await _dio.get('/v1/models', options: Options(sendTimeout: const Duration(seconds: 5), receiveTimeout: const Duration(seconds: 5)));
      return true;
    } catch (_) {
      try {
        await _dio.get('/', options: Options(sendTimeout: const Duration(seconds: 5), receiveTimeout: const Duration(seconds: 5)));
        return true;
      } catch (_) {
        return false;
      }
    }
  }
}
