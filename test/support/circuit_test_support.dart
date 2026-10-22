import 'package:logic_lab/features/editor/domain/circuit_models.dart';

/// Small helper for building circuits inside tests.
class CircuitBuilder {
  CircuitBuilder();

  final List<CircuitNode> nodes = <CircuitNode>[];
  final List<CircuitWire> wires = <CircuitWire>[];
  int _counter = 0;

  String _nextId(String prefix) => '$prefix${_counter++}';

  CircuitNode add(
    ComponentType type, {
    String? label,
    bool value = false,
    int? inputs,
    double x = 0,
    double y = 0,
  }) {
    final CircuitNode node = CircuitNode(
      id: _nextId(type.jsonName),
      type: type,
      position: CanvasPoint(x, y),
      label: label ?? type.technicalName,
      inputValue: value,
      inputCount: inputs,
    );
    nodes.add(node);
    return node;
  }

  void connect(
    CircuitNode from,
    CircuitNode to, {
    int toPort = 0,
    int fromPort = 0,
  }) {
    wires.add(
      CircuitWire(
        id: _nextId('w'),
        fromNodeId: from.id,
        toNodeId: to.id,
        toInputIndex: toPort,
        fromPortIndex: fromPort,
      ),
    );
  }

  CircuitGraph build() => CircuitGraph(nodes: nodes, wires: wires);
}

/// Reference truth table of a basic gate, written independently from the
/// component specification so the tests really cross-check the simulator.
class GateReference {
  const GateReference._();

  static bool apply(ComponentType type, List<bool> inputs) {
    switch (type) {
      case ComponentType.andGate:
        return inputs.every((bool bit) => bit);
      case ComponentType.orGate:
        return inputs.any((bool bit) => bit);
      case ComponentType.notGate:
        return !inputs.first;
      case ComponentType.nandGate:
        return !inputs.every((bool bit) => bit);
      case ComponentType.norGate:
        return !inputs.any((bool bit) => bit);
      case ComponentType.xorGate:
        return inputs.where((bool bit) => bit).length.isOdd;
      case ComponentType.xnorGate:
        return inputs.where((bool bit) => bit).length.isEven;
      case ComponentType.bufferGate:
        return inputs.first;
      case ComponentType.aoi21:
        return !((inputs[0] && inputs[1]) || inputs[2]);
      case ComponentType.aoi22:
        return !((inputs[0] && inputs[1]) || (inputs[2] && inputs[3]));
      case ComponentType.oai21:
        return !((inputs[0] || inputs[1]) && inputs[2]);
      case ComponentType.oai22:
        return !((inputs[0] || inputs[1]) && (inputs[2] || inputs[3]));
      default:
        throw ArgumentError('no reference for ${type.jsonName}');
    }
  }
}

/// Reference behaviour of the arithmetic modules.
class ArithmeticReference {
  const ArithmeticReference._();

  static List<bool> halfAdder(bool a, bool b) => <bool>[a ^ b, a && b];

  static List<bool> fullAdder(bool a, bool b, bool carryIn) {
    final bool sum = a ^ b ^ carryIn;
    final bool carry = (a && b) || (a && carryIn) || (b && carryIn);
    return <bool>[sum, carry];
  }

  static List<bool> halfSubtractor(bool a, bool b) => <bool>[a ^ b, !a && b];

  static List<bool> fullSubtractor(bool a, bool b, bool borrowIn) {
    final bool difference = a ^ b ^ borrowIn;
    final bool borrow = (!a && b) || (!a && borrowIn) || (b && borrowIn);
    return <bool>[difference, borrow];
  }

  /// 2-bit magnitude comparator: [less, equal, greater].
  static List<bool> comparator(int a, int b) => <bool>[a < b, a == b, a > b];
}

/// Reference behaviour of the selection and coding modules.
class SelectionReference {
  const SelectionReference._();

  static bool mux2(bool i0, bool i1, bool select) => select ? i1 : i0;

  static bool mux4(bool i0, bool i1, bool i2, bool i3, bool s1, bool s0) {
    final int index = (s1 ? 2 : 0) + (s0 ? 1 : 0);
    return <bool>[i0, i1, i2, i3][index];
  }

  static List<bool> demux2(bool data, bool select) =>
      select ? <bool>[false, data] : <bool>[data, false];

  static List<bool> demux4(bool data, bool s1, bool s0) {
    final int index = (s1 ? 2 : 0) + (s0 ? 1 : 0);
    return List<bool>.generate(4, (int i) => i == index && data);
  }

  static List<bool> decoder4(bool a, bool b) {
    final int index = (a ? 2 : 0) + (b ? 1 : 0);
    return List<bool>.generate(4, (int i) => i == index);
  }

  static List<bool> decoder8(bool a, bool b, bool c) {
    final int index = (a ? 4 : 0) + (b ? 2 : 0) + (c ? 1 : 0);
    return List<bool>.generate(8, (int i) => i == index);
  }

  /// 4-to-2 encoder: the outputs follow the classic OR encoding.
  static List<bool> encoder4(bool d0, bool d1, bool d2, bool d3) => <bool>[
    d2 || d3,
    d1 || d3,
  ];

  /// 8-to-3 encoder: the highest active input wins.
  static List<bool> encoder8(List<bool> inputs) {
    int index = 0;
    for (int i = 0; i < inputs.length; i++) {
      if (inputs[i]) {
        index = i;
      }
    }
    return <bool>[index & 0x4 != 0, index & 0x2 != 0, index & 0x1 != 0];
  }

  /// Priority encoder: the highest active input wins, V reports "any active".
  static List<bool> priorityEncoder(List<bool> inputs) {
    int index = 0;
    bool any = false;
    for (int i = 0; i < inputs.length; i++) {
      if (inputs[i]) {
        index = i;
        any = true;
      }
    }
    return <bool>[index & 0x4 != 0, index & 0x2 != 0, index & 0x1 != 0, any];
  }
}
