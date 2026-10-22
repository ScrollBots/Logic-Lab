import 'package:flutter_test/flutter_test.dart';
import 'package:logic_lab/features/editor/application/circuit_editor_controller.dart';
import 'package:logic_lab/features/editor/domain/circuit_geometry.dart';
import 'package:logic_lab/features/editor/domain/circuit_models.dart';
import 'package:logic_lab/features/editor/domain/circuit_simulator.dart';
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

  test('a connection preserves the selected source output port', () {
    final CircuitNode decoder = controller.addNode(
      ComponentType.decoder2to4,
      const CanvasPoint(300, 150),
    );
    final CircuitNode output = controller.addNode(
      ComponentType.outputPin,
      const CanvasPoint(520, 150),
    );

    controller.tapOutputPort(decoder.id, 3);
    expect(controller.pendingSourcePort, 3);
    controller.tapInputPort(output.id, 0);

    expect(controller.graph.wires.single.fromPortIndex, 3);
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

  test('a no-op drag preserves redo history', () {
    controller.addNode(ComponentType.orGate, const CanvasPoint(320, 150));
    controller.undo();
    expect(controller.canRedo, isTrue);
    controller.beginNodeDrag('in-a');
    controller.endNodeDrag();
    expect(controller.canRedo, isTrue);
    expect(controller.canUndo, isFalse);
    controller.redo();
    expect(controller.graph.nodes.length, 2);
  });

  test('a drag creates one undo step and preserves attached wires', () {
    final CircuitNode gate = controller.addNode(
      ComponentType.andGate,
      const CanvasPoint(288, 144),
    );
    controller.tapOutputPort('in-a');
    controller.tapInputPort(gate.id, 0);
    final CircuitWire wire = controller.graph.wires.single;
    controller.beginNodeDrag(gate.id);
    controller.dragSelected(const CanvasPoint(24, 0));
    controller.dragSelected(const CanvasPoint(24, 0));
    controller.endNodeDrag();
    expect(controller.graph.nodeById(gate.id)!.position.x, 336);
    expect(controller.graph.wires.single, wire);
    controller.undo();
    expect(controller.graph.nodeById(gate.id)!.position.x, 288);
    expect(controller.graph.wires.single, wire);
    controller.redo();
    expect(controller.graph.nodeById(gate.id)!.position.x, 336);
    expect(controller.graph.wires.single, wire);
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

  test('a gate accepts every input count from two to eight', () {
    final CircuitNode gate = controller.addNode(
      ComponentType.andGate,
      const CanvasPoint(300, 150),
    );
    controller.selectNode(gate.id);
    controller.updateNodeProperties(gate.id, label: 'AND', inputCount: 8);
    expect(controller.graph.nodeById(gate.id)!.inputCount, 8);

    controller.updateInputCount(5);
    expect(controller.graph.nodeById(gate.id)!.inputCount, 5);

    controller.updateInputCount(12);
    expect(controller.graph.nodeById(gate.id)!.inputCount, 8);

    controller.updateInputCount(1);
    expect(controller.graph.nodeById(gate.id)!.inputCount, 2);
  });

  test('the model clamps the stored input count to the supported range', () {
    final CircuitNode tooMany = CircuitNode(
      id: 'wide',
      type: ComponentType.orGate,
      position: const CanvasPoint(0, 0),
      label: 'OR',
      inputCount: 20,
    );
    final CircuitNode tooFew = tooMany.copyWith(inputCount: 1);
    expect(tooMany.inputCount, 8);
    expect(tooFew.inputCount, 2);
  });

  test('shrinking a gate removes wires that point past the new inputs', () {
    final CircuitNode gate = controller.addNode(
      ComponentType.andGate,
      const CanvasPoint(300, 150),
    );
    controller.selectNode(gate.id);
    controller.updateInputCount(6);
    controller.tapOutputPort('in-a');
    controller.tapInputPort(gate.id, 5);
    expect(controller.graph.wires.length, 1);

    controller.selectNode(gate.id);
    controller.updateInputCount(4);
    expect(controller.graph.wires, isEmpty);
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

  test('dragging a component does not re-simulate the circuit', () {
    final CircuitNode gate = controller.addNode(
      ComponentType.andGate,
      const CanvasPoint(300, 150),
    );
    controller.tapOutputPort('in-a');
    controller.tapInputPort(gate.id, 0);
    final SimulationResult before = controller.report;

    controller.beginNodeDrag(gate.id);
    controller.dragSelected(const CanvasPoint(40, 25));
    expect(
      identical(controller.report, before),
      isTrue,
      reason: 'moving a component cannot change a signal',
    );
    expect(
      controller.graph.nodeById(gate.id)!.position.x,
      isNot(300),
      reason: 'the component follows the pointer',
    );

    controller.endNodeDrag();
    expect(
      identical(controller.report, before),
      isFalse,
      reason: 'dropping the component refreshes the simulation once',
    );
  });

  test('small drag deltas accumulate before snapping to the visible grid', () {
    final CircuitNode gate = controller.addNode(
      ComponentType.andGate,
      const CanvasPoint(288, 144),
    );

    controller.beginNodeDrag(gate.id);
    for (int i = 0; i < 4; i++) {
      controller.dragSelected(const CanvasPoint(4, 0));
    }

    final CircuitNode moved = controller.graph.nodeById(gate.id)!;
    expect(moved.position.x, 312);
    expect(moved.position.y, 144);
    expect(moved.position.x % CircuitGeometry.gridSize, 0);
    controller.endNodeDrag();
  });

  test('turning grid snap off preserves the accumulated scene delta', () {
    final CircuitNode gate = controller.addNode(
      ComponentType.andGate,
      const CanvasPoint(288, 144),
    );
    controller.setGridSnapEnabled(false);

    controller.beginNodeDrag(gate.id);
    controller.dragSelected(const CanvasPoint(3.5, 2.5));
    controller.dragSelected(const CanvasPoint(4.5, 1.5));

    final CircuitNode moved = controller.graph.nodeById(gate.id)!;
    expect(moved.position, const CanvasPoint(296, 148));
    controller.endNodeDrag();
  });

  test('feedback through a flip-flop is allowed in the editor', () {
    final CircuitNode clock = controller.addNode(
      ComponentType.clockSource,
      const CanvasPoint(120, 320),
    );
    final CircuitNode flipFlop = controller.addNode(
      ComponentType.dFlipFlop,
      const CanvasPoint(340, 200),
    );
    final CircuitNode inverter = controller.addNode(
      ComponentType.notGate,
      const CanvasPoint(340, 380),
    );
    final CircuitNode probe = controller.addNode(
      ComponentType.outputPin,
      const CanvasPoint(560, 200),
    );
    controller.tapOutputPort(clock.id, 0);
    controller.tapInputPort(flipFlop.id, 1);
    controller.tapOutputPort(flipFlop.id, 0);
    controller.tapInputPort(inverter.id, 0);
    // Closing the loop through the flip-flop is valid sequential feedback.
    controller.tapOutputPort(inverter.id, 0);
    controller.tapInputPort(flipFlop.id, 0);
    controller.tapOutputPort(flipFlop.id, 0);
    controller.tapInputPort(probe.id, 0);
    expect(controller.graph.wires.length, 4);
    expect(
      controller.feedback?.tone,
      EditorFeedbackTone.success,
      reason: controller.feedback?.message,
    );
    expect(
      controller.report.hasErrors,
      isFalse,
      reason: controller.report.problems.toString(),
    );

    controller.stepClock();
    expect(controller.report.signalOf(flipFlop.id, 0), LogicSignal.high);
    controller.stepClock();
    expect(controller.report.signalOf(flipFlop.id, 0), LogicSignal.low);
  });
}
