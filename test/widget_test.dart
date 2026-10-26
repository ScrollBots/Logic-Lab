import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logic_lab/app/app.dart';
import 'package:logic_lab/features/editor/domain/circuit_models.dart';
import 'package:logic_lab/features/learn/application/learning_controller.dart';
import 'package:logic_lab/features/learn/data/learning_progress_repository.dart';
import 'package:logic_lab/features/projects/application/projects_controller.dart';
import 'package:logic_lab/features/projects/data/project_repository.dart';
import 'package:logic_lab/features/projects/domain/circuit_project.dart';
import 'package:logic_lab/features/settings/application/settings_controller.dart';

Future<LogicLabApp> _buildApp({
  List<CircuitProject> projects = const <CircuitProject>[],
}) async {
  final SettingsController settings = await SettingsController.load(
    MemorySettingsStore(),
  );
  final ProjectsController controller = ProjectsController(
    MemoryProjectRepository(projects),
  );
  final LearningController learning = LearningController(
    MemoryLearningProgressRepository(),
  );
  await controller.load();
  await learning.load();
  return LogicLabApp(
    settings: settings,
    projects: controller,
    learning: learning,
  );
}

void main() {
  testWidgets('the shell renders an RTL navigation with four destinations', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(await _buildApp());
    await tester.pumpAndSettle();

    final BuildContext context = tester.element(find.byType(Scaffold).first);
    expect(Directionality.of(context), TextDirection.rtl);

    for (final String label in <String>[
      'خانه',
      'مدارها',
      'آزمایشگاه',
      'آموزش',
    ]) {
      expect(find.text(label), findsWidgets, reason: 'missing $label');
    }
    // Settings lives in the header, not the bottom bar.
    expect(find.byKey(const Key('app-nav-item-settings')), findsNothing);
    expect(find.byKey(const Key('app-header-settings')), findsOneWidget);
    expect(find.text('Logic Lab'), findsOneWidget);
  });

  testWidgets('the home screen shows a first-run empty state', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(await _buildApp());
    await tester.pumpAndSettle();

    expect(find.text('هنوز مداری نساخته‌اید'), findsOneWidget);
    expect(find.text('ساخت اولین مدار'), findsOneWidget);
  });

  testWidgets('selecting another destination switches the visible screen', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(await _buildApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('آموزش').last);
    await tester.pumpAndSettle();

    expect(find.text('ادامهٔ یادگیری'), findsOneWidget);
  });

  testWidgets('the projects screen lists the stored circuits', (
    WidgetTester tester,
  ) async {
    final CircuitProject project = CircuitProject(
      id: 'p1',
      name: 'مدار آزمایشی',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      graph: CircuitGraph(
        nodes: <CircuitNode>[
          CircuitNode(
            id: 'a',
            type: ComponentType.inputPin,
            position: const CanvasPoint(0, 0),
            label: 'A',
          ),
        ],
      ),
    );

    await tester.pumpWidget(
      await _buildApp(projects: <CircuitProject>[project]),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('مدارها').last);
    await tester.pumpAndSettle();

    expect(find.text('مدار آزمایشی'), findsOneWidget);
    expect(find.textContaining('۱ مدار ذخیره شده'), findsOneWidget);
  });

  testWidgets('creating a circuit from the home screen opens the editor', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(await _buildApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('مدار جدید').first);
    await tester.pumpAndSettle();

    // The editor replaces the shell, so the capsule navigation disappears.
    expect(find.text('افزودن قطعه'), findsOneWidget);
    expect(find.text('خانه'), findsNothing);
  });
}
