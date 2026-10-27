// Prints the latest published release of the project and whether it is newer
// than a local version.
//
// Usage (from the project root):
//
//   dart run tool/check_release.dart          # compares with AppInfo.version
//   dart run tool/check_release.dart 1.1.0    # compares with any version
//
// It talks to the same endpoint, through the same gateway and the same
// parser, as the application does. That makes it the quickest way to verify
// that a real GitHub payload still parses after an API change, and to see
// exactly what the in-app prompt would offer.
//
// This is a maintainer tool: it is never bundled into the app.

import 'dart:io';

import 'package:logic_lab/core/app_info.dart';
import 'package:logic_lab/features/updates/data/release_gateway.dart';
import 'package:logic_lab/features/updates/domain/app_release.dart';
import 'package:logic_lab/features/updates/domain/semantic_version.dart';

Future<void> main(List<String> arguments) async {
  final String localVersion = arguments.isNotEmpty
      ? arguments.first.trim()
      : AppInfo.version;
  final SemanticVersion? current = SemanticVersion.tryParse(localVersion);
  if (current == null) {
    stderr.writeln(
      'Invalid version "$localVersion". Expected MAJOR.MINOR.PATCH.',
    );
    exit(64);
  }

  stdout.writeln('GitHub endpoint: $defaultReleaseEndpoint');
  stdout.writeln('Local version:  $current');
  stdout.writeln('');

  final ReleaseGateway gateway = createReleaseGateway();
  try {
    final AppRelease? release = await gateway.latest();
    if (release == null) {
      stdout.writeln('No published release was found (or it is a draft).');
      return;
    }

    stdout.writeln('Latest tag:      ${release.tagName}');
    stdout.writeln('Latest version:  ${release.version}');
    stdout.writeln('Title:           ${release.title}');
    if (release.publishedAt != null) {
      stdout.writeln(
        'Published:       ${release.publishedAt!.toIso8601String()}',
      );
    }
    stdout.writeln('Release page:    ${release.pageUri}');
    stdout.writeln('Notes length:    ${release.notes.length} characters');

    if (release.downloadUri == null) {
      stdout.writeln(
        'Installer:       none (the release page would be opened)',
      );
    } else {
      stdout.writeln('Installer:       ${release.assetName}');
      stdout.writeln('Download URL:    ${release.downloadUri}');
      if (release.assetSize != null) {
        final String megabytes = (release.assetSize! / (1024 * 1024))
            .toStringAsFixed(1);
        stdout.writeln('Installer size:  $megabytes MB');
      }
      stdout.writeln(
        'Trusted host:    ${AppRelease.isTrustedUri(release.downloadTarget)}',
      );
    }

    stdout.writeln('');
    if (release.isNewerThan(current)) {
      stdout.writeln('Update available: $current -> ${release.version}');
      stdout.writeln('The in-app prompt would offer this release.');
    } else {
      stdout.writeln('Already up to date: $current >= ${release.version}');
      stdout.writeln('The in-app prompt would stay hidden.');
    }
  } on ReleaseGatewayException catch (error) {
    stderr.writeln('The release could not be read: ${error.failure.name}');
    exit(75);
  }
}
