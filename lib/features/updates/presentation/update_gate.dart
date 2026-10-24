import 'dart:async';

import 'package:flutter/material.dart';

import '../application/update_controller.dart';
import '../application/update_launcher.dart';
import '../domain/app_release.dart';
import 'update_prompt.dart';

/// Asks GitHub for a newer release once per session, after the app is on
/// screen, and shows the update prompt when there is one.
///
/// The check is skipped entirely when the user turned it off, when the daily
/// limit has not elapsed, or when the version was already postponed. A failed
/// background check is silent by design: an offline phone is not an error.
class UpdateGate extends StatefulWidget {
  const UpdateGate({
    super.key,
    required this.controller,
    required this.autoCheck,
    required this.child,
    this.delay = const Duration(milliseconds: 1200),
    this.launch = UpdateLauncher.open,
  });

  final UpdateController controller;
  final bool autoCheck;
  final Widget child;

  /// Lets the startup animation and the first frame finish before a dialog
  /// can appear on top of the home screen.
  final Duration delay;

  final LaunchUpdateCallback launch;

  @override
  State<UpdateGate> createState() => _UpdateGateState();
}

class _UpdateGateState extends State<UpdateGate> {
  bool _started = false;
  Timer? _delayTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeCheck());
  }

  @override
  void dispose() {
    // The gate can be disposed before the delay elapses (the app was closed,
    // or a test ended). Leaving a timer behind would keep the isolate alive.
    _delayTimer?.cancel();
    super.dispose();
  }

  Future<void> _maybeCheck() async {
    if (_started) {
      return;
    }
    _started = true;
    final UpdateController controller = widget.controller;
    if (!widget.autoCheck || !controller.isCheckDue) {
      return;
    }
    await _waitForDelay();
    if (!mounted) {
      return;
    }
    final AppRelease? release = await controller.check();
    if (!mounted || release == null || !controller.shouldPrompt(release)) {
      return;
    }
    await promptForUpdate(
      context,
      controller: controller,
      release: release,
      launch: widget.launch,
    );
  }

  Future<void> _waitForDelay() {
    final Completer<void> completer = Completer<void>();
    _delayTimer = Timer(widget.delay, () {
      if (!completer.isCompleted) {
        completer.complete();
      }
    });
    return completer.future;
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
