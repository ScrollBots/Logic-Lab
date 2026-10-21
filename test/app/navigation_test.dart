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
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

/// Text that proves the matching page is on screen.
const Map<AppDestination, String> _pageMarkers = <AppDestination, String>{
  AppDestination.home: 'از ایده تا مدار، همین‌جا',
  AppDestination.circuits: 'مدارهای من',
  AppDestination.laboratory: 'میز آزمایش گیت',
  AppDestination.learning: 'مرجع گیت‌ها',
  AppDestination.settings: 'پالت رنگ',
};

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
  // Load the stores, otherwise the projects screen shows an indeterminate
  // progress indicator and `pumpAndSettle` would never settle.
  await projects.load();
  await learning.load();
  return MultiProvider(
    providers: <SingleChildWidget>[
      ChangeNotifierProvider<SettingsController>.value(value: settings),
      ChangeNotifierProvider<ProjectsController>.value(value: projects),
      ChangeNotifierProvider<LearningController>.value(value: learning),
    ],
    child: const MaterialApp(
      // The real application runs in Persian, so the shell is RTL as well.
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

/// Returns the destination whose semantics are marked as selected.
AppDestination _selectedDestination(WidgetTester tester) {
  for (final AppDestination destination in AppNavigation.destinations) {
    final Semantics semantics = tester.widget<Semantics>(
      find.byKey(destination.itemKey),
    );
    if (semantics.properties.selected ?? false) {
      return destination;
    }
  }
  fail('no navigation item reports a selected state');
}

void main() {
  testWidgets('the destination order and index mapping are canonical', (
    WidgetTester tester,
  ) async {
    // The logical order is the order the items are declared; the enum index
    // is the only mapping used by the shell.
    expect(
      AppNavigation.destinations.map((AppDestination d) => d.label).toList(),
      <String>['خانه', 'مدارها', 'آزمایشگاه', 'آموزش', 'تنظیمات'],
    );
    for (int index = 0; index < AppNavigation.destinations.length; index++) {
      expect(AppNavigation.at(index).navIndex, index);
      expect(AppNavigation.indexOf(AppNavigation.at(index)), index);
    }
  });

  testWidgets(
    'tapping every destination shows its page and moves the capsule',
    (WidgetTester tester) async {
      await tester.pumpWidget(await _buildShell());
      await tester.pumpAndSettle();

      for (final AppDestination destination in AppNavigation.destinations) {
        await tester.tap(find.byKey(destination.itemKey));
        await tester.pumpAndSettle();

        // 1. The page that belongs to the destination is on screen.
        expect(
          find.text(_pageMarkers[destination]!),
          findsOneWidget,
          reason: 'the page of ${destination.label} must be visible',
        );

        // 2. The moving highlight sits exactly on the tapped item.
        final Rect highlight = tester.getRect(
          find.byKey(AppDestination.highlightKey),
        );
        final Rect item = tester.getRect(find.byKey(destination.itemKey));
        expect(
          highlight.center.dx,
          closeTo(item.center.dx, 1.5),
          reason:
              'the capsule highlight must follow ${destination.label} '
              '(highlight ${highlight.center.dx} vs item ${item.center.dx})',
        );

        // 3. The accessibility state matches the visible page.
        expect(_selectedDestination(tester), destination);
      }
    },
  );

  testWidgets('the reported mismatch is fixed: Settings and Circuits', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(await _buildShell());
    await tester.pumpAndSettle();

    // Reported bug: with Settings open the Home item looked selected.
    await tester.tap(find.byKey(AppDestination.settings.itemKey));
    await tester.pumpAndSettle();
    expect(find.text(_pageMarkers[AppDestination.settings]!), findsOneWidget);
    expect(_selectedDestination(tester), AppDestination.settings);
    expect(
      tester.getRect(find.byKey(AppDestination.highlightKey)).center.dx,
      closeTo(
        tester.getRect(find.byKey(AppDestination.settings.itemKey)).center.dx,
        1.5,
      ),
    );

    // Reported bug: with Circuits open the Learning item looked selected.
    await tester.tap(find.byKey(AppDestination.circuits.itemKey));
    await tester.pumpAndSettle();
    expect(find.text(_pageMarkers[AppDestination.circuits]!), findsOneWidget);
    expect(_selectedDestination(tester), AppDestination.circuits);
    expect(
      tester.getRect(find.byKey(AppDestination.highlightKey)).center.dx,
      closeTo(
        tester.getRect(find.byKey(AppDestination.circuits.itemKey)).center.dx,
        1.5,
      ),
    );
  });

  testWidgets('reverse navigation keeps the capsule and the page in sync', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(await _buildShell());
    await tester.pumpAndSettle();

    const List<AppDestination> order = <AppDestination>[
      AppDestination.home,
      AppDestination.circuits,
      AppDestination.laboratory,
      AppDestination.learning,
      AppDestination.settings,
      AppDestination.learning,
      AppDestination.laboratory,
      AppDestination.circuits,
      AppDestination.home,
    ];

    for (final AppDestination destination in order) {
      await tester.tap(find.byKey(destination.itemKey));
      await tester.pumpAndSettle();
      expect(_selectedDestination(tester), destination);
      expect(
        tester.getRect(find.byKey(AppDestination.highlightKey)).center.dx,
        closeTo(tester.getRect(find.byKey(destination.itemKey)).center.dx, 1.5),
        reason: 'capsule must stay on ${destination.label}',
      );
    }
  });

  testWidgets('rapid tab changes do not leave a stale active indicator', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(await _buildShell());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(AppDestination.learning.itemKey));
    await tester.pump(const Duration(milliseconds: 40));
    await tester.tap(find.byKey(AppDestination.settings.itemKey));
    await tester.pump(const Duration(milliseconds: 40));
    await tester.tap(find.byKey(AppDestination.home.itemKey));
    await tester.pumpAndSettle();

    expect(_selectedDestination(tester), AppDestination.home);
    expect(
      tester.getRect(find.byKey(AppDestination.highlightKey)).center.dx,
      closeTo(
        tester.getRect(find.byKey(AppDestination.home.itemKey)).center.dx,
        1.5,
      ),
    );
  });

  testWidgets('tapping the active destination keeps it selected', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(await _buildShell());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(AppDestination.laboratory.itemKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(AppDestination.laboratory.itemKey));
    await tester.pumpAndSettle();

    expect(_selectedDestination(tester), AppDestination.laboratory);
    expect(find.text(_pageMarkers[AppDestination.laboratory]!), findsOneWidget);
  });

  testWidgets('the visible order of the items is not reversed by RTL', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(await _buildShell());
    await tester.pumpAndSettle();

    // In an RTL row the first logical destination is rendered on the right.
    final double home =
        tester.getRect(find.byKey(AppDestination.home.itemKey)).center.dx;
    final double settings =
        tester.getRect(find.byKey(AppDestination.settings.itemKey)).center.dx;
    expect(
      home,
      greaterThan(settings),
      reason: 'خانه must stay the right-most item in RTL',
    );

    // ... and the capsule of the selected destination follows it.
    await tester.tap(find.byKey(AppDestination.home.itemKey));
    await tester.pumpAndSettle();
    expect(
      tester.getRect(find.byKey(AppDestination.highlightKey)).center.dx,
      closeTo(home, 1.5),
    );
  });

  testWidgets('the page area carries no overlay above the page content', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(await _buildShell());
    await tester.pumpAndSettle();

    // The body only holds the page stack. A second, absolutely positioned
    // child would be painted as a stray header line above the page title.
    final Stack body = tester.widget<Stack>(
      find.byKey(const Key('app-shell-body')),
    );
    expect(
      body.children.length,
      1,
      reason: 'the page area must not contain a top overlay',
    );

    // The sliding accent lives inside the capsule navigation, never above
    // the page content.
    final Rect accent = tester.getRect(find.byKey(AppDestination.accentKey));
    final Rect capsule = tester.getRect(
      find.byKey(const Key('app-nav-capsule')),
    );
    expect(
      capsule.contains(accent.center),
      isTrue,
      reason: 'the sliding accent must be part of the capsule navigation',
    );

    await tester.tap(find.byKey(AppDestination.circuits.itemKey));
    await tester.pumpAndSettle();

    final Rect title = tester.getRect(find.text('مدارهای من'));
    final Rect accentAfter = tester.getRect(
      find.byKey(AppDestination.accentKey),
    );
    expect(
      accentAfter.top,
      greaterThan(title.bottom),
      reason:
          'nothing may be painted between the page header and the top of the '
          'screen; the page title must be the first element of the page',
    );
  });

  testWidgets('the sliding accent follows the selected destination', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(await _buildShell());
    await tester.pumpAndSettle();

    for (final AppDestination destination in AppNavigation.destinations) {
      await tester.tap(find.byKey(destination.itemKey));
      await tester.pumpAndSettle();

      final Rect accent = tester.getRect(find.byKey(AppDestination.accentKey));
      final Rect item = tester.getRect(find.byKey(destination.itemKey));
      expect(
        accent.center.dx,
        closeTo(item.center.dx, 1.5),
        reason: 'the accent must slide to ${destination.label}',
      );
    }
  });

  testWidgets('no duplicate header appears while the page is morphing', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(await _buildShell());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(AppDestination.circuits.itemKey));
    // Mid transition: the page is scaled and moved, so nothing may detach
    // from it and appear above the page header.
    await tester.pump(const Duration(milliseconds: 80));

    expect(find.text('مدارهای من'), findsOneWidget);
    expect(find.text('مدارهای اخیر'), findsNothing);
    expect(find.text('از ایده تا مدار، همین‌جا'), findsNothing);
    expect(find.text('Logic Lab'), findsNothing);

    final Stack body = tester.widget<Stack>(
      find.byKey(const Key('app-shell-body')),
    );
    expect(body.children.length, 1);
  });
}
