import 'package:flutter_test/flutter_test.dart';
import 'package:mluvici_kalkulacka/update_checker.dart';

void main() {
  group('GitHub release version parsing', () {
    test('extracts version from tags with v prefix and suffixes', () {
      final release = GitHubReleaseInfo(tagName: 'v1.2.3-beta');

      expect(release.normalizedVersion, '1.2.3');
    });

    test('detects newer versions correctly', () {
      final current = GitHubReleaseInfo(tagName: '1.2.3');
      final latest = GitHubReleaseInfo(tagName: '1.2.10');

      expect(current.isNewerThan('1.2.3'), isFalse);
      expect(latest.isNewerThan('1.2.3'), isTrue);
      expect(latest.isNewerThan('1.2.10+1'), isFalse);
    });
  });
}
