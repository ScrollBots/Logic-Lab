import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logic_lab/features/updates/application/update_controller.dart';
import 'package:logic_lab/features/updates/data/release_gateway.dart';
import 'package:logic_lab/features/updates/data/update_store.dart';
import 'package:logic_lab/features/updates/domain/semantic_version.dart';
import 'package:logic_lab/features/updates/presentation/update_gate.dart';
import 'package:logic_lab/features/updates/presentation/update_prompt.dart';

import '../../support/update_test_support.dart';

Widget _host({
  required UpdateController controller,
  required bool autoCheck,
  LaunchUpdateCallback? launch,
  Duration delay = Duration.zero,
}) {
  return MaterialApp(
    locale: const Locale('fa', 'IR'),
    supportedLocales: const <Locale>[Locale('fa', 'IR')],
    localizationsDelegates: const <LocalizationsDelegate<Object>>[
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: UpdateGate(
      controller: controller,
      autoCheck: autoCheck,
      delay: delay,
      launch: launch ?? (Uri _) async => true,
      child: const Scaffold(body: Center(child: Text('خانه'))),
    ),
  );
}

/// Builds a controller with its persisted memory already restored, exactly as
/// the bootstrap does on a real launch.
Future<UpdateController> _controller({
  required FakeReleaseGateway gateway,
  DateTime? lastCheck,
  String? skipped,
  DateTime Function()? clock,
}) {
  return UpdateController.load(
    store: MemoryUpdateStore(
      UpdateMemory(lastCheckAt: lastCheck, skippedVersion: skipped),
    ),
    gateway: gateway,
    currentVersion: const SemanticVersion(1, 1, 0),
    clock: clock,
  );
}

void main() {
  testWidgets('shows the prompt once when a newer release exists', (
    WidgetTester tester,
  ) async {
    final FakeReleaseGateway gateway = FakeReleaseGateway(
      release: sampleRelease(),
    );
    await tester.pumpWidget(
      _host(controller: await _controller(gateway: gateway), autoCheck: true),
    );
    await tester.pumpAndSettle();

    expect(gateway.calls, 1);
    expect(find.byKey(const Key('update-dialog')), findsOneWidget);
    expect(find.text('بعداً'), findsOneWidget);
    expect(find.text('دانلود'), findsOneWidget);
    expect(find.text('1.2.0'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('"download" opens the installer asset', (
    WidgetTester tester,
  ) async {
    final FakeReleaseGateway gateway = FakeReleaseGateway(
      release: sampleRelease(),
    );
    final List<Uri> opened = <Uri>[];
    await tester.pumpWidget(
      _host(
        controller: await _controller(gateway: gateway),
        autoCheck: true,
        launch: (Uri uri) async {
          opened.add(uri);
          return true;
        },
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('update-download')));
    await tester.pumpAndSettle();

    expect(opened, <Uri>[sampleRelease().downloadTarget]);
    expect(opened.single.path, endsWith('.apk'));
    expect(find.byKey(const Key('update-dialog')), findsNothing);
  });

  testWidgets('"later" is remembered and the prompt does not return', (
    WidgetTester tester,
  ) async {
    final FakeReleaseGateway gateway = FakeReleaseGateway(
      release: sampleRelease(),
    );
    final UpdateController controller = await _controller(gateway: gateway);
    await tester.pumpWidget(_host(controller: controller, autoCheck: true));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('update-later')));
    await tester.pumpAndSettle();

    expect(controller.skippedVersion, '1.2.0');
    expect(controller.shouldPrompt(sampleRelease()), isFalse);
    expect(find.byKey(const Key('update-dialog')), findsNothing);

    // The next launch reads the same postponed version and stays quiet.
    // The gate is torn down first so its state is rebuilt like a real restart.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    final FakeReleaseGateway secondGateway = FakeReleaseGateway(
      release: sampleRelease(),
    );
    await tester.pumpWidget(
      _host(
        controller: await _controller(
          gateway: secondGateway,
          skipped: controller.skippedVersion,
        ),
        autoCheck: true,
      ),
    );
    await tester.pumpAndSettle();

    expect(secondGateway.calls, 1);
    expect(find.byKey(const Key('update-dialog')), findsNothing);
  });

  testWidgets('nothing happens when the automatic check is off', (
    WidgetTester tester,
  ) async {
    final FakeReleaseGateway gateway = FakeReleaseGateway(
      release: sampleRelease(),
    );
    await tester.pumpWidget(
      _host(controller: await _controller(gateway: gateway), autoCheck: false),
    );
    await tester.pumpAndSettle();

    expect(gateway.calls, 0);
    expect(find.byKey(const Key('update-dialog')), findsNothing);
  });

  testWidgets('the daily limit prevents a second prompt', (
    WidgetTester tester,
  ) async {
    final DateTime now = DateTime(2026, 10, 24, 12);
    final FakeReleaseGateway gateway = FakeReleaseGateway(
      release: sampleRelease(),
    );
    await tester.pumpWidget(
      _host(
        controller: await _controller(
          gateway: gateway,
          lastCheck: now.subtract(const Duration(hours: 3)),
          clock: () => now,
        ),
        autoCheck: true,
      ),
    );
    await tester.pumpAndSettle();

    expect(gateway.calls, 0);
    expect(find.byKey(const Key('update-dialog')), findsNothing);
  });

  testWidgets('a failed background check is silent', (
    WidgetTester tester,
  ) async {
    final FakeReleaseGateway gateway = FakeReleaseGateway(
      failure: ReleaseFailure.offline,
    );
    await tester.pumpWidget(
      _host(controller: await _controller(gateway: gateway), autoCheck: true),
    );
    await tester.pumpAndSettle();

    expect(gateway.calls, 1);
    expect(find.byKey(const Key('update-dialog')), findsNothing);
    expect(find.textContaining('اتصال اینترنت'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('being up to date shows nothing at all', (
    WidgetTester tester,
  ) async {
    final FakeReleaseGateway gateway = FakeReleaseGateway(
      release: sampleRelease(tag: 'v1.1.0'),
    );
    await tester.pumpWidget(
      _host(controller: await _controller(gateway: gateway), autoCheck: true),
    );
    await tester.pumpAndSettle();

    expect(gateway.calls, 1);
    expect(find.byKey(const Key('update-dialog')), findsNothing);
  });

  testWidgets('closing the app before the delay keeps no timer alive', (
    WidgetTester tester,
  ) async {
    final FakeReleaseGateway gateway = FakeReleaseGateway(
      release: sampleRelease(),
    );
    await tester.pumpWidget(
      _host(
        controller: await _controller(gateway: gateway),
        autoCheck: true,
        delay: const Duration(seconds: 5),
      ),
    );
    // Replace the tree before the delayed check would run.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();

    expect(gateway.calls, 0);
    expect(tester.takeException(), isNull);
  });
}
