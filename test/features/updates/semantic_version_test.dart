import 'package:flutter_test/flutter_test.dart';
import 'package:logic_lab/features/updates/domain/semantic_version.dart';

void main() {
  group('SemanticVersion parsing', () {
    test('accepts the forms the release tags use', () {
      expect(SemanticVersion.tryParse('1.2.3'), const SemanticVersion(1, 2, 3));
      expect(
        SemanticVersion.tryParse('v1.2.3'),
        const SemanticVersion(1, 2, 3),
      );
      expect(
        SemanticVersion.tryParse('V1.2.3'),
        const SemanticVersion(1, 2, 3),
      );
      // Build metadata is ignored: CI regenerates it for every release.
      expect(
        SemanticVersion.tryParse('1.2.3+45'),
        const SemanticVersion(1, 2, 3),
      );
      expect(
        SemanticVersion.tryParse(' 1.2.3 '),
        const SemanticVersion(1, 2, 3),
      );
    });

    test('rejects partial and malformed versions instead of guessing', () {
      for (final String raw in <String>[
        '',
        '1',
        '1.2',
        '1.2.3.4',
        'v',
        'one.two.three',
        '1.2.x',
        '1.2.3 4',
        '-1.2.3',
      ]) {
        expect(
          SemanticVersion.tryParse(raw),
          isNull,
          reason: '"$raw" must not parse',
        );
      }
      expect(SemanticVersion.tryParse(null), isNull);
    });

    test('a pre-release is recognised', () {
      final SemanticVersion? version = SemanticVersion.tryParse('1.2.0-rc.1');
      expect(version, isNotNull);
      expect(version!.isPreRelease, isTrue);
      expect(version.toString(), '1.2.0-rc.1');
      expect(SemanticVersion.tryParse('1.2.0')!.isPreRelease, isFalse);
    });
  });

  group('SemanticVersion ordering', () {
    test('compares numerically, not as text', () {
      final SemanticVersion version = SemanticVersion.tryParse('1.10.0')!;
      expect(version > SemanticVersion.tryParse('1.9.9')!, isTrue);
      expect(version > SemanticVersion.tryParse('1.2.0')!, isTrue);
      expect(
        SemanticVersion.tryParse('2.0.0')! >
            SemanticVersion.tryParse('1.99.99')!,
        isTrue,
      );
      expect(
        SemanticVersion.tryParse('1.2.3')! > SemanticVersion.tryParse('1.2.3')!,
        isFalse,
      );
    });

    test('a pre-release sorts before the final release', () {
      final SemanticVersion prerelease = SemanticVersion.tryParse(
        '1.2.0-rc.1',
      )!;
      final SemanticVersion finalRelease = SemanticVersion.tryParse('1.2.0')!;
      expect(prerelease < finalRelease, isTrue);
      expect(finalRelease > prerelease, isTrue);
    });

    test('equality and hashing use the semantic value', () {
      expect(
        SemanticVersion.tryParse('1.2.3+9'),
        SemanticVersion.tryParse('v1.2.3'),
      );
      expect(
        SemanticVersion.tryParse('1.2.3+9')!.hashCode,
        SemanticVersion.tryParse('v1.2.3')!.hashCode,
      );
      expect(
        SemanticVersion.tryParse('1.2.3') == SemanticVersion.tryParse('1.2.4'),
        isFalse,
      );
      expect(SemanticVersion.tryParse('1.2.3')!.toString(), '1.2.3');
    });
  });
}
