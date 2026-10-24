import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../../../core/app_info.dart';
import '../domain/app_release.dart';
import 'release_gateway.dart';

/// Reads the latest release of the project from the public GitHub API.
///
/// This is the only network request the application ever makes, and it only
/// happens when the user (or the automatic check they can turn off) asks for
/// it. No identifier, no project data and no usage information is sent: the
/// request is a plain anonymous `GET` for a public release.
class GitHubReleaseGateway implements ReleaseGateway {
  const GitHubReleaseGateway({
    this.endpoint = defaultReleaseEndpoint,
    this.timeout = const Duration(seconds: 8),
  });

  /// Guards against a pathological response; a release payload is a few
  /// kilobytes, never hundreds.
  static const int _maxResponseBytes = 512 * 1024;

  final String endpoint;
  final Duration timeout;

  @override
  Future<AppRelease?> latest() async {
    final Uri? uri = Uri.tryParse(endpoint);
    if (uri == null || uri.scheme != 'https') {
      throw const ReleaseGatewayException(ReleaseFailure.badResponse);
    }
    final HttpClient client =
        HttpClient()
          ..connectionTimeout = timeout
          ..userAgent =
              'LogicLab/${AppInfo.version} (+https://github.com/ScrollBots/Logic-Lab)';
    try {
      final HttpClientRequest request = await client
          .getUrl(uri)
          .timeout(timeout);
      request.headers.set(
        HttpHeaders.acceptHeader,
        'application/vnd.github+json',
      );
      final HttpClientResponse response = await request.close().timeout(
        timeout,
      );

      if (response.statusCode == HttpStatus.notFound) {
        // The repository has no published release yet: not an error.
        return null;
      }
      if (response.statusCode == HttpStatus.forbidden ||
          response.statusCode == 429) {
        throw const ReleaseGatewayException(ReleaseFailure.rateLimited);
      }
      if (response.statusCode != HttpStatus.ok) {
        throw const ReleaseGatewayException(ReleaseFailure.badResponse);
      }

      final List<int> bytes = <int>[];
      await for (final List<int> chunk in response.timeout(timeout)) {
        bytes.addAll(chunk);
        if (bytes.length > _maxResponseBytes) {
          throw const ReleaseGatewayException(ReleaseFailure.badResponse);
        }
      }
      final Object? decoded = jsonDecode(utf8.decode(bytes));
      return AppRelease.fromGitHubJson(decoded);
    } on TimeoutException {
      throw const ReleaseGatewayException(ReleaseFailure.timeout);
    } on SocketException {
      throw const ReleaseGatewayException(ReleaseFailure.offline);
    } on HandshakeException {
      throw const ReleaseGatewayException(ReleaseFailure.offline);
    } on FormatException {
      throw const ReleaseGatewayException(ReleaseFailure.badResponse);
    } finally {
      client.close(force: true);
    }
  }
}

ReleaseGateway createPlatformReleaseGateway() => const GitHubReleaseGateway();
