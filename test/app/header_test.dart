import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logic_lab/app/shell/app_navigation.dart';
import 'package:logic_lab/app/shell/app_shell.dart';
import 'package:logic_lab/features/learn/application/learning_controller.dart';
import 'package:logic_lab/features/learn/data/learning_progress_repository.dart';
import 'package:logic_lab/features/projects/application/projects_controller.dart';
import 'package:logic_lab/features/projects/data/project_repository.dart';
import 'package:logic_lab/features/settings/application/settings_controller.dart';
import 'package:logic_lab/features/updates/application/update_controller.dart';
import 'package:logic_lab/features/updates/data/no_release_gateway.dart';
import 'package:logic_lab/features/updates/data/update_store.dart';
import 'package:logic_lab/features/updates/domain/semantic_version.dart';
import 'package:logic_lab/core/app_info.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

Future<Widget> _buildShell() async {
  final SettingsController settings = SettingsController(
    MemorySettingsStore(),
    const AppSettings(),
  );
  final ProjectsController projects = ProjectsController(
    MemoryProjectRepository(),
  );
  final LearningController learning = LearningController(
    MemoryLearningProgressRepository(),
  );
  final UpdateController updates = UpdateController(
    store: MemoryUpdateStore(),
    gateway: const NoReleaseGateway(),
    currentVersion: SemanticVersion.tryParse(AppInfo.version),
  );
  await projects.load();
  await learning.load();
  return MultiProvider(
    providers: <SingleChildWidget>[
      ChangeNotifierProvider<SettingsController>.value(value: settings),
      ChangeNotifierProvider<ProjectsController>.value(value: projects),
      ChangeNotifierProvider<LearningController>.value(value: learning),
      ChangeNotifierProvider<UpdateController>.value(value: updates),
    ],
    child: const MaterialApp(
      locale: Locale('fa', 'IR'),
      supportedLocales: <Locale>[Locale('fa', 'IR')],
      localizationsDelegates: <LocalizationsDelegate<Object>>[
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: AppShell(),
    ),
  );
}

void main() {
  testWidgets('the header exposes a Settings button', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(await _buildShell());
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('app-header')), findsOneWidget);
    expect(find.byKey(const Key('app-header-settings')), findsOneWidget);
    expect(find.byKey(const Key('app-header-identity')), findsOneWidget);
    expect(find.byKey(const Key('app-header-clock')), findsOneWidget);
  });

  testWidgets('the application identity stays in the exact horizontal center', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(await _buildShell());
    await tester.pumpAndSettle();

    final Rect identity = tester.getRect(
      find.byKey(const Key('app-header-identity')),
    );
    final double center = tester.getSize(find.byType(MaterialApp)).width / 2;
    expect(
      identity.center.dx,
      closeTo(center, 12),
      reason: 'the identity must be centered in the screen, not shifted by the side widgets',
    );
    expect(find.text('Logic Lab'), findsOneWidget);
    expect(find.text('آزمایشگاه منطق'), findsOneWidget);
  });

  testWidgets('the clock is on the left and Settings on the right in RTL', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(await _buildShell());
    await tester.pumpAndSettle();

    final Rect clock = tester.getRect(
      find.byKey(const Key('app-header-clock')),
    );
    final Rect settings = tester.getRect(
      find.byKey(const Key('app-header-settings')),
    );
    expect(clock.center.dx, lessThan(settings.center.dx));
    expect(clock.center.dx, lessThan(120));
    expect(settings.center.dx, greaterThan(200));
  });

  testWidgets('the Settings button opens the Settings screen', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(await _buildShell());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('app-header-settings')));
    await tester.pumpAndSettle();

    expect(find.text('پالت رنگ'), findsOneWidget);
    expect(find.text('تنظیمات'), findsWidgets);
  });

  testWidgets('the bottom navigation contains exactly four destinations', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(await _buildShell());
    await tester.pumpAndSettle();

    expect(AppNavigation.destinations.length, 4);
    expect(find.byKey(const Key('app-nav-capsule')), findsOneWidget);
    for (final String label in <String>[
      'خانه',
      'مدارها',
      'آزمایشگاه',
      'آموزش',
    ]) {
      expect(find.text(label), findsWidgets, reason: 'missing $label');
    }
    // Settings is no longer a bottom navigation destination.
    expect(find.byKey(const Key('app-nav-item-settings')), findsNothing);
  });
}
