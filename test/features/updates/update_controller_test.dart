import 'package:flutter_test/flutter_test.dart';
import 'package:logic_lab/features/updates/application/update_controller.dart';
import 'package:logic_lab/features/updates/data/release_gateway.dart';
import 'package:logic_lab/features/updates/data/update_store.dart';
import 'package:logic_lab/features/updates/domain/app_release.dart';
import 'package:logic_lab/features/updates/domain/semantic_version.dart';

import '../../support/update_test_support.dart';

void main() {
  group('UpdateController', () {
    test('reports a release only when it is newer than the app', () async {
      final UpdateController controller = UpdateController(
        store: MemoryUpdateStore(),
        gateway: FakeReleaseGateway(release: sampleRelease()),
        currentVersion: const SemanticVersion(1, 1, 0),
      );

      final AppRelease? release = await controller.check();

      expect(release, isNotNull);
      expect(release!.version, const SemanticVersion(1, 2, 0));
      expect(controller.status, UpdateStatus.available);
      expect(controller.release?.tagName, 'v1.2.0');
      expect(controller.failureMessage, isNull);
      expect(controller.lastCheckAt, isNotNull);
    });

    test('the same or an older release means the app is up to date', () async {
      for (final String tag in <String>['v1.1.0', 'v1.0.0']) {
        final UpdateController controller = UpdateController(
          store: MemoryUpdateStore(),
          gateway: FakeReleaseGateway(release: sampleRelease(tag: tag)),
          currentVersion: const SemanticVersion(1, 1, 0),
        );

        expect(await controller.check(), isNull, reason: tag);
        expect(controller.status, UpdateStatus.upToDate);
        expect(controller.release, isNull);
      }
    });

    test('a silent background failure stays silent', () async {
      final UpdateController controller = UpdateController(
        store: MemoryUpdateStore(),
        gateway: FakeReleaseGateway(failure: ReleaseFailure.offline),
        currentVersion: const SemanticVersion(1, 1, 0),
      );

      expect(await controller.check(), isNull);
      expect(controller.status, UpdateStatus.idle);
      expect(controller.failureMessage, isNull);
      // A failed check must not count as "checked", otherwise being offline
      // would delay the next attempt by a whole day.
      expect(controller.lastCheckAt, isNull);
      expect(controller.isCheckDue, isTrue);
    });

    test('an explicit failure explains itself in Persian', () async {
      final Map<ReleaseFailure, String> expected = <ReleaseFailure, String>{
        ReleaseFailure.offline: 'اتصال اینترنت برقرار نیست.',
        ReleaseFailure.timeout: 'پاسخ GitHub در زمان مقرر نرسید.',
        ReleaseFailure.badResponse: 'پاسخ GitHub قابل خواندن نبود.',
      };

      for (final MapEntry<ReleaseFailure, String> entry in expected.entries) {
        final UpdateController controller = UpdateController(
          store: MemoryUpdateStore(),
          gateway: FakeReleaseGateway(failure: entry.key),
          currentVersion: const SemanticVersion(1, 1, 0),
        );

        expect(await controller.check(manual: true), isNull);
        expect(controller.status, UpdateStatus.failed);
        expect(controller.failureMessage, entry.value);
      }

      final UpdateController limited = UpdateController(
        store: MemoryUpdateStore(),
        gateway: FakeReleaseGateway(failure: ReleaseFailure.rateLimited),
        currentVersion: const SemanticVersion(1, 1, 0),
      );
      expect(await limited.check(manual: true), isNull);
      expect(limited.failureMessage, contains('GitHub'));
    });

    test('the daily limit is persisted and respected', () async {
      DateTime now = DateTime(2026, 10, 22, 9);
      final MemoryUpdateStore store = MemoryUpdateStore();
      final FakeReleaseGateway gateway = FakeReleaseGateway(
        release: sampleRelease(tag: 'v1.1.0'),
      );
      final UpdateController controller = UpdateController(
        store: store,
        gateway: gateway,
        currentVersion: const SemanticVersion(1, 1, 0),
        clock: () => now,
      );

      expect(controller.isCheckDue, isTrue);
      await controller.check();
      expect(controller.isCheckDue, isFalse);
      expect((await store.load()).lastCheckAt, now);

      now = now.add(const Duration(hours: 23, minutes: 59));
      expect(controller.isCheckDue, isFalse);

      now = now.add(const Duration(minutes: 2));
      expect(controller.isCheckDue, isTrue);

      // A fresh instance (a restart) reads the same memory.
      final UpdateController restarted = await UpdateController.load(
        store: store,
        gateway: gateway,
        currentVersion: const SemanticVersion(1, 1, 0),
        clock: () => now,
      );
      expect(restarted.lastCheckAt, isNotNull);
    });

    test('"later" is remembered for that exact version only', () async {
      final MemoryUpdateStore store = MemoryUpdateStore();
      final UpdateController controller = UpdateController(
        store: store,
        gateway: FakeReleaseGateway(release: sampleRelease()),
        currentVersion: const SemanticVersion(1, 1, 0),
      );
      final AppRelease release = (await controller.check())!;

      await controller.skipVersion(release.version.toString());

      expect(controller.skippedVersion, '1.2.0');
      expect(controller.shouldPrompt(release), isFalse);
      expect((await store.load()).skippedVersion, '1.2.0');

      // The next release is offered again.
      final AppRelease newer = sampleRelease(tag: 'v1.3.0');
      expect(controller.shouldPrompt(newer), isTrue);
    });

    test('the postponed version survives a restart', () async {
      final MemoryUpdateStore store = MemoryUpdateStore();
      await UpdateController(
        store: store,
        gateway: FakeReleaseGateway(release: sampleRelease()),
        currentVersion: const SemanticVersion(1, 1, 0),
      ).skipVersion('1.2.0');

      final UpdateController restarted = await UpdateController.load(
        store: store,
        gateway: FakeReleaseGateway(release: sampleRelease()),
        currentVersion: const SemanticVersion(1, 1, 0),
      );
      expect(restarted.skippedVersion, '1.2.0');
      expect(restarted.shouldPrompt(sampleRelease()), isFalse);
    });

    test('concurrent checks share a single request', () async {
      final FakeReleaseGateway gateway = FakeReleaseGateway(
        release: sampleRelease(),
        delay: const Duration(milliseconds: 10),
      );
      final UpdateController controller = UpdateController(
        store: MemoryUpdateStore(),
        gateway: gateway,
        currentVersion: const SemanticVersion(1, 1, 0),
      );

      final List<AppRelease?> results = await Future.wait(<Future<AppRelease?>>[
        controller.check(),
        controller.check(),
        controller.check(manual: true),
      ]);

      expect(gateway.calls, 1);
      expect(results.every((AppRelease? release) => release != null), isTrue);
    });

    test('a later check clears the previous error', () async {
      final FakeReleaseGateway gateway = FakeReleaseGateway(
        failure: ReleaseFailure.offline,
      );
      final UpdateController controller = UpdateController(
        store: MemoryUpdateStore(),
        gateway: gateway,
        currentVersion: const SemanticVersion(1, 1, 0),
      );

      await controller.check(manual: true);
      expect(controller.status, UpdateStatus.failed);

      gateway.failure = null;
      gateway.release = sampleRelease();
      expect(await controller.check(manual: true), isNotNull);
      expect(controller.status, UpdateStatus.available);
      expect(controller.failureMessage, isNull);
    });

    test('a broken update store does not break the controller', () async {
      final UpdateController controller = await UpdateController.load(
        store: _BrokenUpdateStore(),
        gateway: FakeReleaseGateway(release: sampleRelease()),
        currentVersion: const SemanticVersion(1, 1, 0),
      );

      expect(controller.lastCheckAt, isNull);
      expect(await controller.check(), isNotNull);
    });
  });
}

class _BrokenUpdateStore implements UpdateStore {
  @override
  Future<UpdateMemory> load() async => throw const FormatException('broken');

  @override
  Future<void> save(UpdateMemory memory) async {
    throw const FormatException('broken');
  }
}
