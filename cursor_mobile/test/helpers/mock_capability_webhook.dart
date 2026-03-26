import 'dart:convert';
import 'dart:io';

/// Mock HTTP server that simulates a capability webhook (desktop bridge).
/// Accepts POST with action: ping | execute | run.
/// Used for testing Capabilities tab Test and Execute.
class MockCapabilityWebhook {
  HttpServer? _server;
  int _port = 0;

  final List<Map<String, dynamic>> receivedRequests = [];

  int get port => _port;
  String get webhookUrl => 'http://127.0.0.1:$_port/webhook';

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
    final method = req.method;
    final res = req.response;

    try {
      if (method == 'POST') {
        final body = await utf8.decodeStream(req);
        final data = jsonDecode(body) as Map<String, dynamic>? ?? {};
        receivedRequests.add(Map<String, dynamic>.from(data));

        final action = data['action'] as String? ?? 'unknown';
        if (action == 'ping' || action == 'execute' || action == 'run') {
          _sendJson(res, 200, {
            'ok': true,
            'action': action,
            'capability': data['capability'],
            'received_at': DateTime.now().toIso8601String(),
          });
          return;
        }
      }

      if (method == 'GET' && (req.uri.path == '/' || req.uri.path.isEmpty)) {
        _sendJson(res, 200, {'status': 'mock capability webhook', 'port': _port});
        return;
      }

      _sendJson(res, 404, {'error': 'Not found: $method ${req.uri.path}'});
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
