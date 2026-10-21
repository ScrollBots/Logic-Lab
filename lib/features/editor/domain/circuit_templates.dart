import '../../../core/utils/id_generator.dart';
import '../domain/circuit_models.dart';

/// Ready-made combinational circuits used by the lab and quick-start actions.
/// Every template is a real graph that the simulator can evaluate.
class CircuitTemplates {
  const CircuitTemplates._();

  static const List<CircuitTemplate> all = <CircuitTemplate>[
    CircuitTemplate(
      id: 'half_adder',
      title: 'نیم‌جمع‌کننده یک‌بیتی',
      description:
          'دو ورودی A و B را جمع می‌کند: خروجی S مجموع و خروجی C بابتِ حمل است.',
      level: 'متوسط',
      builder: _halfAdder,
    ),
    CircuitTemplate(
      id: 'full_adder',
      title: 'جمع‌کننده کامل',
      description:
          'سه ورودی A، B و Cin را جمع می‌کند و مجموع و بابت حمل را می‌دهد.',
      level: 'متوسط',
      builder: _fullAdder,
    ),
    CircuitTemplate(
      id: 'equality',
      title: 'مقایسه‌گر برابری',
      description:
          'با XNOR بررسی می‌کند که دو ورودی برابرند؛ خروجی ۱ یعنی برابر.',
      level: 'مقدماتی',
      builder: _equality,
    ),
    CircuitTemplate(
      id: 'mux2',
      title: 'مالتی‌پلکسر ۲ به ۱',
      description:
          'با انتخابگر S بین دو ورودی داده I0 و I1 یکی را به خروجی می‌برد.',
      level: 'متوسط',
      builder: _mux2,
    ),
    CircuitTemplate(
      id: 'decoder4',
      title: 'دیکودر ۲ به ۴',
      description: 'دو ورودی A و B را به چهار خروجی یک‌کاناله تبدیل می‌کند.',
      level: 'متوسط',
      builder: _decoder4,
    ),
    CircuitTemplate(
      id: 'd_flip_flop',
      title: 'فلیپ‌فلپ D',
      description:
          'با هر لبه بالارونده کلاک، مقدار D را در Q ذخیره می‌کند. برای دیدن نتیجه، پالس کلاک را بزنید.',
      level: 'ترتیبی',
      builder: _dFlipFlop,
    ),
    CircuitTemplate(
      id: 'counter4',
      title: 'شمارنده ۴ بیتی',
      description:
          'با هر پالس کلاک یک واحد اضافه می‌کند و چهار بیت خروجی می‌دهد.',
      level: 'ترتیبی',
      builder: _counter4,
    ),
  ];

  static CircuitGraph _halfAdder() {
    final CircuitNode a = _input('A', 90, 170);
    final CircuitNode b = _input('B', 90, 330);
    final CircuitNode xor = _gate(ComponentType.xorGate, 300, 200, 'XOR');
    final CircuitNode and = _gate(ComponentType.andGate, 300, 360, 'AND');
    final CircuitNode sum = _output('S', 540, 190);
    final CircuitNode carry = _output('C', 540, 360);
    return CircuitGraph(
      nodes: <CircuitNode>[a, b, xor, and, sum, carry],
      wires: <CircuitWire>[
        _wire(a, xor, 0),
        _wire(b, xor, 1),
        _wire(a, and, 0),
        _wire(b, and, 1),
        _wire(xor, sum, 0),
        _wire(and, carry, 0),
      ],
    );
  }

  static CircuitGraph _equality() {
    final CircuitNode a = _input('A', 90, 210);
    final CircuitNode b = _input('B', 90, 350);
    final CircuitNode xnor = _gate(ComponentType.xnorGate, 320, 280, 'XNOR');
    final CircuitNode out = _output('EQ', 560, 280);
    return CircuitGraph(
      nodes: <CircuitNode>[a, b, xnor, out],
      wires: <CircuitWire>[
        _wire(a, xnor, 0),
        _wire(b, xnor, 1),
        _wire(xnor, out, 0),
      ],
    );
  }

  static CircuitGraph _mux2() {
    final CircuitNode i0 = _input('I0', 70, 140);
    final CircuitNode i1 = _input('I1', 70, 280);
    final CircuitNode s = _input('S', 70, 420);
    final CircuitNode notS = _gate(ComponentType.notGate, 260, 420, 'NOT');
    final CircuitNode and0 = _gate(ComponentType.andGate, 430, 150, 'AND');
    final CircuitNode and1 = _gate(ComponentType.andGate, 430, 310, 'AND');
    final CircuitNode or = _gate(ComponentType.orGate, 620, 230, 'OR');
    final CircuitNode out = _output('Y', 800, 230);
    return CircuitGraph(
      nodes: <CircuitNode>[i0, i1, s, notS, and0, and1, or, out],
      wires: <CircuitWire>[
        _wire(i0, and0, 0),
        _wire(s, and0, 1),
        _wire(i1, and1, 0),
        _wire(notS, and1, 1),
        _wire(s, notS, 0),
        _wire(and0, or, 0),
        _wire(and1, or, 1),
        _wire(or, out, 0),
      ],
    );
  }

