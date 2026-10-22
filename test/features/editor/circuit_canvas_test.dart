import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logic_lab/core/theme/logic_lab_theme.dart';
import 'package:logic_lab/features/editor/application/circuit_editor_controller.dart';
import 'package:logic_lab/features/editor/domain/circuit_geometry.dart';
import 'package:logic_lab/features/editor/domain/circuit_models.dart';
import 'package:logic_lab/features/editor/domain/circuit_simulator.dart';
import 'package:logic_lab/features/editor/presentation/circuit_canvas.dart';
import 'package:logic_lab/features/projects/domain/circuit_project.dart';

CircuitProject _project() {
  return CircuitProject(
    id: 'p1',
    name: 'آزمایش کانواس',
    createdAt: DateTime.utc(2026, 1, 1),
    updatedAt: DateTime.utc(2026, 1, 1),
    graph: CircuitGraph(
      nodes: <CircuitNode>[
        CircuitNode(
          id: 'gate',
          type: ComponentType.andGate,
          position: const CanvasPoint(480, 360),
          label: 'AND',
        ),
      ],
    ),
  );
}

CircuitProject _wireProject({bool high = false, bool decoder = false}) {
  return _project().copyWith(
    graph: CircuitGraph(
      nodes: <CircuitNode>[
        CircuitNode(
          id: 'source',
          type: decoder ? ComponentType.decoder2to4 : ComponentType.inputPin,
          position: const CanvasPoint(480, 360),
          label: 'SOURCE',
          inputValue: high,
        ),
        CircuitNode(
          id: 'target',
          type: ComponentType.outputPin,
          position: const CanvasPoint(800, 360),
          label: 'TARGET',
        ),
      ],
      wires:
          high
              ? <CircuitWire>[
                CircuitWire(
                  id: 'wire',
                  fromNodeId: 'source',
                  toNodeId: 'target',
                  toInputIndex: 0,
                ),
              ]
              : const <CircuitWire>[],
    ),
  );
}

CircuitEditorController _editorFor(CircuitProject project) {
  return CircuitEditorController(
    project: project,
    onSave: (CircuitProject saved, CircuitGraph graph) async {
      return saved.copyWith(graph: graph);
    },
  );
}

Finder _port(String nodeLabel, {required bool input, int index = 0}) {
  return find
      .byWidgetPredicate((Widget widget) {
        return widget is Semantics &&
            (widget.properties.label?.startsWith(
                  input ? 'پایه ورودی ' : 'پایه خروجی ',
                ) ??
                false) &&
            (widget.properties.label?.endsWith(' از $nodeLabel') ?? false);
      })
      .at(index);
}

