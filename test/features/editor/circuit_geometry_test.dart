import 'package:flutter_test/flutter_test.dart';
import 'package:logic_lab/features/editor/domain/circuit_geometry.dart';
import 'package:logic_lab/features/editor/domain/circuit_models.dart';

CircuitNode _gate(ComponentType type, int inputCount) {
  return CircuitNode(
    id: 'g',
    type: type,
    position: const CanvasPoint(0, 0),
    label: type.technicalName,
    inputCount: inputCount,
  );
}

void main() {
  test('an eight input gate grows tall enough to contain its ports', () {
    final CircuitNode gate = _gate(ComponentType.andGate, 8);
    final CanvasRect bounds = CircuitGeometry.nodeBounds(gate);
    final double firstPort = CircuitGeometry.inputPortY(gate, 0);
    final double lastPort = CircuitGeometry.inputPortY(gate, 7);

    expect(
      CircuitGeometry.heightOf(gate),
      greaterThan(CircuitGeometry.nodeHeight),
    );
    expect(firstPort, greaterThanOrEqualTo(bounds.top));
    expect(lastPort, lessThanOrEqualTo(bounds.bottom));
    expect(
      CircuitGeometry.portPosition(gate, CircuitPin.input(gate.id, 7)),
      isNotNull,
    );
  });

  test('gates with up to four inputs keep the compact body', () {
    for (final int count in <int>[2, 3, 4]) {
      expect(
        CircuitGeometry.heightOf(_gate(ComponentType.orGate, count)),
        CircuitGeometry.nodeHeight,
        reason: 'a $count input gate fits in the default body',
      );
    }
  });

  test('hit testing selects the nearest pin in overlapping touch targets', () {
    final CircuitNode gate = _gate(ComponentType.andGate, 8);
    final CircuitGraph graph = CircuitGraph(nodes: <CircuitNode>[gate]);
    final CanvasPoint port = CircuitGeometry.portPosition(
      gate,
      CircuitPin.input(gate.id, 3),
    )!;
    final CircuitPin? closest = CircuitGeometry.portAt(
      graph,
      port.translate(2, 1),
      radius: 64,
    );
    expect(closest?.isInput, isTrue);
    expect(closest?.index, 3);
    expect(
      CircuitGeometry.portAt(graph, port, radius: 22, outputOnly: true),
      isNull,
    );
    final CanvasPoint output = CircuitGeometry.portPosition(
      gate,
      CircuitPin.output(gate.id, 0),
    )!;
    expect(CircuitGeometry.portAt(graph, output, inputOnly: true), isNull);
  });

  test('a tall gate never shrinks below the default body height', () {
    expect(
      CircuitGeometry.heightOf(_gate(ComponentType.nandGate, 5)),
      greaterThanOrEqualTo(CircuitGeometry.nodeHeight),
    );
  });
}
