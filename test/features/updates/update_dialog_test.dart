import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logic_lab/features/updates/domain/app_release.dart';
import 'package:logic_lab/features/updates/domain/semantic_version.dart';
import 'package:logic_lab/features/updates/presentation/update_dialog.dart';

import '../../support/update_test_support.dart';

Widget _host({
  required AppRelease release,
  required ValueChanged<UpdateChoice?> onResult,
  SemanticVersion currentVersion = const SemanticVersion(1, 1, 0),
}) {
  return MaterialApp(
    locale: const Locale('fa', 'IR'),
    supportedLocales: const <Locale>[Locale('fa', 'IR')],
    localizationsDelegates: const <LocalizationsDelegate<Object>>[
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: Builder(
      builder: (BuildContext context) => Scaffold(
        body: Center(
          child: ElevatedButton(
            onPressed: () async {
              final UpdateChoice? choice = await showUpdateDialog(
                context,
                release: release,
                currentVersion: currentVersion,
              );
              onResult(choice);
            },
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('the prompt offers both versions and exactly two actions', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _host(release: sampleRelease(), onResult: (UpdateChoice? _) {}),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('update-dialog')), findsOneWidget);
    expect(find.text('نسخهٔ جدید در دسترس است'), findsOneWidget);
    // Installed and new version, both written left to right.
    expect(find.text('1.1.0'), findsOneWidget);
    expect(find.text('1.2.0'), findsOneWidget);
    expect(find.text('نصب‌شده'), findsOneWidget);
    expect(find.text('تازه'), findsOneWidget);
    expect(find.text('بعداً'), findsOneWidget);
    expect(find.text('دانلود'), findsOneWidget);
    expect(find.byKey(const Key('update-later')), findsOneWidget);
    expect(find.byKey(const Key('update-download')), findsOneWidget);
    // Exactly two actions: postpone, or download.
    final AlertDialog dialog = tester.widget<AlertDialog>(
      find.byKey(const Key('update-dialog')),
    );
    expect(dialog.actions, hasLength(2));
    // The size is shown so the download is not a surprise.
    expect(find.textContaining('حجم فایل نصب'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the release notes are shown without Markdown punctuation', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _host(release: sampleRelease(), onResult: (UpdateChoice? _) {}),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('تغییرات این نسخه'), findsOneWidget);
    expect(find.textContaining('به‌روزرسانی درون‌برنامه‌ای'), findsOneWidget);
    // The heading markers and bullets are stripped before display.
    expect(find.textContaining('##'), findsNothing);
    expect(find.textContaining('* '), findsNothing);
  });

  testWidgets('"later" closes the prompt with that choice', (
    WidgetTester tester,
  ) async {
    UpdateChoice? result;
    await tester.pumpWidget(
      _host(
        release: sampleRelease(),
        onResult: (UpdateChoice? c) => result = c,
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('update-later')));
    await tester.pumpAndSettle();

    expect(result, UpdateChoice.later);
    expect(find.byKey(const Key('update-dialog')), findsNothing);
  });

  testWidgets('"download" closes the prompt with that choice', (
    WidgetTester tester,
  ) async {
    UpdateChoice? result;
    await tester.pumpWidget(
      _host(
        release: sampleRelease(),
        onResult: (UpdateChoice? c) => result = c,
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('update-download')));
    await tester.pumpAndSettle();

    expect(result, UpdateChoice.download);
    expect(find.byKey(const Key('update-dialog')), findsNothing);
  });

  testWidgets('dismissing the prompt is not a decision', (
    WidgetTester tester,
  ) async {
    UpdateChoice? result = UpdateChoice.download;
    await tester.pumpWidget(
      _host(
        release: sampleRelease(),
        onResult: (UpdateChoice? c) => result = c,
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tapAt(const Offset(4, 4));
    await tester.pumpAndSettle();

    expect(result, isNull);
    expect(find.byKey(const Key('update-dialog')), findsNothing);
  });

  testWidgets('a release without notes still renders a complete prompt', (
    WidgetTester tester,
  ) async {
    final AppRelease release = AppRelease.fromGitHubJson(
      releasePayload(body: '', assets: <Map<String, Object?>>[]),
    )!;
    await tester.pumpWidget(
      _host(release: release, onResult: (UpdateChoice? _) {}),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('تغییرات این نسخه'), findsNothing);
    expect(find.textContaining('حجم فایل نصب'), findsNothing);
    expect(find.byKey(const Key('update-later')), findsOneWidget);
    expect(find.byKey(const Key('update-download')), findsOneWidget);
  });
}