  static CircuitGraph _fullAdder() {
    final CircuitNode a = _input('A', 70, 140);
    final CircuitNode b = _input('B', 70, 270);
    final CircuitNode cin = _input('Cin', 70, 400);
    final CircuitNode xor1 = _gate(ComponentType.xorGate, 250, 200, 'XOR');
    final CircuitNode and1 = _gate(ComponentType.andGate, 250, 330, 'AND');
    final CircuitNode xor2 = _gate(ComponentType.xorGate, 440, 180, 'XOR');
    final CircuitNode and2 = _gate(ComponentType.andGate, 440, 330, 'AND');
    final CircuitNode or = _gate(ComponentType.orGate, 620, 260, 'OR');
    final CircuitNode sum = _output('S', 800, 170);
    final CircuitNode carry = _output('C', 800, 350);
    return CircuitGraph(
      nodes: <CircuitNode>[a, b, cin, xor1, and1, xor2, and2, or, sum, carry],
      wires: <CircuitWire>[
        _wire(a, xor1, 0),
        _wire(b, xor1, 1),
        _wire(a, and1, 0),
        _wire(b, and1, 1),
        _wire(xor1, xor2, 0),
        _wire(cin, xor2, 1),
        _wire(xor1, and2, 0),
        _wire(cin, and2, 1),
        _wire(and1, or, 0),
        _wire(and2, or, 1),
        _wire(xor2, sum, 0),
        _wire(or, carry, 0),
      ],
    );
  }

  static CircuitGraph _decoder4() {
    final CircuitNode a = _input('A', 90, 200);
    final CircuitNode b = _input('B', 90, 330);
    final CircuitNode decoder = _module(
      ComponentType.decoder2to4,
      330,
      265,
      'DEC4',
    );
    final List<CircuitNode> outputs = <CircuitNode>[
      _output('Y0', 600, 160),
      _output('Y1', 600, 250),
      _output('Y2', 600, 340),
      _output('Y3', 600, 430),
    ];
    final List<CircuitWire> wires = <CircuitWire>[
      _wire(a, decoder, 0),
      _wire(b, decoder, 1),
    ];
    for (int i = 0; i < outputs.length; i++) {
      wires.add(_wire(decoder, outputs[i], 0, fromPort: i));
    }
    return CircuitGraph(
      nodes: <CircuitNode>[a, b, decoder, ...outputs],
      wires: wires,
    );
  }

  static CircuitGraph _dFlipFlop() {
    final CircuitNode data = _input('D', 90, 220);
    final CircuitNode clock = CircuitNode(
      id: IdGenerator.next('clk'),
      type: ComponentType.clockSource,
      position: const CanvasPoint(90, 360),
      label: 'CLK',
    );
    final CircuitNode flipFlop = _module(
      ComponentType.dFlipFlop,
      330,
      270,
      'DFF',
    );
    final CircuitNode q = _output('Q', 580, 240);
    final CircuitNode qBar = _output('Q̅', 580, 330);
    return CircuitGraph(
      nodes: <CircuitNode>[data, clock, flipFlop, q, qBar],
      wires: <CircuitWire>[
        _wire(data, flipFlop, 0),
        _wire(clock, flipFlop, 1),
        _wire(flipFlop, q, 0),
        _wire(flipFlop, qBar, 0, fromPort: 1),
      ],
    );
  }

  static CircuitGraph _counter4() {
    final CircuitNode clock = CircuitNode(
      id: IdGenerator.next('clk'),
      type: ComponentType.clockSource,
      position: const CanvasPoint(90, 200),
      label: 'CLK',
    );
    final CircuitNode reset = _input('RST', 90, 330);
    final CircuitNode counter = _module(
      ComponentType.counter4,
      330,
      260,
      'CNT4',
    );
    final List<CircuitNode> outputs = <CircuitNode>[
      _output('Q0', 580, 160),
      _output('Q1', 580, 250),
      _output('Q2', 580, 340),
      _output('Q3', 580, 430),
    ];
    final List<CircuitWire> wires = <CircuitWire>[
      _wire(clock, counter, 0),
      _wire(reset, counter, 1),
    ];
    for (int i = 0; i < outputs.length; i++) {
      wires.add(_wire(counter, outputs[i], 0, fromPort: i));
    }
    return CircuitGraph(
      nodes: <CircuitNode>[clock, reset, counter, ...outputs],
      wires: wires,
    );
  }

  static CircuitNode _input(String label, double x, double y) {
    return CircuitNode(
      id: IdGenerator.next('in'),
      type: ComponentType.inputPin,
      position: CanvasPoint(x, y),
      label: label,
    );
  }

  static CircuitNode _output(String label, double x, double y) {
    return CircuitNode(
      id: IdGenerator.next('out'),
      type: ComponentType.outputPin,
      position: CanvasPoint(x, y),
      label: label,
    );
  }

  static CircuitNode _module(
    ComponentType type,
    double x,
    double y,
    String label,
  ) {
    return CircuitNode(
      id: IdGenerator.next('m'),
      type: type,
      position: CanvasPoint(x, y),
      label: label,
    );
  }

  static CircuitNode _gate(
    ComponentType type,
    double x,
    double y,
    String label,
  ) {
    return CircuitNode(
      id: IdGenerator.next('g'),
      type: type,
      position: CanvasPoint(x, y),
      label: label,
      inputCount: type == ComponentType.notGate ? 1 : 2,
    );
  }

  static CircuitWire _wire(
    CircuitNode from,
    CircuitNode to,
    int inputIndex, {
    int fromPort = 0,
  }) {
    return CircuitWire(
      id: IdGenerator.next('w'),
      fromNodeId: from.id,
      toNodeId: to.id,
      toInputIndex: inputIndex,
      fromPortIndex: fromPort,
    );
  }
}

class CircuitTemplate {
  const CircuitTemplate({
    required this.id,
    required this.title,
    required this.description,
    required this.level,
    required this.builder,
  });

  final String id;
  final String title;
  final String description;
  final String level;
  final CircuitGraph Function() builder;
}
