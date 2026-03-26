import 'package:flutter_test/flutter_test.dart';
import 'package:mordechaius_maximus/data/local/secure_storage_service.dart';
import 'package:mordechaius_maximus/services/capability_service.dart';
import 'helpers/mock_capability_storage.dart';
import 'helpers/mock_capability_webhook.dart';

void main() {
  group('CapabilityService', () {
    late MockCapabilityWebhook webhook;
    late MockCapabilityStorage storage;
    late CapabilityService service;

    setUpAll(() async {
      webhook = MockCapabilityWebhook();
      await webhook.start();
    });

    tearDownAll(() async {
      await webhook.stop();
    });

    setUp(() {
      storage = MockCapabilityStorage();
      service = CapabilityService(storage);
    });

    group('pingWebhook', () {
      test('returns error when no webhook configured', () async {
        final err = await service.pingWebhook('sms');
        expect(err, isNotNull);
        expect(err, contains('No webhook URL configured'));
      });

      test('returns error when webhook URL is invalid', () async {
        storage.setConfig('sms', const CapabilityConfig(webhookUrl: 'not-a-valid-url'));
        final err = await service.pingWebhook('sms');
        expect(err, isNotNull);
        expect(err, contains('Invalid webhook URL'));
      });

      test('succeeds when webhook responds 200', () async {
        storage.setConfig('obs', CapabilityConfig(webhookUrl: webhook.webhookUrl));
        final err = await service.pingWebhook('obs');
        expect(err, isNull);
        expect(webhook.receivedRequests.length, 1);
        expect(webhook.receivedRequests.first['action'], 'ping');
        expect(webhook.receivedRequests.first['capability'], 'obs');
      });

      test('includes source and timestamp in ping payload', () async {
        storage.setConfig('obs', CapabilityConfig(webhookUrl: webhook.webhookUrl));
        await service.pingWebhook('obs');
        final req = webhook.receivedRequests.first;
        expect(req['source'], 'mordechaius_maximus');
        expect(req['timestamp'], isNotNull);
      });
    });

    group('execute', () {
      test('returns error when no webhook configured', () async {
        final err = await service.execute('messenger');
        expect(err, isNotNull);
        expect(err, contains('No webhook URL configured'));
      });

      test('succeeds and sends full payload when webhook configured', () async {
        storage.setConfig('obs', CapabilityConfig(
          webhookUrl: webhook.webhookUrl,
          apiKey: 'test-key',
          folderPath: '/path/to/folder',
        ));
        webhook.receivedRequests.clear();

        final err = await service.execute('obs', action: 'run', payload: {'capability_title': 'OBS Studio control'});
        expect(err, isNull);
        expect(webhook.receivedRequests.length, 1);
        final req = webhook.receivedRequests.first;
        expect(req['action'], 'run');
        expect(req['capability'], 'obs');
        expect(req['api_key'], 'test-key');
        expect(req['folder_path'], '/path/to/folder');
        expect(req['capability_title'], 'OBS Studio control');
      });

      test('succeeds with minimal config (webhook only)', () async {
        storage.setConfig('tiktok_live', CapabilityConfig(webhookUrl: webhook.webhookUrl));
        webhook.receivedRequests.clear();

        final err = await service.execute('tiktok_live');
        expect(err, isNull);
        expect(webhook.receivedRequests.first['action'], 'execute');
      });
    });

    group('simulation - full capability flow', () {
      test('all catalog capabilities: Test (no config) shows helpful message', () async {
        for (final c in [
          'sms',
          'messenger',
          'tiktok_live',
          'opus',
          'obs',
          'autopost',
          'autoreply',
          'smarthome_lights',
          'smarthome_thermostat',
          'smarthome_alexa',
          'email',
          'drive_upload',
          'drive_download',
          'youtube_mgmt',
        ]) {
          final err = await service.pingWebhook(c);
          expect(err, isNotNull);
          expect(err, contains('No webhook URL configured'));
        }
      });

      test('configure → Test → Execute flow for OBS capability', () async {
        storage.setConfig('obs', CapabilityConfig(
          webhookUrl: webhook.webhookUrl,
          apiKey: 'obs-secret',
          folderPath: '',
        ));
        webhook.receivedRequests.clear();

        // Simulate Test button
        final testErr = await service.pingWebhook('obs');
        expect(testErr, isNull);
        expect(webhook.receivedRequests.any((r) => r['action'] == 'ping'), isTrue);

        // Simulate Execute button
        final execErr = await service.execute('obs', action: 'run', payload: {'capability_title': 'OBS Studio control'});
        expect(execErr, isNull);
        expect(webhook.receivedRequests.any((r) => r['action'] == 'run'), isTrue);
        final runReq = webhook.receivedRequests.firstWhere((r) => r['action'] == 'run');
        expect(runReq['api_key'], 'obs-secret');
      });
    });
  });
}
