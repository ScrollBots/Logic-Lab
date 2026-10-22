import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logic_lab/features/boolean_tools/presentation/boolean_workspace_screen.dart';
import 'package:logic_lab/features/editor/domain/circuit_models.dart';
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
        find.text(category),
        findsOneWidget,
        reason: 'the heading "$category" must not be repeated',
      );
    }
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
