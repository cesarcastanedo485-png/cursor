import 'package:flutter_test/flutter_test.dart';
import 'package:mordechaius_maximus/services/mordecai_health_service.dart';

void main() {
  group('MordecaiHealthService.normalizeBaseUrl', () {
    test('adds https for bare hostnames', () {
      expect(
        MordecaiHealthService.normalizeBaseUrl('foo.trycloudflare.com'),
        'https://foo.trycloudflare.com',
      );
    });

    test('uses http for localhost', () {
      expect(
        MordecaiHealthService.normalizeBaseUrl('localhost:3000'),
        'http://localhost:3000',
      );
    });

    test('preserves explicit https and strips trailing slash', () {
      expect(
        MordecaiHealthService.normalizeBaseUrl('https://example.com/'),
        'https://example.com',
      );
    });

    test('empty input', () {
      expect(MordecaiHealthService.normalizeBaseUrl(''), '');
      expect(MordecaiHealthService.normalizeBaseUrl('   '), '');
    });
  });
}
