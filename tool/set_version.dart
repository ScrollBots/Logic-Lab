// Sets the application version inside `pubspec.yaml`.
//
// The release workflow derives the version from the git tag and calls this
// script, so the published artifact and the About screen always agree with
// the tag.
//
// Usage:
//   dart run tool/set_version.dart 1.2.3+45
//
// The build number (the part after `+`) is optional; when it is missing the
// current build number is kept.

import 'dart:io';

final RegExp _versionPattern = RegExp(
  r'^(\d+)\.(\d+)\.(\d+)(?:-([0-9A-Za-z.-]+))?(?:\+([0-9A-Za-z.-]+))?$',
);

void main(List<String> arguments) {
  if (arguments.length != 1) {
    stderr.writeln('usage: dart run tool/set_version.dart <version>');
    exit(64);
  }

  final String requested = arguments.first.trim();
  final RegExpMatch? match = _versionPattern.firstMatch(requested);
  if (match == null) {
    stderr.writeln('Invalid version "$requested". Expected MAJOR.MINOR.PATCH[-prerelease][+build]');
    exit(64);
  }

  final File pubspec = File('pubspec.yaml');
  if (!pubspec.existsSync()) {
    stderr.writeln('pubspec.yaml not found. Run this from the project root.');
    exit(66);
  }

  final String content = pubspec.readAsStringSync();
  final RegExpMatch? current = RegExp(
    r'^version:\s*(\S+)\s*$',
    multiLine: true,
  ).firstMatch(content);
  if (current == null) {
    stderr.writeln('No "version:" line found in pubspec.yaml');
    exit(65);
  }

  final String currentVersion = current.group(1)!;
  final String buildNumber = match.group(5) ??
      (currentVersion.contains('+')
          ? currentVersion.split('+').last
          : '1');

  final String version =
      '${match.group(1)}.${match.group(2)}.${match.group(3)}'
      '${match.group(4) != null ? '-${match.group(4)}' : ''}'
      '+$buildNumber';

  final String updated = content.replaceFirst(
    RegExp(r'^version:\s*\S+\s*$', multiLine: true),
    'version: $version',
  );
  pubspec.writeAsStringSync(updated);
  stdout.writeln('pubspec.yaml version set to $version');
}
