import 'package:logic_lab/features/updates/data/release_gateway.dart';
import 'package:logic_lab/features/updates/domain/app_release.dart';

/// A release payload shaped exactly like
/// `GET /repos/ScrollBots/Logic-Lab/releases/latest`.
///
/// The field names come from the live API, so the parser is tested against
/// the real payload instead of an invented one.
Map<String, Object?> releasePayload({
  String tag = 'v1.2.0',
  String name = 'Logic Lab 1.2.0',
  String body =
      '## Logic Lab 1.2.0\n\n* به‌روزرسانی درون‌برنامه‌ای\n* یک APK یونیورسال',
  bool draft = false,
  bool prerelease = false,
  String htmlUrl =
      'https://github.com/ScrollBots/Logic-Lab/releases/tag/v1.2.0',
  List<Map<String, Object?>>? assets,
  String publishedAt = '2026-10-22T08:42:01Z',
}) {
  return <String, Object?>{
    'tag_name': tag,
    'name': name,
    'body': body,
    'draft': draft,
    'prerelease': prerelease,
    'html_url': htmlUrl,
    'published_at': publishedAt,
    'assets':
        assets ??
        <Map<String, Object?>>[
          <String, Object?>{
            'name': 'LogicLab-1.2.0-universal.apk',
            'size': 24326963,
            'browser_download_url':
                'https://github.com/ScrollBots/Logic-Lab/releases/download/v1.2.0/LogicLab-1.2.0-universal.apk',
          },
          <String, Object?>{
            'name': 'app-release.aab',
            'size': 24956108,
            'browser_download_url':
                'https://github.com/ScrollBots/Logic-Lab/releases/download/v1.2.0/app-release.aab',
          },
        ],
  };
}

/// A well formed release, ready to hand to the controller.
AppRelease sampleRelease({
  String tag = 'v1.2.0',
  List<Map<String, Object?>>? assets,
}) {
  final AppRelease? release = AppRelease.fromGitHubJson(
    releasePayload(tag: tag, assets: assets),
  );
  if (release == null) {
    throw StateError('The sample release payload no longer parses.');
  }
  return release;
}

class FakeReleaseGateway implements ReleaseGateway {
  FakeReleaseGateway({this.release, this.failure, this.delay});

  AppRelease? release;
  ReleaseFailure? failure;
  Duration? delay;
  int calls = 0;

  @override
  Future<AppRelease?> latest() async {
    calls++;
    final Duration? wait = delay;
    if (wait != null) {
      await Future<void>.delayed(wait);
    }
    final ReleaseFailure? problem = failure;
    if (problem != null) {
      throw ReleaseGatewayException(problem);
    }
    return release;
  }
}
