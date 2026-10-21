import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logic_lab/core/widgets/common.dart';
import 'package:logic_lab/features/editor/domain/circuit_models.dart';
import 'package:logic_lab/features/editor/presentation/circuit_editor_screen.dart';
import 'package:logic_lab/features/projects/application/projects_controller.dart';
import 'package:logic_lab/features/projects/data/project_repository.dart';
import 'package:logic_lab/features/projects/domain/circuit_project.dart';
import 'package:logic_lab/features/settings/application/settings_controller.dart';
import 'package:provider/provider.dart';

CircuitProject _counterProject() {
  final CircuitNode clock = CircuitNode(
    id: 'clk',
    type: ComponentType.clockSource,
    position: const CanvasPoint(120, 260),
    label: 'CLK',
  );
  final CircuitNode reset = CircuitNode(
    id: 'rst',
    type: ComponentType.inputPin,
    position: const CanvasPoint(120, 380),
    label: 'RST',
  );
  final CircuitNode counter = CircuitNode(
    id: 'cnt',
    type: ComponentType.counter4,
    position: const CanvasPoint(340, 300),
    label: 'CNT4',
  );
  final CircuitNode probe = CircuitNode(
    id: 'q0',
    type: ComponentType.outputPin,
    position: const CanvasPoint(580, 280),
    label: 'Q0',
  );
  return CircuitProject(
    id: 'p1',
    name: 'شمارنده آزمایشی',
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
    graph: CircuitGraph(
      nodes: <CircuitNode>[clock, reset, counter, probe],
      wires: <CircuitWire>[
        CircuitWire(
          id: 'w1',
          fromNodeId: 'clk',
          toNodeId: 'cnt',
          toInputIndex: 0,
        ),
        CircuitWire(
          id: 'w2',
          fromNodeId: 'rst',
          toNodeId: 'cnt',
          toInputIndex: 1,
        ),
        CircuitWire(
          id: 'w3',
          fromNodeId: 'cnt',
          toNodeId: 'q0',
          toInputIndex: 0,
          fromPortIndex: 0,
        ),
      ],
    ),
  );
}

void main() {
  testWidgets('the editor shows the simulation controls and the clock level', (
    WidgetTester tester,
  ) async {
    final ProjectsController projects = ProjectsController(
      MemoryProjectRepository(),
    );
    await tester.pumpWidget(
      _wrap(
        CircuitEditorScreen(
          project: _counterProject(),
          projectsController: projects,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('مدار معتبر است'), findsOneWidget);
    expect(find.text('CLK=0'), findsOneWidget);
    expect(find.byTooltip('یک پالس کلاک'), findsOneWidget);
    expect(find.byTooltip('اجرای کلاک خودکار'), findsOneWidget);
    expect(find.byTooltip('بازنشانی وضعیت ترتیبی'), findsOneWidget);
  });

  testWidgets('stepping the clock advances the counter in the editor', (
    WidgetTester tester,
  ) async {
    final ProjectsController projects = ProjectsController(
      MemoryProjectRepository(),
    );
    await tester.pumpWidget(
      _wrap(
        CircuitEditorScreen(
          project: _counterProject(),
          projectsController: projects,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // The counter starts at zero.
    expect(find.text('CLK=0'), findsOneWidget);

    await tester.tap(find.byTooltip('یک پالس کلاک'));
    await tester.pumpAndSettle();

    // After one rising edge the least significant output is high.
    expect(find.text('CLK=0'), findsOneWidget);
    final SignalPill pill = tester.widget<SignalPill>(
      find.ancestor(of: find.text('Q0'), matching: find.byType(SignalPill)),
    );
    expect(pill.value, isTrue);
  });
}

Widget _wrap(Widget child) {
  return ChangeNotifierProvider<SettingsController>(
    create:
        (_) => SettingsController(MemorySettingsStore(), const AppSettings()),
    child: MaterialApp(home: child),
  );
}