void main() {
  test('dark neon defaults do not replace custom signal colors', () {
    ThemeData theme({
      Color high = const Color(0xFF1D9B72),
      Color low = const Color(0xFF6D7B8E),
      Brightness brightness = Brightness.dark,
    }) => LogicLabTheme.build(
      brightness: brightness,
      seed: const Color(0xFF1F5FCC),
      highSignal: high,
      lowSignal: low,
    );
    final LogicLabColors dark = theme().extension<LogicLabColors>()!;
    expect(dark.highSignal, const Color(0xFF22C55E));
    expect(dark.canvas, const Color(0xFF0F172A));
    const Color customHigh = Color(0xFF00FFFF);
    const Color customLow = Color(0xFFFF00FF);
    final LogicLabColors custom =
        theme(high: customHigh, low: customLow).extension<LogicLabColors>()!;
    expect(custom.highSignal, customHigh);
    expect(custom.lowSignal, customLow);
    expect(
      theme(
        brightness: Brightness.light,
      ).extension<LogicLabColors>()!.highSignal,
      const Color(0xFF1D9B72),
    );
  });

  test(
    'painter invalidates for grid, selection and pending output changes',
    () {
      final CircuitGraph graph = _project().graph;
      final SimulationResult report = CircuitSimulator(graph).evaluate();
      final ThemeData theme = ThemeData.light(useMaterial3: true);

      CircuitPainter painter({
        bool showGrid = true,
        int pendingSourcePort = 0,
        Set<String> selectedNodeIds = const <String>{},
        CircuitPaintLayer layer = CircuitPaintLayer.nodes,
      }) {
        return CircuitPainter(
          graph: graph,
          report: report,
          selectedNodeId: null,
          selectedWireId: null,
          pendingSourceId: 'gate',
          pendingSourcePort: pendingSourcePort,
          selectedNodeIds: selectedNodeIds,
          showGrid: showGrid,
          theme: theme,
          colors: LogicLabColors.fallback,
          layer: layer,
        );
      }

      final CircuitPainter original = painter();
      expect(painter().shouldRepaint(original), isFalse);
      final CircuitPainter grid = painter(layer: CircuitPaintLayer.grid);
      expect(
        painter(
          layer: CircuitPaintLayer.grid,
          showGrid: false,
        ).shouldRepaint(grid),
        isTrue,
      );
      expect(painter(pendingSourcePort: 1).shouldRepaint(original), isTrue);
      expect(
        painter(
          selectedNodeIds: const <String>{'gate'},
        ).shouldRepaint(original),
        isTrue,
      );
    },
  );

  testWidgets('zoom buttons preserve the visible scene center', (
    WidgetTester tester,
  ) async {
    final CircuitEditorController editor = _editorFor(_project());
    addTearDown(editor.dispose);
    final CircuitCanvasController canvas = CircuitCanvasController();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CircuitCanvas(
            editor: editor,
            canvasController: canvas,
            animationsEnabled: false,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final CanvasPoint center = canvas.visibleCenter()!;
    canvas.zoomIn();
    await tester.pump();
    expect(canvas.visibleCenter()!.x, closeTo(center.x, 0.001));
    expect(canvas.visibleCenter()!.y, closeTo(center.y, 0.001));
    canvas.zoomOut();
    await tester.pump();
    expect(canvas.visibleCenter()!.x, closeTo(center.x, 0.001));
    expect(canvas.visibleCenter()!.y, closeTo(center.y, 0.001));
  });

  testWidgets('wire drag selects the nearest output and connects at low zoom', (
    WidgetTester tester,
  ) async {
    final CircuitEditorController editor = _editorFor(
      _wireProject(decoder: true),
    );
    addTearDown(editor.dispose);
    final CircuitCanvasController canvas = CircuitCanvasController();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CircuitCanvas(
            editor: editor,
            canvasController: canvas,
            animationsEnabled: false,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    canvas.zoomOut();
    await tester.pump();
    final Offset start = tester.getCenter(_port('SOURCE', input: false));
    final Offset end = tester.getCenter(_port('TARGET', input: true));
    await tester.tapAt(start);
    await tester.pump();
    expect(editor.pendingSourcePort, 0);
    editor.cancelPendingConnection();
    await tester.dragFrom(start, end - start);
    await tester.pumpAndSettle();
    expect(editor.graph.wires, hasLength(1));
    expect(editor.graph.wires.single.fromPortIndex, 0);
    expect(editor.graph.wires.single.toNodeId, 'target');
    expect(editor.hasPendingConnection, isFalse);
    await editor.flush();
  });

  testWidgets('offscreen node overlays are culled and return after fitting', (
    WidgetTester tester,
  ) async {
    final CircuitProject project = _project().copyWith(
      graph: CircuitGraph(
        nodes: <CircuitNode>[
          CircuitNode(
            id: 'left',
            type: ComponentType.andGate,
            position: const CanvasPoint(100, 100),
            label: 'LEFT',
          ),
          CircuitNode(
            id: 'right',
            type: ComponentType.andGate,
            position: const CanvasPoint(1700, 1000),
            label: 'RIGHT',
          ),
        ],
      ),
    );
    final CircuitEditorController editor = _editorFor(project);
    addTearDown(editor.dispose);
    final CircuitCanvasController canvas = CircuitCanvasController();
    final Finder nodes = find.byWidgetPredicate(
      (Widget widget) =>
          widget is Semantics &&
          <String>['LEFT، AND', 'RIGHT، AND'].contains(widget.properties.label),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CircuitCanvas(
            editor: editor,
            canvasController: canvas,
            animationsEnabled: false,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(nodes, findsNWidgets(2));
    for (int i = 0; i < 20; i++) {
      canvas.zoomIn();
    }
    await tester.pump();
    expect(nodes, findsNothing);
    canvas.resetView();
    await tester.pump();
    expect(nodes, findsNWidgets(2));
  });

  testWidgets('dropping a wire on empty canvas cancels the connection', (
    WidgetTester tester,
  ) async {
    final CircuitEditorController editor = _editorFor(_wireProject());
    addTearDown(editor.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CircuitCanvas(
            editor: editor,
            canvasController: CircuitCanvasController(),
            animationsEnabled: false,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.drag(_port('SOURCE', input: false), const Offset(60, 90));
    await tester.pumpAndSettle();
    expect(editor.graph.wires, isEmpty);
    expect(editor.hasPendingConnection, isFalse);
  });

  testWidgets('a refused wire drop keeps its error without a success haptic', (
    WidgetTester tester,
  ) async {
    final List<MethodCall> calls = <MethodCall>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (MethodCall call) async {
        if (call.method == 'HapticFeedback.vibrate') {
          calls.add(call);
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    final CircuitEditorController editor = _editorFor(_wireProject(high: true));
    addTearDown(editor.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CircuitCanvas(
            editor: editor,
            canvasController: CircuitCanvasController(),
            animationsEnabled: false,
            hapticsEnabled: true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final Offset start = tester.getCenter(_port('SOURCE', input: false));
    final Offset end = tester.getCenter(_port('TARGET', input: true));
    await tester.dragFrom(start, end - start);
    await tester.pumpAndSettle();
    expect(editor.graph.wires, hasLength(1));
    expect(editor.hasPendingConnection, isFalse);
    expect(editor.feedback?.tone, EditorFeedbackTone.error);
    expect(
      calls.where(
        (MethodCall call) => call.arguments == 'HapticFeedbackType.lightImpact',
      ),
      isEmpty,
    );
  });

  testWidgets('HIGH wire animation respects settings and reduced motion', (
    WidgetTester tester,
  ) async {
    final CircuitEditorController editor = _editorFor(_wireProject(high: true));
    addTearDown(editor.dispose);
    final CircuitCanvasController canvas = CircuitCanvasController();
    Future<void> mount({bool enabled = true, bool reduced = false}) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(disableAnimations: reduced),
            child: Scaffold(
              body: CircuitCanvas(
                editor: editor,
                canvasController: canvas,
                animationsEnabled: enabled,
              ),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    CircuitPainter wirePainter() => tester
        .widgetList<CustomPaint>(find.byType(CustomPaint))
        .map((CustomPaint widget) => widget.painter)
        .whereType<CircuitPainter>()
        .singleWhere(
          (CircuitPainter painter) => painter.layer == CircuitPaintLayer.wires,
        );

    await mount();
    final AnimationController flow =
        wirePainter().flowAnimation! as AnimationController;
    expect(flow.isAnimating, isTrue);
    await tester.pump(const Duration(milliseconds: 100));
    expect(flow.value, greaterThan(0));
    editor.toggleInput('source');
    await tester.pump();
    expect(flow.isAnimating, isFalse);
    editor.toggleInput('source');
    await tester.pump();
    expect(flow.isAnimating, isTrue);
    await mount(reduced: true);
    expect(wirePainter().flowAnimation, isNull);
    expect(flow.isAnimating, isFalse);
    await mount(enabled: false);
    expect(wirePainter().flowAnimation, isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await editor.flush();
  });

  testWidgets('input haptics are emitted only when enabled', (
    WidgetTester tester,
  ) async {
    final List<MethodCall> calls = <MethodCall>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (MethodCall call) async {
        if (call.method == 'HapticFeedback.vibrate') {
          calls.add(call);
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    final CircuitEditorController editor = _editorFor(_wireProject());
    addTearDown(editor.dispose);
    final CircuitCanvasController canvas = CircuitCanvasController();
    for (final bool enabled in <bool>[false, true]) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CircuitCanvas(
              editor: editor,
              canvasController: canvas,
              animationsEnabled: false,
              hapticsEnabled: enabled,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tapAt(
        tester.getCenter(
          find.byWidgetPredicate(
            (Widget widget) =>
                widget is Semantics &&
                (widget.properties.label?.startsWith('SOURCE، ورودی،') ??
                    false),
          ),
        ),
      );
      await tester.pump();
      expect(calls, hasLength(enabled ? 1 : 0));
    }
    await editor.flush();
  });

  testWidgets('node drag uses scene coordinates while zoomed', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final CircuitProject project = _project();
    final CircuitEditorController editor = CircuitEditorController(
      project: project,
      onSave: (CircuitProject saved, CircuitGraph graph) async {
        return saved.copyWith(graph: graph);
      },
    );
    addTearDown(editor.dispose);
    final CircuitCanvasController canvas = CircuitCanvasController();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CircuitCanvas(editor: editor, canvasController: canvas),
        ),
      ),
    );
    await tester.pumpAndSettle();

    for (int i = 0; i < 4; i++) {
      canvas.zoomIn();
    }
    await tester.pump();
    final double scale = canvas.currentScale()!;
    expect(scale, greaterThan(1.8));

    final Finder gate = find.bySemanticsLabel('AND، AND');
    expect(gate, findsOneWidget);
    const double screenDelta = 48;
    await tester.drag(
      find.descendant(of: gate, matching: find.byType(GestureDetector)),
      const Offset(screenDelta, 0),
    );
    await tester.pumpAndSettle();

    final double sceneDelta = screenDelta / scale;
    final double expectedX =
        ((480 + sceneDelta) / CircuitGeometry.gridSize).round() *
        CircuitGeometry.gridSize;
    expect(editor.graph.nodeById('gate')!.position.x, expectedX);
    await editor.flush();
  });
}
