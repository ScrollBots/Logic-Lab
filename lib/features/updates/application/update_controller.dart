import 'package:flutter/foundation.dart';

import '../../../core/app_info.dart';
import '../data/release_gateway.dart';
import '../data/update_store.dart';
import '../domain/app_release.dart';
import '../domain/semantic_version.dart';

enum UpdateStatus { idle, checking, upToDate, available, failed }

/// Owns the "is there a newer release?" question.
///
/// The controller never touches the network by itself: it only runs when the
/// automatic check (which the user can switch off) or the explicit "check
/// now" button asks it to. Failures are reported, never thrown into the UI,
/// so being offline is an ordinary state rather than an error dialog.
class UpdateController extends ChangeNotifier {
  UpdateController({
    required UpdateStore store,
    required ReleaseGateway gateway,
    SemanticVersion? currentVersion,
    DateTime Function()? clock,
  }) : _store = store,
       _gateway = gateway,
       currentVersion =
           currentVersion ??
           SemanticVersion.tryParse(AppInfo.version) ??
           const SemanticVersion(0, 0, 0),
       _clock = clock ?? DateTime.now;

  /// Automatic checks run at most once a day. The limit is persisted, so
  /// closing and reopening the app does not hammer GitHub.
  static const Duration checkInterval = Duration(hours: 24);

  final UpdateStore _store;
  final ReleaseGateway _gateway;
  final DateTime Function() _clock;

  final SemanticVersion currentVersion;

  UpdateStatus _status = UpdateStatus.idle;
  AppRelease? _release;
  DateTime? _lastCheckAt;
  String? _skippedVersion;
  String? _failureMessage;
  Future<AppRelease?>? _inFlight;
  bool _disposed = false;

  static Future<UpdateController> load({
    required UpdateStore store,
    required ReleaseGateway gateway,
    SemanticVersion? currentVersion,
    DateTime Function()? clock,
  }) async {
    final UpdateController controller = UpdateController(
      store: store,
      gateway: gateway,
      currentVersion: currentVersion,
      clock: clock,
    );
    await controller.restore();
    return controller;
  }

  /// Reads the remembered check time and the postponed version.
  Future<void> restore() async {
    try {
      final UpdateMemory memory = await _store.load();
      _lastCheckAt = memory.lastCheckAt;
      _skippedVersion = memory.skippedVersion;
    } catch (_) {
      // Preferences are best effort; a broken value simply means "check".
    }
    _notify();
  }

  UpdateStatus get status => _status;
  AppRelease? get release => _release;
  DateTime? get lastCheckAt => _lastCheckAt;
  String? get skippedVersion => _skippedVersion;

  /// A Persian sentence, present only after a failed check.
  String? get failureMessage => _failureMessage;

  bool get isChecking => _status == UpdateStatus.checking;

  bool get isCheckDue {
    final DateTime? last = _lastCheckAt;
    if (last == null) {
      return true;
    }
    return _clock().difference(last) >= checkInterval;
  }

  /// False when the user already pressed "later" on this exact version.
  bool shouldPrompt(AppRelease candidate) =>
      _skippedVersion != candidate.version.toString();

  /// Looks for a newer release and returns it, or `null` when the app is up to
  /// date (or the check failed).
  ///
  /// Concurrent calls share one request.
  Future<AppRelease?> check({bool manual = false}) {
    final Future<AppRelease?>? running = _inFlight;
    if (running != null) {
      return running;
    }
    final Future<AppRelease?> future = _runCheck(manual: manual);
    _inFlight = future;
    return future.whenComplete(() {
      if (identical(_inFlight, future)) {
        _inFlight = null;
      }
    });
  }

  Future<AppRelease?> _runCheck({required bool manual}) async {
    _status = UpdateStatus.checking;
    _failureMessage = null;
    _notify();
    try {
      final AppRelease? latest = await _gateway.latest();
      _lastCheckAt = _clock();
      await _persist();
      if (latest == null || !latest.isNewerThan(currentVersion)) {
        _release = null;
        _status = UpdateStatus.upToDate;
        return null;
      }
      _release = latest;
      _status = UpdateStatus.available;
      return latest;
    } on ReleaseGatewayException catch (error) {
      // A background check that fails because the phone is offline is not
      // something the user needs to see; an explicit check deserves an answer.
      _failureMessage = manual ? _describe(error.failure) : null;
      _status = manual ? UpdateStatus.failed : UpdateStatus.idle;
      return null;
    } catch (_) {
      _failureMessage = manual ? 'بررسی به‌روزرسانی ممکن نشد.' : null;
      _status = manual ? UpdateStatus.failed : UpdateStatus.idle;
      return null;
    } finally {
      _notify();
    }
  }

  /// Remembers that the user postponed this version.
  Future<void> skipVersion(String version) async {
    _skippedVersion = version;
    await _persist();
    _notify();
  }

  Future<void> _persist() async {
    try {
      await _store.save(
        UpdateMemory(
          lastCheckAt: _lastCheckAt,
          skippedVersion: _skippedVersion,
        ),
      );
    } catch (_) {
      // Ignore: the next check is simply allowed a little earlier.
    }
  }

  static String _describe(ReleaseFailure failure) {
    switch (failure) {
      case ReleaseFailure.offline:
        return 'اتصال اینترنت برقرار نیست.';
      case ReleaseFailure.timeout:
        return 'پاسخ GitHub در زمان مقرر نرسید.';
      case ReleaseFailure.rateLimited:
        return 'GitHub فعلاً اجازهٔ بررسی بیشتر نمی‌دهد؛ کمی بعد دوباره تلاش کنید.';
      case ReleaseFailure.badResponse:
        return 'پاسخ GitHub قابل خواندن نبود.';
      case ReleaseFailure.unsupported:
        return 'بررسی به‌روزرسانی در این نسخه پشتیبانی نمی‌شود.';
    }
  }

  void _notify() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
