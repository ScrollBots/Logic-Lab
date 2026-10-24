import 'package:flutter/material.dart';

import '../application/update_controller.dart';
import '../application/update_launcher.dart';
import '../domain/app_release.dart';
import 'update_dialog.dart';

typedef LaunchUpdateCallback = Future<bool> Function(Uri uri);

/// Shows the update prompt and performs the chosen action.
///
/// Shared by the automatic check at startup and the explicit check in the
/// settings, so both behave identically. "Later" is remembered for the exact
/// version, while a dismissal without a choice is not.
Future<UpdateChoice?> promptForUpdate(
  BuildContext context, {
  required UpdateController controller,
  required AppRelease release,
  LaunchUpdateCallback launch = UpdateLauncher.open,
}) async {
  final UpdateChoice? choice = await showUpdateDialog(
    context,
    release: release,
    currentVersion: controller.currentVersion,
  );
  if (choice == null) {
    return null;
  }
  if (choice == UpdateChoice.later) {
    await controller.skipVersion(release.version.toString());
    return choice;
  }
  final Uri target = release.downloadTarget;
  final bool opened = await launch(target);
  if (!opened && context.mounted) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text('مرورگر باز نشد. نشانی دانلود: $target')),
      );
  }
  return choice;
}
