import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import '../providers/notification_provider.dart';

class AgentStreamEvent {
  const AgentStreamEvent({
    required this.type,
    required this.agentId,
    this.eventId = '',
    this.status,
    this.messagePreview,
    this.threadId,
    this.heartbeat = false,
    this.at,
  });

  final String type;
  final String agentId;
  final String eventId;
  final String? status;
  final String? messagePreview;
  final String? threadId;
  final bool heartbeat;
  final String? at;

  factory AgentStreamEvent.fromJson(Map<String, dynamic> json) {
    return AgentStreamEvent(
      type: (json['type'] ?? '').toString(),
      agentId: (json['agentId'] ?? json['id'] ?? '').toString(),
      eventId: (json['eventId'] ?? '').toString(),
      status: json['status']?.toString(),
      messagePreview: json['messagePreview']?.toString(),
      threadId: json['threadId']?.toString(),
      heartbeat: json['heartbeat'] == true,
      at: json['at']?.toString(),
    );
  }

  bool get isConnectedSignal => type == 'stream_ready';
}

class AgentStreamService {
  AgentStreamService({
    required this.mordecaiBaseUrl,
    required this.bridgeSecret,
    required this.fcmToken,
  });

  final String mordecaiBaseUrl;
  final String? bridgeSecret;
  final String? fcmToken;

  String get _baseUrl => mordecaiBaseUrl.endsWith('/')
      ? mordecaiBaseUrl.substring(0, mordecaiBaseUrl.length - 1)
      : mordecaiBaseUrl;

  Future<void> registerDevice(AgentNotificationPreferences preferences) async {
    final token = fcmToken?.trim() ?? '';
    if (token.isEmpty) return;
    await _postJson(
      '/api/notifications/register-device',
      {
        'token': token,
        'preferences': preferences.toJson(),
      },
    );
  }

  Future<void> watchAgent({
    required String agentId,
    required AgentNotificationPreferences preferences,
  }) async {
    final token = fcmToken?.trim() ?? '';
    if (token.isEmpty || agentId.trim().isEmpty) return;
    await _postJson('/api/agents/watch', {
      'agentId': agentId.trim(),
      'token': token,
      'preferences': preferences.toJson(),
    });
  }

  Stream<AgentStreamEvent> streamAgent({
    required String agentId,
    required AgentNotificationPreferences preferences,
  }) {
    final controller = StreamController<AgentStreamEvent>();
    var cancelled = false;
    var backoffMs = 1000;
    HttpClient? activeClient;

    Future<void> run() async {
      while (!cancelled) {
        try {
          final token = fcmToken?.trim() ?? '';
          final query = token.isEmpty
              ? ''
              : '?token=${Uri.encodeQueryComponent(token)}';
          final uri = Uri.parse('$_baseUrl/api/agents/$agentId/stream$query');
          final client = HttpClient();
          activeClient = client;
          final req = await client.getUrl(uri);
          req.headers.set('Accept', 'text/event-stream');
          if ((bridgeSecret ?? '').trim().isNotEmpty) {
            req.headers.set('X-Bridge-Secret', bridgeSecret!.trim());
          }
          req.headers.set(
            'X-Notification-Preferences',
            jsonEncode(preferences.toJson()),
          );

          final res = await req.close();
          if (res.statusCode != 200) {
            throw HttpException(
              'SSE connection failed with status ${res.statusCode}',
              uri: uri,
            );
          }

          backoffMs = 1000;
          String? pendingEventType;
          String? pendingEventId;
          final dataLines = <String>[];

          await for (final line
              in res.transform(utf8.decoder).transform(const LineSplitter())) {
            if (cancelled) break;
            if (line.isEmpty) {
              if (dataLines.isNotEmpty) {
                final payload = dataLines.join('\n');
                try {
                  final decoded = jsonDecode(payload);
                  if (decoded is Map<String, dynamic>) {
                    final event = AgentStreamEvent.fromJson({
                      ...decoded,
                      if (pendingEventType != null && pendingEventType.isNotEmpty)
                        'type': pendingEventType,
                      if (pendingEventId != null && pendingEventId.isNotEmpty)
                        'eventId': pendingEventId,
                    });
                    if (!controller.isClosed) controller.add(event);
                  }
                } catch (_) {}
              }
              pendingEventType = null;
              pendingEventId = null;
              dataLines.clear();
              continue;
            }
            if (line.startsWith('event:')) {
              pendingEventType = line.substring(6).trim();
            } else if (line.startsWith('id:')) {
              pendingEventId = line.substring(3).trim();
            } else if (line.startsWith('data:')) {
              dataLines.add(line.substring(5).trimLeft());
            }
          }
        } catch (e, st) {
          if (!controller.isClosed) controller.addError(e, st);
        } finally {
          activeClient?.close(force: true);
          activeClient = null;
        }

        if (cancelled) break;
        await Future.delayed(Duration(milliseconds: backoffMs));
        backoffMs = min(backoffMs * 2, 15000);
      }
      if (!controller.isClosed) await controller.close();
    }

    run();
    controller.onCancel = () {
      cancelled = true;
      activeClient?.close(force: true);
    };
    return controller.stream;
  }

  Future<void> _postJson(String path, Map<String, dynamic> body) async {
    final uri = Uri.parse('$_baseUrl$path');
    final client = HttpClient();
    try {
      final req = await client.postUrl(uri);
      req.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
      if ((bridgeSecret ?? '').trim().isNotEmpty) {
        req.headers.set('X-Bridge-Secret', bridgeSecret!.trim());
      }
      req.write(jsonEncode(body));
      final res = await req.close();
      if (res.statusCode < 200 || res.statusCode >= 300) {
        throw HttpException(
          'Request failed (${res.statusCode}) for $path',
          uri: uri,
        );
      }
    } finally {
      client.close(force: true);
    }
  }
}
