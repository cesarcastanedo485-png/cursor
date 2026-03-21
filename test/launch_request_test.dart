import 'package:flutter_test/flutter_test.dart';
import 'package:mordechaius_maximus/data/models/launch_request.dart';

void main() {
  group('LaunchRequest.toJson', () {
    test('sends explicit autoCreatePr false when toggle is off', () {
      const request = LaunchRequest(
        repoUrl: 'https://github.com/example/repo',
        prompt: 'Fix lint issues',
        autoCreatePr: false,
      );

      final json = request.toJson();
      final target = json['target'] as Map<String, dynamic>;
      expect(target['autoCreatePr'], isFalse);
      expect(target.containsKey('branchName'), isFalse);
    });

    test('includes branchName while keeping autoCreatePr false', () {
      const request = LaunchRequest(
        repoUrl: 'https://github.com/example/repo',
        prompt: 'Update docs',
        branchName: 'main',
        autoCreatePr: false,
      );

      final json = request.toJson();
      final target = json['target'] as Map<String, dynamic>;
      expect(target['autoCreatePr'], isFalse);
      expect(target['branchName'], 'main');
    });

    test('sends explicit autoCreatePr true when enabled', () {
      const request = LaunchRequest(
        repoUrl: 'https://github.com/example/repo',
        prompt: 'Add tests',
        autoCreatePr: true,
      );

      final json = request.toJson();
      final target = json['target'] as Map<String, dynamic>;
      expect(target['autoCreatePr'], isTrue);
    });
  });
}
