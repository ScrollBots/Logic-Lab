import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:logic_lab/core/app_info.dart';

/// Guards the single source of truth for the application version.
///
/// The About screen, the splash screen and the Android manifest all read from
/// `pubspec.yaml`; this test fails if the Dart constants ever drift away from
/// it, which is how the version would otherwise end up as `1/0/0` or `1٫0٫0`.
void main() {
  test('the Dart version constants match pubspec.yaml', () {
    final File pubspec = File('pubspec.yaml');
    expect(pubspec.existsSync(), isTrue, reason: 'pubspec.yaml must exist');

    final String content = pubspec.readAsStringSync();
    final RegExpMatch? match = RegExp(
      r'^version:\s*([0-9]+\.[0-9]+\.[0-9]+)\+([0-9]+)\s*$',
      multiLine: true,
    ).firstMatch(content);
    expect(match, isNotNull, reason: 'pubspec.yaml must declare a version');

    final String pubVersion = match!.group(1)!;
    final String pubBuild = match.group(2)!;

    expect(AppInfo.version, pubVersion);
    expect(AppInfo.buildNumber, pubBuild);
  });

  test('the displayed version keeps a dot separator', () {
    expect(AppInfo.versionDisplay, '1.0.0');
    expect(AppInfo.versionDisplay.contains('/'), isFalse);
    expect(AppInfo.versionDisplay.contains('٫'), isFalse);
    expect(AppInfo.versionDisplay.contains('،'), isFalse);
    expect(AppInfo.versionDisplay.split('.').length, 3);
  });

  test('the application id stays stable', () {
    final File manifest = File('android/app/src/main/AndroidManifest.xml');
    expect(manifest.existsSync(), isTrue);
    final File gradle = File('android/app/build.gradle.kts');
    expect(
      gradle.readAsStringSync(),
      contains('applicationId = "ir.logiclab.logic_lab"'),
    );
  });
}
