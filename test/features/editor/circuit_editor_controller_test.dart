import 'package:flutter_test/flutter_test.dart';
import 'package:logic_lab/features/editor/application/circuit_editor_controller.dart';
import 'package:logic_lab/features/editor/domain/circuit_models.dart';
import 'package:logic_lab/features/projects/domain/circuit_project.dart';

void main() {
  late List<CircuitGraph> savedGraphs;
  late CircuitEditorController controller;

  CircuitProject project() {
    return CircuitProject(
      id: 'p1',
      name: 'پروژه آزمایشی',
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 1, 1),
      graph: CircuitGraph(
        nodes: <CircuitNode>[
          CircuitNode(
            id: 'in-a',
            type: ComponentType.inputPin,
            position: const CanvasPoint(100, 120),
            label: 'A',
          ),
        ],
      ),
    );
  }

  setUp(() {
    savedGraphs = <CircuitGraph>[];
    controller = CircuitEditorController(
      project: project(),
      onSave: (CircuitProject saved, CircuitGraph graph) async {
        savedGraphs.add(graph);
        return saved.copyWith(
          graph: graph,
          updatedAt: DateTime.utc(2026, 2, 2),
        );
      },
    );
  });

  test('adding a component updates the graph and the simulation', () {
    controller.addNode(ComponentType.andGate, const CanvasPoint(300, 150));
    expect(controller.graph.nodes.length, 2);
    expect(controller.canUndo, isTrue);
    expect(controller.report.problems, isNotEmpty);
  });

  test('connecting an output to an input creates a wire', () {
    final CircuitNode gate = controller.addNode(
      ComponentType.andGate,
      const CanvasPoint(300, 150),
    );
    controller.tapOutputPort('in-a');
    expect(controller.hasPendingConnection, isTrue);
    controller.tapInputPort(gate.id, 0);
    expect(controller.graph.wires.length, 1);
    expect(controller.hasPendingConnection, isFalse);
    expect(controller.feedback?.tone, EditorFeedbackTone.success);
  });

  test('an invalid connection is refused and reported', () {
    final CircuitNode gate = controller.addNode(
      ComponentType.andGate,
      const CanvasPoint(300, 150),
    );
    controller.tapOutputPort('in-a');
    controller.tapInputPort(gate.id, 0);
    // The same input port cannot receive a second wire.
    controller.tapOutputPort('in-a');
    controller.tapInputPort(gate.id, 0);
    expect(controller.graph.wires.length, 1);
    expect(controller.feedback?.tone, EditorFeedbackTone.error);
  });

  test('toggling an input re-evaluates the circuit', () {
    final CircuitNode gate = controller.addNode(
      ComponentType.orGate,
      const CanvasPoint(300, 150),
    );
    final CircuitNode secondInput = controller.addNode(
      ComponentType.inputPin,
      const CanvasPoint(100, 280),
    );
    controller.tapOutputPort('in-a');
    controller.tapInputPort(gate.id, 0);
    controller.tapOutputPort(secondInput.id);
    controller.tapInputPort(gate.id, 1);
    expect(controller.report.signalOf(gate.id), LogicSignal.low);

    controller.toggleInput('in-a');
    expect(controller.report.signalOf(gate.id), LogicSignal.high);
  });

  test('undo and redo restore previous graph states', () {
    controller.addNode(ComponentType.orGate, const CanvasPoint(320, 150));
    expect(controller.graph.nodes.length, 2);
    controller.undo();
    expect(controller.graph.nodes.length, 1);
    expect(controller.canRedo, isTrue);
    controller.redo();
    expect(controller.graph.nodes.length, 2);
  });

  test('deleting a component removes the wires attached to it', () {
    final CircuitNode gate = controller.addNode(
      ComponentType.andGate,
      const CanvasPoint(300, 150),
    );
    controller.tapOutputPort('in-a');
    controller.tapInputPort(gate.id, 0);
    expect(controller.graph.wires.length, 1);
    controller.selectNode(gate.id);
    controller.deleteSelected();
    expect(controller.graph.wires.length, 0);
    expect(controller.graph.nodes.length, 1);
  });

  test('duplicating a component creates an independent copy', () {
    final CircuitNode gate = controller.addNode(
      ComponentType.andGate,
      const CanvasPoint(300, 150),
    );
    controller.selectNode(gate.id);
    controller.duplicateSelected();
    expect(controller.graph.nodes.length, 3);
    expect(controller.graph.nodes.last.id, isNot(gate.id));
  });

  test('autosave writes the graph to the repository', () async {
    controller.addNode(ComponentType.xorGate, const CanvasPoint(320, 150));
    expect(controller.saveStatus, SaveStatus.unsaved);
    await controller.saveNow();
    expect(savedGraphs.length, 1);
    expect(savedGraphs.first.nodes.length, 2);
    expect(controller.saveStatus, SaveStatus.saved);
  });

  test('node properties are applied as a single undoable action', () {
    final CircuitNode gate = controller.addNode(
      ComponentType.andGate,
      const CanvasPoint(300, 150),
    );
    controller.selectNode(gate.id);
    controller.updateNodeProperties(gate.id, label: 'گیت من', inputCount: 3);
    final CircuitNode updated = controller.graph.nodeById(gate.id)!;
    expect(updated.label, 'گیت من');
    expect(updated.inputCount, 3);
    controller.undo();
    expect(controller.graph.nodeById(gate.id)!.inputCount, 2);
  });

  test('stepping the clock advances a sequential circuit', () {
    final CircuitNode clock = controller.addNode(
      ComponentType.clockSource,
      const CanvasPoint(120, 320),
    );
    final CircuitNode reset = controller.addNode(
      ComponentType.inputPin,
      const CanvasPoint(120, 420),
    );
    final CircuitNode counter = controller.addNode(
      ComponentType.counter4,
      const CanvasPoint(340, 300),
    );
    final CircuitNode probe = controller.addNode(
      ComponentType.outputPin,
      const CanvasPoint(560, 300),
    );
    controller.tapOutputPort(clock.id, 0);
    controller.tapInputPort(counter.id, 0);
    controller.tapOutputPort(reset.id, 0);
    controller.tapInputPort(counter.id, 1);
    controller.tapOutputPort(counter.id, 0);
    controller.tapInputPort(probe.id, 0);
    expect(
      controller.report.isValid,
      isTrue,
      reason: controller.report.problems.toString(),
    );
    expect(controller.hasSequentialParts, isTrue);

    controller.stepClock();
    expect(
      controller.report.signalOf(counter.id, 0).booleanValue,
      isTrue,
      reason: 'the counter must be 1 after one clock edge',
    );
    expect(controller.report.signalOf(probe.id).booleanValue, isTrue);

    controller.stepClock();
    expect(
      controller.report.signalOf(counter.id, 0).booleanValue,
      isFalse,
      reason: 'the counter must be 2 after two clock edges',
    );
    expect(controller.report.signalOf(counter.id, 1).booleanValue, isTrue);

    controller.resetSimulation();
    expect(
      controller.report.signalOf(counter.id, 0).booleanValue,
      isFalse,
      reason: 'reset clears the counter',
    );
  });
}
