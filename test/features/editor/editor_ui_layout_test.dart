import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logic_lab/features/boolean_tools/presentation/boolean_workspace_screen.dart';
import 'package:logic_lab/features/editor/domain/circuit_models.dart';
import 'package:logic_lab/features/editor/domain/component_spec.dart';
import 'package:logic_lab/features/editor/presentation/circuit_editor_screen.dart';
import 'package:logic_lab/features/projects/application/projects_controller.dart';
import 'package:logic_lab/features/projects/data/project_repository.dart';
import 'package:logic_lab/features/projects/domain/circuit_project.dart';
import 'package:logic_lab/features/settings/application/settings_controller.dart';
import 'package:provider/provider.dart';

CircuitProject _emptyProject() {
  return CircuitProject(
    id: 'p1',
    name: 'پروژه خالی',
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
    graph: CircuitGraph(
      nodes: <CircuitNode>[
        CircuitNode(
          id: 'a',
          type: ComponentType.inputPin,
          position: const CanvasPoint(120, 200),
          label: 'A',
        ),
      ],
    ),
  );
}

Widget _wrap(Widget child) {
  return ChangeNotifierProvider<SettingsController>(
    create:
        (_) => SettingsController(MemorySettingsStore(), const AppSettings()),
    child: MaterialApp(home: child),
  );
}

void main() {
  testWidgets('every category of the component tray is listed only once', (
    WidgetTester tester,
  ) async {
    final ProjectsController projects = ProjectsController(
      MemoryProjectRepository(),
    );
    await tester.pumpWidget(
      _wrap(
        CircuitEditorScreen(
          project: _emptyProject(),
          projectsController: projects,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('افزودن قطعه'));
    await tester.pumpAndSettle();

    for (final String category in <String>[
      'پایه‌ها',
      'گیت‌های پایه',
      'گیت‌های مرکب',
      'ماژول‌های حسابی',
      'انتخابگر و کدگذار',
      'مدارهای ترتیبی',
    ]) {
      expect(
        find.byKey(ValueKey<String>('component-category-heading-$category')),
        findsOneWidget,
        reason: 'the heading "$category" must not be repeated',
      );
      expect(
        find.descendant(
          of: find.byType(ChoiceChip),
          matching: find.text(category),
        ),
        findsOneWidget,
      );
    }
    expect(find.text('قطعه‌ای با این نام پیدا نشد.'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tray search and category filters share the same results', (
    WidgetTester tester,
  ) async {
    await _openTray(tester);
    final String halfAdder =
        ComponentLibrary.specOf(ComponentType.halfAdder).title;
    final Finder bases = find.descendant(
      of: find.byType(ChoiceChip),
      matching: find.text('پایه‌ها'),
    );

    await tester.enterText(find.byType(TextField), '  HaLfAdDeR  ');
    await tester.pumpAndSettle();
    expect(find.text(halfAdder), findsOneWidget);
    expect(find.text('قطعه‌ای با این نام پیدا نشد.'), findsNothing);
    expect(
      find.byKey(const ValueKey<String>('component-category-heading-پایه‌ها')),
      findsNothing,
    );

    await tester.tap(bases);
    await tester.pumpAndSettle();
    expect(find.text(halfAdder), findsNothing);
    expect(find.text('قطعه‌ای با این نام پیدا نشد.'), findsOneWidget);

    await tester.tap(find.text('همه'));
    await tester.pumpAndSettle();
    expect(find.text(halfAdder), findsOneWidget);
    expect(find.text('قطعه‌ای با این نام پیدا نشد.'), findsNothing);

    await tester.tap(find.byTooltip('پاک کردن'));
    await tester.pumpAndSettle();
    await tester.tap(bases);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey<String>('component-category-heading-پایه‌ها')),
      findsOneWidget,
    );
    expect(
      find.byKey(
        const ValueKey<String>('component-category-heading-گیت‌های پایه'),
      ),
      findsNothing,
    );

    await tester.enterText(find.byType(TextField), 'کلاک');
    await tester.pumpAndSettle();
    expect(find.text('کلاک'), findsWidgets);
    expect(find.text('قطعه‌ای با این نام پیدا نشد.'), findsNothing);

    await tester.enterText(find.byType(TextField), 'no-such-component');
    await tester.pumpAndSettle();
    expect(find.text('قطعه‌ای با این نام پیدا نشد.'), findsOneWidget);
    await tester.tap(find.byTooltip('پاک کردن'));
    await tester.pumpAndSettle();
    expect(find.text('قطعه‌ای با این نام پیدا نشد.'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tray resizes and keeps search above a small-screen keyboard', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await _openTray(tester);

    final Finder sheetFinder = find.byType(DraggableScrollableSheet);
    final DraggableScrollableSheet sheet = tester.widget(sheetFinder);
    expect(sheet.expand, isFalse);
    expect(sheet.initialChildSize, 0.6);
    expect(sheet.minChildSize, 0.35);
    expect(sheet.maxChildSize, 0.9);
    final Finder scrollFinder = find.descendant(
      of: sheetFinder,
      matching: find.byWidgetPredicate(
        (Widget widget) =>
            widget is SingleChildScrollView &&
            widget.scrollDirection == Axis.vertical,
      ),
    );
    final SingleChildScrollView scroll = tester.widget(scrollFinder);
    expect(scroll.controller, isNotNull);
    expect(scroll.controller!.hasClients, isTrue);
    final double initialHeight = tester.getSize(sheetFinder).height;
    await tester.drag(
      find.text('قطعه را انتخاب کنید؛ سپس آن را روی بوم جابه‌جا کنید.'),
      const Offset(0, -120),
    );
    await tester.pumpAndSettle();
    expect(tester.getSize(sheetFinder).height, greaterThan(initialHeight));

    await tester.tap(find.byType(TextField));
    tester.view.viewInsets = const FakeViewPadding(bottom: 220);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'input');
    await tester.pumpAndSettle();
    expect(
      tester.getRect(find.byType(TextField)).bottom,
      lessThanOrEqualTo(420),
    );
    expect(find.text('قطعه‌ای با این نام پیدا نشد.'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the boolean tool header stays readable on a small screen', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(360, 720);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_wrap(const BooleanWorkspaceScreen()));
    await tester.pumpAndSettle();

    expect(find.text('عبارت بولی'), findsOneWidget);
    expect(find.text('نمونه:'), findsOneWidget);
    expect(find.text('(A & B) | !C'), findsOneWidget);
    expect(find.text('محاسبه'), findsOneWidget);
    // The heading and the buttons must not overflow on a narrow screen.
    expect(tester.takeException(), isNull);
  });

  testWidgets('the boolean tool header stays readable on a wide screen', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_wrap(const BooleanWorkspaceScreen()));
    await tester.pumpAndSettle();

    expect(find.text('عبارت بولی'), findsOneWidget);
    expect(find.text('(A & B) | !C'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _openTray(WidgetTester tester) async {
  final ProjectsController projects = ProjectsController(
    MemoryProjectRepository(),
  );
  await tester.pumpWidget(
    _wrap(
      CircuitEditorScreen(
        project: _emptyProject(),
        projectsController: projects,
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('افزودن قطعه'));
  await tester.pumpAndSettle();
}
