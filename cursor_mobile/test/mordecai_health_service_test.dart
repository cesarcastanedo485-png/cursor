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

    test('coerces /health url to host root', () {
      expect(
        MordecaiHealthService.normalizeBaseUrl(
          'https://foo.trycloudflare.com/health',
        ),
        'https://foo.trycloudflare.com',
      );
    });

    test('coerces /api/commissions/health url to host root', () {
      expect(
        MordecaiHealthService.normalizeBaseUrl(
          'https://foo.trycloudflare.com/api/commissions/health',
        ),
        'https://foo.trycloudflare.com',
      );
    });
  });

  group('MordecaiHealthService.validateForCommissions', () {
    test('returns error for empty URL', () {
      final result = MordecaiHealthService.validateForCommissions('');
      expect(result.isValid, isFalse);
      expect(result.error, isNotNull);
    });

    test('warns for localhost on mobile', () {
      final result = MordecaiHealthService.validateForCommissions(
        'localhost:3000',
      );
      expect(result.isValid, isTrue);
      expect(result.hasWarning, isTrue);
    });

    test('warns for http tunnel on mobile', () {
      final result = MordecaiHealthService.validateForCommissions(
        'http://example.com',
      );
      expect(result.isValid, isTrue);
      expect(result.likelyBlockedOnDevice, isTrue);
      expect(result.hasWarning, isTrue);
    });

    test('passes for https tunnel', () {
      final result = MordecaiHealthService.validateForCommissions(
        'foo.trycloudflare.com',
      );
      expect(result.isValid, isTrue);
      expect(result.normalizedUrl, 'https://foo.trycloudflare.com');
      expect(result.hasWarning, isFalse);
    });
  });
}
