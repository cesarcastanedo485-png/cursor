import 'package:flutter_test/flutter_test.dart';
import 'package:mordechaius_maximus/services/local_openai_service.dart';
import 'helpers/mock_private_ai_server.dart';

void main() {
  group('LocalOpenAiService with mock server', () {
    late MockPrivateAiServer server;

    setUpAll(() async {
      server = MockPrivateAiServer();
      await server.start();
    });

    tearDownAll(() async {
      await server.stop();
    });

    test('ping via /v1/models returns true', () async {
      final svc = LocalOpenAiService(
        baseUrl: server.baseUrl,
        model: 'test-model',
      );
      final ok = await svc.ping();
      expect(ok, isTrue);
    });

    test('chatCompletion returns mock reply and waits for response', () async {
      final svc = LocalOpenAiService(
        baseUrl: server.baseUrl,
        model: 'test-model',
      );
      final reply = await svc.chatCompletion([
        {'role': 'user', 'content': 'Hello'},
      ]);
      expect(reply, isNotNull);
      expect(reply, contains('Mock reply'));
      expect(reply, contains('1 messages'));
    });

    test('chatCompletion with multiple messages receives correct count', () async {
      final svc = LocalOpenAiService(
        baseUrl: server.baseUrl,
        model: 'test-model',
      );
      final reply = await svc.chatCompletion([
        {'role': 'system', 'content': 'You are helpful.'},
        {'role': 'user', 'content': 'Hi'},
        {'role': 'assistant', 'content': 'Hello!'},
        {'role': 'user', 'content': 'Thanks'},
      ]);
      expect(reply, contains('4 messages'));
    });

    test('imageGenerations returns URL from mock', () async {
      final svc = LocalOpenAiService(
        baseUrl: server.baseUrl,
        model: 'flux',
      );
      final url = await svc.imageGenerations('a cute cat');
      expect(url, isNotNull);
      expect(url, contains('example.com'));
      expect(url, contains('mock-image'));
    });
  });
}
