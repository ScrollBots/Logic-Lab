import 'package:flutter_test/flutter_test.dart';
import 'package:logic_lab/features/updates/domain/app_release.dart';
import 'package:logic_lab/features/updates/domain/semantic_version.dart';

import '../../support/update_test_support.dart';

void main() {
  group('AppRelease parsing', () {
    test('reads a real GitHub release payload', () {
      final AppRelease release = sampleRelease();

      expect(release.version, const SemanticVersion(1, 2, 0));
      expect(release.tagName, 'v1.2.0');
      expect(release.title, 'Logic Lab 1.2.0');
      expect(release.notes, contains('به‌روزرسانی درون‌برنامه‌ای'));
      expect(
        release.pageUri,
        Uri.parse(
          'https://github.com/ScrollBots/Logic-Lab/releases/tag/v1.2.0',
        ),
      );
      expect(
        release.downloadUri,
        Uri.parse(
          'https://github.com/ScrollBots/Logic-Lab/releases/download/v1.2.0/'
          'LogicLab-1.2.0-universal.apk',
        ),
      );
      expect(release.assetName, 'LogicLab-1.2.0-universal.apk');
      expect(release.assetSize, 24326963);
      expect(release.publishedAt, DateTime.utc(2026, 10, 22, 8, 42, 1));
    });

    test('ignores the App Bundle and picks an APK only', () {
      final AppRelease? release = AppRelease.fromGitHubJson(
        releasePayload(
          assets: <Map<String, Object?>>[
            <String, Object?>{
              'name': 'app-release.aab',
              'size': 10,
              'browser_download_url':
                  'https://github.com/ScrollBots/Logic-Lab/releases/download/v1.2.0/app-release.aab',
            },
          ],
        ),
      );
      expect(release, isNotNull);
      expect(release!.downloadUri, isNull);
      // Without an installer the prompt still has somewhere useful to go.
      expect(release.downloadTarget, release.pageUri);
    });

    test('prefers the universal APK when several are published', () {
      final AppRelease? release = AppRelease.fromGitHubJson(
        releasePayload(
          assets: <Map<String, Object?>>[
            <String, Object?>{
              'name': 'app-arm64-v8a-release.apk',
              'size': 1,
              'browser_download_url':
                  'https://github.com/ScrollBots/Logic-Lab/releases/download/v1.2.0/app-arm64-v8a-release.apk',
            },
            <String, Object?>{
              'name': 'LogicLab-1.2.0-universal.apk',
              'size': 2,
              'browser_download_url':
                  'https://github.com/ScrollBots/Logic-Lab/releases/download/v1.2.0/LogicLab-1.2.0-universal.apk',
            },
          ],
        ),
      );
      expect(release!.assetName, 'LogicLab-1.2.0-universal.apk');
    });

    test('falls back to the first APK when none is labelled universal', () {
      final AppRelease? release = AppRelease.fromGitHubJson(
        releasePayload(
          assets: <Map<String, Object?>>[
            <String, Object?>{
              'name': 'app-arm64-v8a-release.apk',
              'size': 1,
              'browser_download_url':
                  'https://github.com/ScrollBots/Logic-Lab/releases/download/v1.2.0/app-arm64-v8a-release.apk',
            },
          ],
        ),
      );
      expect(release!.assetName, 'app-arm64-v8a-release.apk');
    });

    test('rejects drafts, pre-releases and unparsable tags', () {
      expect(AppRelease.fromGitHubJson(releasePayload(draft: true)), isNull);
      expect(
        AppRelease.fromGitHubJson(releasePayload(prerelease: true)),
        isNull,
      );
      expect(
        AppRelease.fromGitHubJson(releasePayload(tag: 'v1.2.0-rc.1')),
        isNull,
      );
      expect(
        AppRelease.fromGitHubJson(releasePayload(tag: 'build-42')),
        isNull,
      );
      expect(AppRelease.fromGitHubJson(null), isNull);
      expect(AppRelease.fromGitHubJson('not a release'), isNull);
      expect(AppRelease.fromGitHubJson(<String, Object?>{}), isNull);
    });

    test('never trusts a download URL outside GitHub', () {
      final AppRelease? release = AppRelease.fromGitHubJson(
        releasePayload(
          assets: <Map<String, Object?>>[
            <String, Object?>{
              'name': 'LogicLab-1.2.0-universal.apk',
              'size': 10,
              'browser_download_url': 'https://evil.example/malware.apk',
            },
          ],
        ),
      );
      expect(release, isNotNull);
      expect(release!.downloadUri, isNull);
      expect(release.downloadTarget, release.pageUri);
    });

    test('rejects a release page that is not GitHub over https', () {
      expect(
        AppRelease.fromGitHubJson(
          releasePayload(htmlUrl: 'https://evil.example/release'),
        ),
        isNull,
      );
      expect(
        AppRelease.fromGitHubJson(
          releasePayload(htmlUrl: 'http://github.com/x/y/releases/tag/v1'),
        ),
        isNull,
      );
    });

    test('only github hosts are considered trusted', () {
      expect(
        AppRelease.isTrustedUri(
          Uri.parse('https://github.com/ScrollBots/Logic-Lab/releases'),
        ),
        isTrue,
      );
      expect(
        AppRelease.isTrustedUri(
          Uri.parse('https://objects.githubusercontent.com/some/asset.apk'),
        ),
        isTrue,
      );
      expect(
        AppRelease.isTrustedUri(
          Uri.parse('https://release-assets.githubusercontent.com/a.apk'),
        ),
        isTrue,
      );
      for (final String untrusted in <String>[
        'http://github.com/x',
        'https://evil.example/x.apk',
        'https://github.com.evil.example/x.apk',
        'ftp://github.com/x',
        'https:///no-host',
      ]) {
        expect(
          AppRelease.isTrustedUri(Uri.parse(untrusted)),
          isFalse,
          reason: '$untrusted must not be trusted',
        );
      }
    });
  });

  group('AppRelease comparison', () {
    test('reports an update only for a strictly newer version', () {
      final AppRelease release = sampleRelease();
      expect(release.isNewerThan(SemanticVersion.tryParse('1.1.0')!), isTrue);
      expect(release.isNewerThan(SemanticVersion.tryParse('1.2.0')!), isFalse);
      expect(release.isNewerThan(SemanticVersion.tryParse('1.3.0')!), isFalse);
      expect(release.isNewerThan(SemanticVersion.tryParse('2.0.0')!), isFalse);
    });
  });
}
