import 'dart:convert';
import 'dart:io';

/// Mock HTTP server that simulates Ollama/OpenAI-compatible API.
/// Used for testing Private AI features (ping, chat, image generation).
class MockPrivateAiServer {
  HttpServer? _server;
  int _port = 0;

  int get port => _port;
  String get baseUrl => 'http://127.0.0.1:$_port';

  Future<void> start() async {
    _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _port = _server!.port;
    _server!.listen(_handleRequest);
  }

  Future<void> stop() async {
    await _server?.close(force: true);
    _server = null;
  }

  void _handleRequest(HttpRequest req) async {
    final path = req.uri.path;
    final method = req.method;
    final res = req.response;

    try {
      if (method == 'GET') {
        if (path == '/v1/models' || path == '/v1/models/') {
          _sendJson(res, 200, {
            'data': [
              {'id': 'test-model', 'object': 'model'},
            ],
          });
          return;
        }
        if (path == '/' || path.isEmpty) {
          _sendJson(res, 200, {'status': 'ok'});
          return;
        }
      } else if (method == 'POST') {
        if (path == '/v1/chat/completions' || path == '/v1/chat/completions/') {
          final body = await utf8.decodeStream(req);
          final data = jsonDecode(body) as Map<String, dynamic>?;
          final messages = data?['messages'] as List? ?? [];
          _sendJson(res, 200, {
            'id': 'chatcmpl-test',
            'choices': [
              {
                'index': 0,
                'message': {
                  'role': 'assistant',
                  'content':
                      'Mock reply to your message. (Received ${messages.length} messages)',
                },
                'finish_reason': 'stop',
              },
            ],
          });
          return;
        }
        if (path == '/v1/images/generations' ||
            path == '/v1/images/generations/') {
          final body = await utf8.decodeStream(req);
          final data = jsonDecode(body) as Map<String, dynamic>?;
          _sendJson(res, 200, {
            'data': [
              {
                'url': 'https://example.com/mock-image.png',
                'b64_json': null,
              },
            ],
          });
          return;
        }
      }

      _sendJson(res, 404, {'error': 'Not found: $method $path'});
    } catch (e) {
      _sendJson(res, 500, {'error': '$e'});
    } finally {
      try {
        await res.close();
      } catch (_) {}
    }
  }

  void _sendJson(HttpResponse res, int statusCode, Map<String, dynamic> body) {
    res.statusCode = statusCode;
    res.headers.contentType = ContentType.json;
    res.write(jsonEncode(body));
  }
}
