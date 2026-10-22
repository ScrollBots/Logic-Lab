import 'component_type.dart';

/// The kind of a component, which decides how it is drawn and evaluated.
enum ComponentKind {
  /// A user switch that drives a signal.
  input,

  /// A read-only probe that displays a signal.
  output,

  /// A classic single-output gate drawn with the conventional symbol.
  gate,

  /// A compound module drawn as a labelled block with named ports.
  module,

  /// A stateful element (latch, flip-flop, register, counter).
  sequential,

  /// The clock generator.
  clock,

  /// A component type that this build does not understand.
  unsupported,
}

/// Runtime state of a sequential component.
///
/// The stored values are three-valued: a flip-flop that captured an unknown
/// data input must remember that the output is unknown as well, instead of
/// silently turning it into a zero.
class ComponentState {
  const ComponentState({
    this.q = LogicSignal.low,
    this.qBar = LogicSignal.high,
    this.prevClock = false,
    this.bits = const <LogicSignal>[],
    this.initialized = false,
  });

  /// Latch / flip-flop output.
  final LogicSignal q;

  /// Complementary latch / flip-flop output.
  final LogicSignal qBar;

  /// Clock level seen during the previous evaluation (for edge detection).
  final bool prevClock;

  /// Bit vector used by registers, shift registers and counters.
  final List<LogicSignal> bits;

  /// True once the component has captured a value.
  final bool initialized;

  ComponentState copyWith({
    LogicSignal? q,
    LogicSignal? qBar,
    bool? prevClock,
    List<LogicSignal>? bits,
    bool? initialized,
  }) {
    return ComponentState(
      q: q ?? this.q,
      qBar: qBar ?? this.qBar,
      prevClock: prevClock ?? this.prevClock,
      bits: bits ?? this.bits,
      initialized: initialized ?? this.initialized,
    );
  }

  /// Value equality, used to detect that the state has settled.
  bool sameAs(ComponentState other) {
    if (q != other.q || qBar != other.qBar || prevClock != other.prevClock) {
      return false;
    }
    if (bits.length != other.bits.length) {
      return false;
    }
    for (int i = 0; i < bits.length; i++) {
      if (bits[i] != other.bits[i]) {
        return false;
      }
    }
    return true;
  }
}

/// Evaluates a component and returns one signal per output port.
typedef ModuleEvaluator =
    List<LogicSignal> Function(List<LogicSignal> inputs, ComponentState state);

/// Updates the state of a level-sensitive component while it is enabled.
typedef LatchUpdater =
    ComponentState Function(List<LogicSignal> inputs, ComponentState state);

/// Updates the state of an edge-triggered component on a rising clock edge.
typedef EdgeUpdater =
    ComponentState Function(List<LogicSignal> inputs, ComponentState state);

/// Complete description of one component type.
class ComponentSpec {
  const ComponentSpec({
    required this.type,
    required this.kind,
    required this.title,
    required this.description,
    this.inputLabels = const <String>[],
    this.outputLabels = const <String>['Y'],
    this.minInputs = 0,
    this.maxInputs = 0,
    this.configurableInputs = false,
    this.usesClock = false,
    this.tristate = false,
    this.evaluator,
    this.latchUpdater,
    this.edgeUpdater,
    this.initialState,
  });

  final ComponentType type;
  final ComponentKind kind;

  /// Persian display name.
  final String title;

  /// Short Persian explanation shown in the component library.
  final String description;

  /// Labels of the input ports (left to right in schematic convention).
  final List<String> inputLabels;

  /// Labels of the output ports.
  final List<String> outputLabels;

  /// Configurable input count range for gates such as AND/OR.
  final int minInputs;
  final int maxInputs;
  final bool configurableInputs;

  final bool usesClock;
  final bool tristate;

  final ModuleEvaluator? evaluator;
  final LatchUpdater? latchUpdater;
  final EdgeUpdater? edgeUpdater;
  final ComponentState Function()? initialState;

  int get fixedInputCount => inputLabels.length;

  bool get isStateful => latchUpdater != null || edgeUpdater != null;
}

// ---------------------------------------------------------------------------
// Three-valued logic helpers
// ---------------------------------------------------------------------------

LogicSignal notSignal(LogicSignal value) {
  return switch (value) {
    LogicSignal.low => LogicSignal.high,
    LogicSignal.high => LogicSignal.low,
    LogicSignal.unknown => LogicSignal.unknown,
    LogicSignal.highImpedance => LogicSignal.unknown,
  };
}

/// AND with proper three-valued behaviour: a single LOW dominates.
LogicSignal andAll(List<LogicSignal> values) {
  if (values.isEmpty) {
    return LogicSignal.high;
  }
  bool unknown = false;
  for (final LogicSignal value in values) {
    if (value == LogicSignal.low) {
      return LogicSignal.low;
    }
    if (value != LogicSignal.high) {
      unknown = true;
    }
  }
  return unknown ? LogicSignal.unknown : LogicSignal.high;
}

/// OR with proper three-valued behaviour: a single HIGH dominates.
LogicSignal orAll(List<LogicSignal> values) {
  if (values.isEmpty) {
    return LogicSignal.low;
  }
  bool unknown = false;
  for (final LogicSignal value in values) {
    if (value == LogicSignal.high) {
      return LogicSignal.high;
    }
    if (value != LogicSignal.low) {
      unknown = true;
    }
  }
  return unknown ? LogicSignal.unknown : LogicSignal.low;
}

/// XOR (parity). Unknown inputs produce an unknown result.
LogicSignal xorAll(List<LogicSignal> values) {
  bool? parity;
  for (final LogicSignal value in values) {
    if (value != LogicSignal.high && value != LogicSignal.low) {
      return LogicSignal.unknown;
    }
    parity = (parity ?? false) ^ (value == LogicSignal.high);
  }
  return parity == true ? LogicSignal.high : LogicSignal.low;
}

LogicSignal _bool(bool value) => value ? LogicSignal.high : LogicSignal.low;

/// Subtracts two bit vectors, returning [difference, borrow].
List<LogicSignal> _subtractBits(List<LogicSignal> a, List<LogicSignal> b) {
  LogicSignal borrow = LogicSignal.low;
  final List<LogicSignal> result = <LogicSignal>[];
  for (int i = 0; i < a.length; i++) {
    final LogicSignal bitA = a[i];
    final LogicSignal bitB = b[i];
    final LogicSignal difference = xorAll(<LogicSignal>[bitA, bitB, borrow]);
    borrow = orAll(<LogicSignal>[
      andAll(<LogicSignal>[notSignal(bitA), bitB]),
      andAll(<LogicSignal>[notSignal(bitA), borrow]),
      andAll(<LogicSignal>[bitB, borrow]),
    ]);
    result.add(difference);
  }
  return <LogicSignal>[...result, borrow];
}

/// Selects one of two data inputs with a select line.
LogicSignal _mux2(LogicSignal i0, LogicSignal i1, LogicSignal select) {
  if (select == LogicSignal.low) {
    return i0;
  }
  if (select == LogicSignal.high) {
    return i1;
  }
  return LogicSignal.unknown;
}

// ---------------------------------------------------------------------------
// Component registry
// ---------------------------------------------------------------------------

class ComponentLibrary {
  const ComponentLibrary._();

  static const Map<ComponentType, ComponentSpec> _specs =
      <ComponentType, ComponentSpec>{
        ComponentType.inputPin: ComponentSpec(
          type: ComponentType.inputPin,
          kind: ComponentKind.input,
          title: 'ورودی',
          description: 'کلید دوحالته با مقدار اولیه',
          inputLabels: <String>[],
          outputLabels: <String>['OUT'],
        ),
        ComponentType.outputPin: ComponentSpec(
          type: ComponentType.outputPin,
          kind: ComponentKind.output,
          title: 'خروجی',
          description: 'نمایش نتیجه سیگنال',
          inputLabels: <String>['IN'],
          outputLabels: <String>['Y'],
        ),
        ComponentType.clockSource: ComponentSpec(
          type: ComponentType.clockSource,
          kind: ComponentKind.clock,
          title: 'کلاک',
          description: 'تولید پالس کلاک برای مدارهای ترتیبی',
          inputLabels: <String>[],
          outputLabels: <String>['CLK'],
        ),
        ComponentType.unknown: ComponentSpec(
          type: ComponentType.unknown,
          kind: ComponentKind.unsupported,
          title: 'قطعه پشتیبانی‌نشده',
          description: 'این نوع قطعه در این نسخه پشتیبانی نمی‌شود',
          inputLabels: <String>['IN'],
          outputLabels: <String>['Y'],
        ),
      };

  /// Basic gates that are drawn with the conventional schematic symbol.
  static const List<ComponentType> basicGates = <ComponentType>[
    ComponentType.andGate,
    ComponentType.orGate,
    ComponentType.notGate,
    ComponentType.nandGate,
    ComponentType.norGate,
    ComponentType.xorGate,
    ComponentType.xnorGate,
    ComponentType.bufferGate,
    ComponentType.triStateBuffer,
  ];

  /// Compound gates with more than one logical function inside.
  static const List<ComponentType> compoundGates = <ComponentType>[
    ComponentType.aoi21,
    ComponentType.aoi22,
    ComponentType.oai21,
    ComponentType.oai22,
  ];

  /// Arithmetic modules.
  static const List<ComponentType> arithmeticModules = <ComponentType>[
    ComponentType.halfAdder,
    ComponentType.fullAdder,
    ComponentType.halfSubtractor,
    ComponentType.fullSubtractor,
    ComponentType.comparator,
  ];

  /// Selection and coding modules.
  static const List<ComponentType> selectionModules = <ComponentType>[
    ComponentType.mux2,
    ComponentType.mux4,
    ComponentType.demux1to2,
    ComponentType.demux1to4,
    ComponentType.decoder2to4,
    ComponentType.decoder3to8,
    ComponentType.encoder4to2,
    ComponentType.encoder8to3,
    ComponentType.priorityEncoder,
  ];

  /// Sequential elements.
  static const List<ComponentType> sequentialComponents = <ComponentType>[
    ComponentType.srLatch,
    ComponentType.gatedSrLatch,
    ComponentType.dLatch,
    ComponentType.dFlipFlop,
    ComponentType.tFlipFlop,
    ComponentType.jkFlipFlop,
    ComponentType.register4,
    ComponentType.shiftRegister4,
    ComponentType.counter4,
    ComponentType.upDownCounter4,
  ];

  static ComponentSpec specOf(ComponentType type) {
    final ComponentSpec? known = _specs[type];
    if (known != null) {
      return known;
    }
    return _dynamicSpec(type);
  }

  static ComponentSpec _dynamicSpec(ComponentType type) {
    switch (type) {
      case ComponentType.andGate:
      case ComponentType.orGate:
      case ComponentType.nandGate:
      case ComponentType.norGate:
      case ComponentType.xorGate:
      case ComponentType.xnorGate:
        return ComponentSpec(
          type: type,
          kind: ComponentKind.gate,
          title: type.persianName,
          description: type.description,
          outputLabels: <String>['Y'],
          minInputs: 2,
          maxInputs: 8,
          configurableInputs: true,
          evaluator: _gateEvaluator(type),
        );
      case ComponentType.notGate:
        return const ComponentSpec(
          type: ComponentType.notGate,
          kind: ComponentKind.gate,
          title: 'دروازه NOT',
          description: 'معکوس‌کننده تک‌ورودی',
          inputLabels: <String>['A'],
          outputLabels: <String>['Y'],
          minInputs: 1,
          maxInputs: 1,
          evaluator: _notEvaluator,
        );
      case ComponentType.bufferGate:
        return const ComponentSpec(
          type: ComponentType.bufferGate,
          kind: ComponentKind.gate,
          title: 'بافر',
          description: 'سیگنال را بدون تغییر منتقل می‌کند',
          inputLabels: <String>['A'],
          outputLabels: <String>['Y'],
          minInputs: 1,
          maxInputs: 1,
          evaluator: _bufferEvaluator,
        );
      case ComponentType.triStateBuffer:
        return const ComponentSpec(
          type: ComponentType.triStateBuffer,
          kind: ComponentKind.gate,
          title: 'بافر سه‌حالته',
          description:
              'با فعال شدن EN خروجی را می‌راند و در غیر این صورت حالت Z می‌گیرد',
          inputLabels: <String>['A', 'EN'],
          outputLabels: <String>['Y'],
          minInputs: 2,
          maxInputs: 2,
          tristate: true,
          evaluator: _triStateEvaluator,
        );
      case ComponentType.aoi21:
        return const ComponentSpec(
          type: ComponentType.aoi21,
          kind: ComponentKind.module,
          title: 'AOI21',
          description: 'Y = ¬((A ∧ B) ∨ C)',
          inputLabels: <String>['A', 'B', 'C'],
          outputLabels: <String>['Y'],
          minInputs: 3,
          maxInputs: 3,
          evaluator: _aoi21Evaluator,
        );
      case ComponentType.aoi22:
        return const ComponentSpec(
          type: ComponentType.aoi22,
          kind: ComponentKind.module,
          title: 'AOI22',
          description: 'Y = ¬((A ∧ B) ∨ (C ∧ D))',
          inputLabels: <String>['A', 'B', 'C', 'D'],
          outputLabels: <String>['Y'],
          minInputs: 4,
          maxInputs: 4,
          evaluator: _aoi22Evaluator,
        );
      case ComponentType.oai21:
        return const ComponentSpec(
          type: ComponentType.oai21,
          kind: ComponentKind.module,
          title: 'OAI21',
          description: 'Y = ¬((A ∨ B) ∧ C)',
          inputLabels: <String>['A', 'B', 'C'],
          outputLabels: <String>['Y'],
          minInputs: 3,
          maxInputs: 3,
          evaluator: _oai21Evaluator,
        );
      case ComponentType.oai22:
        return const ComponentSpec(
          type: ComponentType.oai22,
          kind: ComponentKind.module,
          title: 'OAI22',
          description: 'Y = ¬((A ∨ B) ∧ (C ∨ D))',
          inputLabels: <String>['A', 'B', 'C', 'D'],
          outputLabels: <String>['Y'],
          minInputs: 4,
          maxInputs: 4,
          evaluator: _oai22Evaluator,
        );
      case ComponentType.halfAdder:
        return const ComponentSpec(
          type: ComponentType.halfAdder,
          kind: ComponentKind.module,
          title: 'نیم‌جمع‌کننده',
          description: 'S = A ⊕ B و C = A ∧ B',
          inputLabels: <String>['A', 'B'],
          outputLabels: <String>['S', 'C'],
          minInputs: 2,
          maxInputs: 2,
          evaluator: _halfAdderEvaluator,
        );
      case ComponentType.fullAdder:
        return const ComponentSpec(
          type: ComponentType.fullAdder,
          kind: ComponentKind.module,
          title: 'جمع‌کننده کامل',
          description: 'S = A ⊕ B ⊕ Cin و Cout با بابت حمل',
          inputLabels: <String>['A', 'B', 'Cin'],
          outputLabels: <String>['S', 'Cout'],
          minInputs: 3,
          maxInputs: 3,
          evaluator: _fullAdderEvaluator,
        );
      case ComponentType.halfSubtractor:
        return const ComponentSpec(
          type: ComponentType.halfSubtractor,
          kind: ComponentKind.module,
          title: 'نیم‌تفریق‌کننده',
          description: 'D = A ⊕ B و Br = ¬A ∧ B',
          inputLabels: <String>['A', 'B'],
          outputLabels: <String>['D', 'Br'],
          minInputs: 2,
          maxInputs: 2,
          evaluator: _halfSubtractorEvaluator,
        );
      case ComponentType.fullSubtractor:
        return const ComponentSpec(
          type: ComponentType.fullSubtractor,
          kind: ComponentKind.module,
          title: 'تفریق‌کننده کامل',
          description: 'D = A − B − Bin با بابت قرض',
          inputLabels: <String>['A', 'B', 'Bin'],
          outputLabels: <String>['D', 'Bout'],
          minInputs: 3,
          maxInputs: 3,
          evaluator: _fullSubtractorEvaluator,
        );
      case ComponentType.comparator:
        return const ComponentSpec(
          type: ComponentType.comparator,
          kind: ComponentKind.module,
          title: 'مقایسه‌گر دوبیتی',
          description: 'مقایسه A و B و تولید LT، EQ و GT',
          inputLabels: <String>['A1', 'A0', 'B1', 'B0'],
          outputLabels: <String>['LT', 'EQ', 'GT'],
          minInputs: 4,
          maxInputs: 4,
          evaluator: _comparatorEvaluator,
        );
      case ComponentType.mux2:
        return const ComponentSpec(
          type: ComponentType.mux2,
          kind: ComponentKind.module,
          title: 'مالتی‌پلکسر ۲ به ۱',
          description: 'Y = S ? I1 : I0',
          inputLabels: <String>['I0', 'I1', 'S'],
          outputLabels: <String>['Y'],
          minInputs: 3,
          maxInputs: 3,
          evaluator: _mux2Evaluator,
        );
      case ComponentType.mux4:
        return const ComponentSpec(
          type: ComponentType.mux4,
          kind: ComponentKind.module,
          title: 'مالتی‌پلکسر ۴ به ۱',
          description: 'انتخاب یکی از چهار ورودی با S1 و S0',
          inputLabels: <String>['I0', 'I1', 'I2', 'I3', 'S1', 'S0'],
          outputLabels: <String>['Y'],
          minInputs: 6,
          maxInputs: 6,
          evaluator: _mux4Evaluator,
        );
      case ComponentType.demux1to2:
        return const ComponentSpec(
          type: ComponentType.demux1to2,
          kind: ComponentKind.module,
          title: 'دیمالتی‌پلکسر ۱ به ۲',
          description: 'هدایت D به یکی از دو خروجی با S',
          inputLabels: <String>['D', 'S'],
          outputLabels: <String>['Y0', 'Y1'],
          minInputs: 2,
          maxInputs: 2,
          evaluator: _demux2Evaluator,
        );
      case ComponentType.demux1to4:
        return const ComponentSpec(
          type: ComponentType.demux1to4,
          kind: ComponentKind.module,
          title: 'دیمالتی‌پلکسر ۱ به ۴',
          description: 'هدایت D به یکی از چهار خروجی با S1 و S0',
          inputLabels: <String>['D', 'S1', 'S0'],
          outputLabels: <String>['Y0', 'Y1', 'Y2', 'Y3'],
          minInputs: 3,
          maxInputs: 3,
          evaluator: _demux4Evaluator,
        );
      case ComponentType.decoder2to4:
        return const ComponentSpec(
          type: ComponentType.decoder2to4,
          kind: ComponentKind.module,
          title: 'دیکودر ۲ به ۴',
          description: 'تنها یکی از چهار خروجی فعال می‌شود',
          inputLabels: <String>['A', 'B'],
          outputLabels: <String>['Y0', 'Y1', 'Y2', 'Y3'],
          minInputs: 2,
          maxInputs: 2,
          evaluator: _decoder4Evaluator,
        );
      case ComponentType.decoder3to8:
        return const ComponentSpec(
          type: ComponentType.decoder3to8,
          kind: ComponentKind.module,
          title: 'دیکودر ۳ به ۸',
          description: 'تنها یکی از هشت خروجی فعال می‌شود',
          inputLabels: <String>['A', 'B', 'C'],
          outputLabels: <String>[
            'Y0',
            'Y1',
            'Y2',
            'Y3',
            'Y4',
            'Y5',
            'Y6',
            'Y7',
          ],
          minInputs: 3,
          maxInputs: 3,
          evaluator: _decoder8Evaluator,
        );
      case ComponentType.encoder4to2:
        return const ComponentSpec(
          type: ComponentType.encoder4to2,
          kind: ComponentKind.module,
          title: 'انکودر ۴ به ۲',
          description: 'کد دودویی ورودی فعال را تولید می‌کند',
          inputLabels: <String>['D0', 'D1', 'D2', 'D3'],
          outputLabels: <String>['Y1', 'Y0'],
          minInputs: 4,
          maxInputs: 4,
          evaluator: _encoder4Evaluator,
        );
      case ComponentType.encoder8to3:
        return const ComponentSpec(
          type: ComponentType.encoder8to3,
          kind: ComponentKind.module,
          title: 'انکودر ۸ به ۳',
          description: 'کد سه‌بیتی ورودی فعال را تولید می‌کند',
          inputLabels: <String>['D0', 'D1', 'D2', 'D3', 'D4', 'D5', 'D6', 'D7'],
          outputLabels: <String>['Y2', 'Y1', 'Y0'],
          minInputs: 8,
          maxInputs: 8,
          evaluator: _encoder8Evaluator,
        );
      case ComponentType.priorityEncoder:
        return const ComponentSpec(
          type: ComponentType.priorityEncoder,
          kind: ComponentKind.module,
          title: 'انکودر اولویت‌دار',
          description: 'بالاترین ورودی فعال انتخاب و در Y و V گزارش می‌شود',
          inputLabels: <String>['D0', 'D1', 'D2', 'D3', 'D4', 'D5', 'D6', 'D7'],
          outputLabels: <String>['Y2', 'Y1', 'Y0', 'V'],
          minInputs: 8,
          maxInputs: 8,
          evaluator: _priorityEncoderEvaluator,
        );
      case ComponentType.srLatch:
        return const ComponentSpec(
          type: ComponentType.srLatch,
          kind: ComponentKind.sequential,
          title: 'قفل SR',
          description: 'قفل سطح‌حساس با S و R فعال‌بالا',
          inputLabels: <String>['S', 'R'],
          outputLabels: <String>['Q', 'Q̅'],
          minInputs: 2,
          maxInputs: 2,
          evaluator: _srLatchEvaluator,
          latchUpdater: _srLatchUpdate,
          initialState: _initialLatchState,
        );
      case ComponentType.gatedSrLatch:
        return const ComponentSpec(
          type: ComponentType.gatedSrLatch,
          kind: ComponentKind.sequential,
          title: 'قفل SR فعال‌شونده',
          description: 'قفل SR فقط هنگام فعال بودن EN کار می‌کند',
          inputLabels: <String>['S', 'R', 'EN'],
          outputLabels: <String>['Q', 'Q̅'],
          minInputs: 3,
          maxInputs: 3,
          evaluator: _gatedSrLatchEvaluator,
          latchUpdater: _gatedSrLatchUpdate,
          initialState: _initialLatchState,
        );
      case ComponentType.dLatch:
        return const ComponentSpec(
          type: ComponentType.dLatch,
          kind: ComponentKind.sequential,
          title: 'قفل D',
          description: 'تا وقتی EN فعال است، Q مقدار D را دنبال می‌کند',
          inputLabels: <String>['D', 'EN'],
          outputLabels: <String>['Q', 'Q̅'],
          minInputs: 2,
          maxInputs: 2,
          evaluator: _dLatchEvaluator,
          latchUpdater: _dLatchUpdate,
          initialState: _initialLatchState,
        );
      case ComponentType.dFlipFlop:
        return const ComponentSpec(
          type: ComponentType.dFlipFlop,
          kind: ComponentKind.sequential,
          title: 'فلیپ‌فلپ D',
          description: 'با لبه بالارونده کلاک، D را در Q ذخیره می‌کند',
          inputLabels: <String>['D', 'CLK'],
          outputLabels: <String>['Q', 'Q̅'],
          minInputs: 2,
          maxInputs: 2,
          usesClock: true,
          evaluator: _flipFlopEvaluator,
          edgeUpdater: _dFlipFlopEdge,
          initialState: _initialFlipFlopState,
        );
      case ComponentType.tFlipFlop:
        return const ComponentSpec(
          type: ComponentType.tFlipFlop,
          kind: ComponentKind.sequential,
          title: 'فلیپ‌فلپ T',
          description: 'با لبه بالارونده و T=۱ وضعیت را وارونه می‌کند',
          inputLabels: <String>['T', 'CLK'],
          outputLabels: <String>['Q', 'Q̅'],
          minInputs: 2,
          maxInputs: 2,
          usesClock: true,
          evaluator: _flipFlopEvaluator,
          edgeUpdater: _tFlipFlopEdge,
          initialState: _initialFlipFlopState,
        );
      case ComponentType.jkFlipFlop:
        return const ComponentSpec(
          type: ComponentType.jkFlipFlop,
          kind: ComponentKind.sequential,
          title: 'فلیپ‌فلپ JK',
          description: 'با J=K=۱ وضعیت را وارونه می‌کند و با J=K=۰ نگه می‌دارد',
          inputLabels: <String>['J', 'K', 'CLK'],
          outputLabels: <String>['Q', 'Q̅'],
          minInputs: 3,
          maxInputs: 3,
          usesClock: true,
          evaluator: _flipFlopEvaluator,
          edgeUpdater: _jkFlipFlopEdge,
          initialState: _initialFlipFlopState,
        );
      case ComponentType.register4:
        return const ComponentSpec(
          type: ComponentType.register4,
          kind: ComponentKind.sequential,
          title: 'رجیستر ۴ بیتی',
          description: 'چهار بیت را با لبه بالارونده کلاک ذخیره می‌کند',
          inputLabels: <String>['D0', 'D1', 'D2', 'D3', 'CLK'],
          outputLabels: <String>['Q0', 'Q1', 'Q2', 'Q3'],
          minInputs: 5,
          maxInputs: 5,
          usesClock: true,
          evaluator: _registerEvaluator,
          edgeUpdater: _registerEdge,
          initialState: _initialRegisterState,
        );
      case ComponentType.shiftRegister4:
        return const ComponentSpec(
          type: ComponentType.shiftRegister4,
          kind: ComponentKind.sequential,
          title: 'رجیستر شیفت ۴ بیتی',
          description:
              'با هر لبه کلاک داده یک بیت جابه‌جا می‌شود (DIR=۰ راست، DIR=۱ چپ)',
          inputLabels: <String>['D', 'DIR', 'CLK'],
          outputLabels: <String>['Q0', 'Q1', 'Q2', 'Q3'],
          minInputs: 3,
          maxInputs: 3,
          usesClock: true,
          evaluator: _registerEvaluator,
          edgeUpdater: _shiftRegisterEdge,
          initialState: _initialRegisterState,
        );
      case ComponentType.counter4:
        return const ComponentSpec(
          type: ComponentType.counter4,
          kind: ComponentKind.sequential,
          title: 'شمارنده ۴ بیتی',
          description: 'با هر لبه کلاک یک واحد اضافه می‌کند',
          inputLabels: <String>['CLK', 'RST'],
          outputLabels: <String>['Q0', 'Q1', 'Q2', 'Q3'],
          minInputs: 2,
          maxInputs: 2,
          usesClock: true,
          evaluator: _registerEvaluator,
          edgeUpdater: _counterEdge,
          initialState: _initialRegisterState,
        );
      case ComponentType.upDownCounter4:
        return const ComponentSpec(
          type: ComponentType.upDownCounter4,
          kind: ComponentKind.sequential,
          title: 'شمارنده بالا/پایین ۴ بیتی',
          description: 'با UP=۱ افزایش و با UP=۰ کاهش می‌یابد',
          inputLabels: <String>['CLK', 'RST', 'UP'],
          outputLabels: <String>['Q0', 'Q1', 'Q2', 'Q3'],
          minInputs: 3,
          maxInputs: 3,
          usesClock: true,
          evaluator: _registerEvaluator,
          edgeUpdater: _upDownCounterEdge,
          initialState: _initialRegisterState,
        );
      case ComponentType.inputPin:
      case ComponentType.outputPin:
      case ComponentType.clockSource:
      case ComponentType.unknown:
        return specOf(type);
    }
  }

  // -----------------------------------------------------------------------
  // Primitive gate evaluators
  // -----------------------------------------------------------------------

  static ModuleEvaluator _gateEvaluator(ComponentType type) {
    return (List<LogicSignal> inputs, ComponentState state) {
      switch (type) {
        case ComponentType.andGate:
          return <LogicSignal>[andAll(inputs)];
        case ComponentType.orGate:
          return <LogicSignal>[orAll(inputs)];
        case ComponentType.nandGate:
          return <LogicSignal>[notSignal(andAll(inputs))];
        case ComponentType.norGate:
          return <LogicSignal>[notSignal(orAll(inputs))];
        case ComponentType.xorGate:
          return <LogicSignal>[xorAll(inputs)];
        case ComponentType.xnorGate:
          return <LogicSignal>[notSignal(xorAll(inputs))];
        default:
          return <LogicSignal>[LogicSignal.unknown];
      }
    };
  }

  static List<LogicSignal> _notEvaluator(
    List<LogicSignal> inputs,
    ComponentState state,
  ) {
    if (inputs.isEmpty) {
      return <LogicSignal>[LogicSignal.unknown];
    }
    return <LogicSignal>[notSignal(inputs.first)];
  }

  static List<LogicSignal> _bufferEvaluator(
    List<LogicSignal> inputs,
    ComponentState state,
  ) {
    if (inputs.isEmpty) {
      return <LogicSignal>[LogicSignal.unknown];
    }
    return <LogicSignal>[inputs.first];
  }

  static List<LogicSignal> _triStateEvaluator(
    List<LogicSignal> inputs,
    ComponentState state,
  ) {
    if (inputs.length < 2) {
      return <LogicSignal>[LogicSignal.unknown];
    }
    final LogicSignal data = inputs[0];
    final LogicSignal enable = inputs[1];
    if (enable == LogicSignal.low) {
      return <LogicSignal>[LogicSignal.highImpedance];
    }
    if (enable != LogicSignal.high) {
      return <LogicSignal>[LogicSignal.unknown];
    }
    return <LogicSignal>[data];
  }

  // -----------------------------------------------------------------------
  // Compound gate evaluators
  // -----------------------------------------------------------------------

  static List<LogicSignal> _aoi21Evaluator(
    List<LogicSignal> inputs,
    ComponentState state,
  ) {
    if (inputs.length < 3) {
      return <LogicSignal>[LogicSignal.unknown];
    }
    return <LogicSignal>[
      notSignal(
        orAll(<LogicSignal>[
          andAll(<LogicSignal>[inputs[0], inputs[1]]),
          inputs[2],
        ]),
      ),
    ];
  }

  static List<LogicSignal> _aoi22Evaluator(
    List<LogicSignal> inputs,
    ComponentState state,
  ) {
    if (inputs.length < 4) {
      return <LogicSignal>[LogicSignal.unknown];
    }
    return <LogicSignal>[
      notSignal(
        orAll(<LogicSignal>[
          andAll(<LogicSignal>[inputs[0], inputs[1]]),
          andAll(<LogicSignal>[inputs[2], inputs[3]]),
        ]),
      ),
    ];
  }

  static List<LogicSignal> _oai21Evaluator(
    List<LogicSignal> inputs,
    ComponentState state,
  ) {
    if (inputs.length < 3) {
      return <LogicSignal>[LogicSignal.unknown];
    }
    return <LogicSignal>[
      notSignal(
        andAll(<LogicSignal>[
          orAll(<LogicSignal>[inputs[0], inputs[1]]),
          inputs[2],
        ]),
      ),
    ];
  }

  static List<LogicSignal> _oai22Evaluator(
    List<LogicSignal> inputs,
    ComponentState state,
  ) {
    if (inputs.length < 4) {
      return <LogicSignal>[LogicSignal.unknown];
    }
    return <LogicSignal>[
      notSignal(
        andAll(<LogicSignal>[
          orAll(<LogicSignal>[inputs[0], inputs[1]]),
          orAll(<LogicSignal>[inputs[2], inputs[3]]),
        ]),
      ),
    ];
  }

  // -----------------------------------------------------------------------
  // Arithmetic evaluators
  // -----------------------------------------------------------------------

  static List<LogicSignal> _halfAdderEvaluator(
    List<LogicSignal> inputs,
    ComponentState state,
  ) {
    if (inputs.length < 2) {
      return <LogicSignal>[LogicSignal.unknown, LogicSignal.unknown];
    }
    return <LogicSignal>[
      xorAll(<LogicSignal>[inputs[0], inputs[1]]),
      andAll(<LogicSignal>[inputs[0], inputs[1]]),
    ];
  }

  static List<LogicSignal> _fullAdderEvaluator(
    List<LogicSignal> inputs,
    ComponentState state,
  ) {
    if (inputs.length < 3) {
      return <LogicSignal>[LogicSignal.unknown, LogicSignal.unknown];
    }
    final LogicSignal a = inputs[0];
    final LogicSignal b = inputs[1];
    final LogicSignal carryIn = inputs[2];
    final LogicSignal sum = xorAll(<LogicSignal>[a, b, carryIn]);
    final LogicSignal carryOut = orAll(<LogicSignal>[
      andAll(<LogicSignal>[a, b]),
      andAll(<LogicSignal>[a, carryIn]),
      andAll(<LogicSignal>[b, carryIn]),
    ]);
    return <LogicSignal>[sum, carryOut];
  }

  static List<LogicSignal> _halfSubtractorEvaluator(
    List<LogicSignal> inputs,
    ComponentState state,
  ) {
    if (inputs.length < 2) {
      return <LogicSignal>[LogicSignal.unknown, LogicSignal.unknown];
    }
    return <LogicSignal>[
      xorAll(<LogicSignal>[inputs[0], inputs[1]]),
      andAll(<LogicSignal>[notSignal(inputs[0]), inputs[1]]),
    ];
  }

  static List<LogicSignal> _fullSubtractorEvaluator(
    List<LogicSignal> inputs,
    ComponentState state,
  ) {
    if (inputs.length < 3) {
      return <LogicSignal>[LogicSignal.unknown, LogicSignal.unknown];
    }
    final LogicSignal a = inputs[0];
    final LogicSignal b = inputs[1];
    final LogicSignal borrowIn = inputs[2];
    final LogicSignal difference = xorAll(<LogicSignal>[a, b, borrowIn]);
    final LogicSignal borrowOut = orAll(<LogicSignal>[
      andAll(<LogicSignal>[notSignal(a), b]),
      andAll(<LogicSignal>[notSignal(a), borrowIn]),
      andAll(<LogicSignal>[b, borrowIn]),
    ]);
    return <LogicSignal>[difference, borrowOut];
  }

  static List<LogicSignal> _comparatorEvaluator(
    List<LogicSignal> inputs,
    ComponentState state,
  ) {
    if (inputs.length < 4) {
      return <LogicSignal>[
        LogicSignal.unknown,
        LogicSignal.unknown,
        LogicSignal.unknown,
      ];
    }
    // The bit vectors are handled least significant bit first.
    final List<LogicSignal> a = <LogicSignal>[inputs[1], inputs[0]];
    final List<LogicSignal> b = <LogicSignal>[inputs[3], inputs[2]];
    final LogicSignal equal = andAll(<LogicSignal>[
      notSignal(xorAll(<LogicSignal>[a[0], b[0]])),
      notSignal(xorAll(<LogicSignal>[a[1], b[1]])),
    ]);
    // "Less than" is the borrow of a - b, "greater than" the borrow of b - a.
    // Deriving one from the other would report "greater" for equal numbers.
    final LogicSignal less = _subtractBits(a, b)[2];
    final LogicSignal greater = _subtractBits(b, a)[2];
    return <LogicSignal>[less, equal, greater];
  }

  // -----------------------------------------------------------------------
  // Selection and coding evaluators
  // -----------------------------------------------------------------------

  static List<LogicSignal> _mux2Evaluator(
    List<LogicSignal> inputs,
    ComponentState state,
  ) {
    if (inputs.length < 3) {
      return <LogicSignal>[LogicSignal.unknown];
    }
    return <LogicSignal>[_mux2(inputs[0], inputs[1], inputs[2])];
  }

  static List<LogicSignal> _mux4Evaluator(
    List<LogicSignal> inputs,
    ComponentState state,
  ) {
    if (inputs.length < 6) {
      return <LogicSignal>[LogicSignal.unknown];
    }
    final LogicSignal s1 = inputs[4];
    final LogicSignal s0 = inputs[5];
    if (s1 != LogicSignal.high && s1 != LogicSignal.low) {
      return <LogicSignal>[LogicSignal.unknown];
    }
    if (s0 != LogicSignal.high && s0 != LogicSignal.low) {
      return <LogicSignal>[LogicSignal.unknown];
    }
    final int index =
        (s1 == LogicSignal.high ? 2 : 0) + (s0 == LogicSignal.high ? 1 : 0);
    return <LogicSignal>[inputs[index]];
  }

  static List<LogicSignal> _demux2Evaluator(
    List<LogicSignal> inputs,
    ComponentState state,
  ) {
    if (inputs.length < 2) {
      return <LogicSignal>[LogicSignal.unknown, LogicSignal.unknown];
    }
    final LogicSignal select = inputs[1];
    if (select == LogicSignal.high) {
      return <LogicSignal>[LogicSignal.low, inputs[0]];
    }
    if (select == LogicSignal.low) {
      return <LogicSignal>[inputs[0], LogicSignal.low];
    }
    return <LogicSignal>[LogicSignal.unknown, LogicSignal.unknown];
  }

  static List<LogicSignal> _demux4Evaluator(
    List<LogicSignal> inputs,
    ComponentState state,
  ) {
    if (inputs.length < 3) {
      return <LogicSignal>[
        LogicSignal.unknown,
        LogicSignal.unknown,
        LogicSignal.unknown,
        LogicSignal.unknown,
      ];
    }
    final LogicSignal s1 = inputs[1];
    final LogicSignal s0 = inputs[2];
    if ((s1 != LogicSignal.high && s1 != LogicSignal.low) ||
        (s0 != LogicSignal.high && s0 != LogicSignal.low)) {
      return <LogicSignal>[
        LogicSignal.unknown,
        LogicSignal.unknown,
        LogicSignal.unknown,
        LogicSignal.unknown,
      ];
    }
    final int index =
        (s1 == LogicSignal.high ? 2 : 0) + (s0 == LogicSignal.high ? 1 : 0);
    final List<LogicSignal> result = List<LogicSignal>.filled(
      4,
      LogicSignal.low,
    );
    result[index] = inputs[0];
    return result;
  }

  static List<LogicSignal> _decoder4Evaluator(
    List<LogicSignal> inputs,
    ComponentState state,
  ) {
    if (inputs.length < 2) {
      return List<LogicSignal>.filled(4, LogicSignal.unknown);
    }
    if (inputs[0] != LogicSignal.high && inputs[0] != LogicSignal.low) {
      return List<LogicSignal>.filled(4, LogicSignal.unknown);
    }
    if (inputs[1] != LogicSignal.high && inputs[1] != LogicSignal.low) {
      return List<LogicSignal>.filled(4, LogicSignal.unknown);
    }
    final int index =
        (inputs[0] == LogicSignal.high ? 2 : 0) +
        (inputs[1] == LogicSignal.high ? 1 : 0);
    final List<LogicSignal> result = List<LogicSignal>.filled(
      4,
      LogicSignal.low,
    );
    result[index] = LogicSignal.high;
    return result;
  }

  static List<LogicSignal> _decoder8Evaluator(
    List<LogicSignal> inputs,
    ComponentState state,
  ) {
    if (inputs.length < 3) {
      return List<LogicSignal>.filled(8, LogicSignal.unknown);
    }
    for (final LogicSignal value in inputs) {
      if (value != LogicSignal.high && value != LogicSignal.low) {
        return List<LogicSignal>.filled(8, LogicSignal.unknown);
      }
    }
    int index = 0;
    for (int i = 0; i < 3; i++) {
      index = (index << 1) | (inputs[i] == LogicSignal.high ? 1 : 0);
    }
    final List<LogicSignal> result = List<LogicSignal>.filled(
      8,
      LogicSignal.low,
    );
    result[index] = LogicSignal.high;
    return result;
  }

  static List<LogicSignal> _encoder4Evaluator(
    List<LogicSignal> inputs,
    ComponentState state,
  ) {
    if (inputs.length < 4) {
      return <LogicSignal>[LogicSignal.unknown, LogicSignal.unknown];
    }
    if (inputs.any(
      (LogicSignal value) =>
          value != LogicSignal.high && value != LogicSignal.low,
    )) {
      return <LogicSignal>[LogicSignal.unknown, LogicSignal.unknown];
    }
    final bool d1 = inputs[1] == LogicSignal.high;
    final bool d2 = inputs[2] == LogicSignal.high;
    final bool d3 = inputs[3] == LogicSignal.high;
    return <LogicSignal>[_bool(d2 || d3), _bool(d1 || d3)];
  }

  static List<LogicSignal> _encoder8Evaluator(
    List<LogicSignal> inputs,
    ComponentState state,
  ) {
    if (inputs.length < 8) {
      return <LogicSignal>[
        LogicSignal.unknown,
        LogicSignal.unknown,
        LogicSignal.unknown,
      ];
    }
    for (final LogicSignal value in inputs) {
      if (value != LogicSignal.high && value != LogicSignal.low) {
        return <LogicSignal>[
          LogicSignal.unknown,
          LogicSignal.unknown,
          LogicSignal.unknown,
        ];
      }
    }
    int index = 0;
    for (int i = 0; i < 8; i++) {
      if (inputs[i] == LogicSignal.high) {
        index = i;
      }
    }
    return <LogicSignal>[
      _bool(index & 0x4 != 0),
      _bool(index & 0x2 != 0),
      _bool(index & 0x1 != 0),
    ];
  }

  static List<LogicSignal> _priorityEncoderEvaluator(
    List<LogicSignal> inputs,
    ComponentState state,
  ) {
    if (inputs.length < 8) {
      return <LogicSignal>[
        LogicSignal.unknown,
        LogicSignal.unknown,
        LogicSignal.unknown,
        LogicSignal.unknown,
      ];
    }
    for (final LogicSignal value in inputs) {
      if (value != LogicSignal.high && value != LogicSignal.low) {
        return <LogicSignal>[
          LogicSignal.unknown,
          LogicSignal.unknown,
          LogicSignal.unknown,
          LogicSignal.unknown,
        ];
      }
    }
    int index = -1;
    for (int i = 7; i >= 0; i--) {
      if (inputs[i] == LogicSignal.high) {
        index = i;
        break;
      }
    }
    if (index < 0) {
      return <LogicSignal>[
        LogicSignal.low,
        LogicSignal.low,
        LogicSignal.low,
        LogicSignal.low,
      ];
    }
    return <LogicSignal>[
      _bool(index & 0x4 != 0),
      _bool(index & 0x2 != 0),
      _bool(index & 0x1 != 0),
      LogicSignal.high,
    ];
  }

  // -----------------------------------------------------------------------
  // Sequential evaluators
  // -----------------------------------------------------------------------

  static ComponentState _initialLatchState() => const ComponentState(
    q: LogicSignal.low,
    qBar: LogicSignal.high,
    initialized: true,
  );

  static ComponentState _initialFlipFlopState() => const ComponentState(
    q: LogicSignal.low,
    qBar: LogicSignal.high,
    prevClock: false,
    initialized: true,
  );

  static ComponentState _initialRegisterState() => const ComponentState(
    bits: <LogicSignal>[
      LogicSignal.low,
      LogicSignal.low,
      LogicSignal.low,
      LogicSignal.low,
    ],
    initialized: true,
  );

  /// Toggles a stored bit. An unknown value stays unknown.
  static LogicSignal _toggle(LogicSignal value) {
    return switch (value) {
      LogicSignal.high => LogicSignal.low,
      LogicSignal.low => LogicSignal.high,
      _ => LogicSignal.unknown,
    };
  }

  /// A data line that is not firmly driven carries no information; it is
  /// treated as unknown (a high-impedance line is a floating line).
  static LogicSignal _asData(LogicSignal value) {
    return (value == LogicSignal.high || value == LogicSignal.low)
        ? value
        : LogicSignal.unknown;
  }

  static List<LogicSignal> _srLatchEvaluator(
    List<LogicSignal> inputs,
    ComponentState state,
  ) {
    return <LogicSignal>[state.q, state.qBar];
  }

  static ComponentState _srLatchUpdate(
    List<LogicSignal> inputs,
    ComponentState state,
  ) {
    if (inputs.length < 2) {
      return state;
    }
    final LogicSignal set = inputs[0];
    final LogicSignal reset = inputs[1];
    if (set == LogicSignal.high && reset == LogicSignal.high) {
      // Illegal state for an active-high NOR latch: both outputs are high.
      return state.copyWith(q: LogicSignal.high, qBar: LogicSignal.high);
    }
    if (set == LogicSignal.high) {
      return state.copyWith(q: LogicSignal.high, qBar: LogicSignal.low);
    }
    if (reset == LogicSignal.high) {
      return state.copyWith(q: LogicSignal.low, qBar: LogicSignal.high);
    }
    if (set == LogicSignal.unknown || reset == LogicSignal.unknown) {
      // An ambiguous request keeps the stored value but marks it uncertain.
      return state.copyWith(q: LogicSignal.unknown, qBar: LogicSignal.unknown);
    }
    return state;
  }

  static List<LogicSignal> _gatedSrLatchEvaluator(
    List<LogicSignal> inputs,
    ComponentState state,
  ) {
    return <LogicSignal>[state.q, state.qBar];
  }

  static ComponentState _gatedSrLatchUpdate(
    List<LogicSignal> inputs,
    ComponentState state,
  ) {
    if (inputs.length < 3) {
      return state;
    }
    if (inputs[2] != LogicSignal.high) {
      // The latch is closed and keeps its value.
      return state;
    }
    return _srLatchUpdate(<LogicSignal>[inputs[0], inputs[1]], state);
  }

  static List<LogicSignal> _dLatchEvaluator(
    List<LogicSignal> inputs,
    ComponentState state,
  ) {
    return <LogicSignal>[state.q, state.qBar];
  }

  static ComponentState _dLatchUpdate(
    List<LogicSignal> inputs,
    ComponentState state,
  ) {
    if (inputs.length < 2) {
      return state;
    }
    if (inputs[1] != LogicSignal.high) {
      // The latch is closed and holds the stored value.
      return state;
    }
    final LogicSignal data = _asData(inputs[0]);
    if (data == LogicSignal.unknown) {
      return state.copyWith(q: LogicSignal.unknown, qBar: LogicSignal.unknown);
    }
    return state.copyWith(q: data, qBar: notSignal(data));
  }

  static List<LogicSignal> _flipFlopEvaluator(
    List<LogicSignal> inputs,
    ComponentState state,
  ) {
    return <LogicSignal>[state.q, state.qBar];
  }

  static ComponentState _dFlipFlopEdge(
    List<LogicSignal> inputs,
    ComponentState state,
  ) {
    if (inputs.length < 2) {
      return state;
    }
    final LogicSignal data = _asData(inputs[0]);
    if (data == LogicSignal.unknown) {
      // Capturing a floating or unknown line makes the stored value unknown.
      return state.copyWith(
        q: LogicSignal.unknown,
        qBar: LogicSignal.unknown,
        initialized: true,
      );
    }
    return state.copyWith(q: data, qBar: notSignal(data), initialized: true);
  }

  static ComponentState _tFlipFlopEdge(
    List<LogicSignal> inputs,
    ComponentState state,
  ) {
    if (inputs.length < 2) {
      return state;
    }
    final LogicSignal toggle = inputs[0];
    if (toggle == LogicSignal.low) {
      return state;
    }
    if (toggle != LogicSignal.high) {
      // It is unclear whether the flip-flop toggles, so the state becomes
      // unknown instead of guessing.
      return state.copyWith(
        q: LogicSignal.unknown,
        qBar: LogicSignal.unknown,
        initialized: true,
      );
    }
    final LogicSignal next = _toggle(state.q);
    return state.copyWith(q: next, qBar: notSignal(next), initialized: true);
  }

  static ComponentState _jkFlipFlopEdge(
    List<LogicSignal> inputs,
    ComponentState state,
  ) {
    if (inputs.length < 3) {
      return state;
    }
    final LogicSignal j = inputs[0];
    final LogicSignal k = inputs[1];
    if ((j != LogicSignal.high && j != LogicSignal.low) ||
        (k != LogicSignal.high && k != LogicSignal.low)) {
      return state.copyWith(
        q: LogicSignal.unknown,
        qBar: LogicSignal.unknown,
        initialized: true,
      );
    }
    final bool jHigh = j == LogicSignal.high;
    final bool kHigh = k == LogicSignal.high;
    if (jHigh && !kHigh) {
      return state.copyWith(
        q: LogicSignal.high,
        qBar: LogicSignal.low,
        initialized: true,
      );
    }
    if (!jHigh && kHigh) {
      return state.copyWith(
        q: LogicSignal.low,
        qBar: LogicSignal.high,
        initialized: true,
      );
    }
    if (jHigh && kHigh) {
      final LogicSignal next = _toggle(state.q);
      return state.copyWith(q: next, qBar: notSignal(next), initialized: true);
    }
    return state;
  }

  static List<LogicSignal> _registerEvaluator(
    List<LogicSignal> inputs,
    ComponentState state,
  ) {
    if (state.bits.length == 4) {
      return List<LogicSignal>.unmodifiable(state.bits);
    }
    return const <LogicSignal>[
      LogicSignal.low,
      LogicSignal.low,
      LogicSignal.low,
      LogicSignal.low,
    ];
  }

  static ComponentState _registerEdge(
    List<LogicSignal> inputs,
    ComponentState state,
  ) {
    if (inputs.length < 5) {
      return state;
    }
    final List<LogicSignal> bits = <LogicSignal>[
      for (int i = 0; i < 4; i++) _asData(inputs[i]),
    ];
    return state.copyWith(bits: bits, initialized: true);
  }

  static ComponentState _shiftRegisterEdge(
    List<LogicSignal> inputs,
    ComponentState state,
  ) {
    if (inputs.length < 3) {
      return state;
    }
    final List<LogicSignal> current =
        state.bits.length == 4
            ? state.bits
            : const <LogicSignal>[
              LogicSignal.low,
              LogicSignal.low,
              LogicSignal.low,
              LogicSignal.low,
            ];
    final LogicSignal data = _asData(inputs[0]);
    final bool shiftRight = inputs[1] == LogicSignal.low;
    final List<LogicSignal> next =
        shiftRight
            ? <LogicSignal>[data, current[0], current[1], current[2]]
            : <LogicSignal>[current[1], current[2], current[3], data];
    return state.copyWith(bits: next, initialized: true);
  }

  static ComponentState _counterEdge(
    List<LogicSignal> inputs,
    ComponentState state,
  ) {
    if (inputs.length < 2) {
      return state;
    }
    if (inputs[1] == LogicSignal.high) {
      return state.copyWith(
        bits: const <LogicSignal>[
          LogicSignal.low,
          LogicSignal.low,
          LogicSignal.low,
          LogicSignal.low,
        ],
        initialized: true,
      );
    }
    final List<LogicSignal> current =
        state.bits.length == 4
            ? state.bits
            : const <LogicSignal>[
              LogicSignal.low,
              LogicSignal.low,
              LogicSignal.low,
              LogicSignal.low,
            ];
    final int value = _bitsToInt(current) + 1 & 0xF;
    return state.copyWith(bits: _intToBits(value), initialized: true);
  }

  static ComponentState _upDownCounterEdge(
    List<LogicSignal> inputs,
    ComponentState state,
  ) {
    if (inputs.length < 3) {
      return state;
    }
    if (inputs[1] == LogicSignal.high) {
      return state.copyWith(
        bits: const <LogicSignal>[
          LogicSignal.low,
          LogicSignal.low,
          LogicSignal.low,
          LogicSignal.low,
        ],
        initialized: true,
      );
    }
    final List<LogicSignal> current =
        state.bits.length == 4
            ? state.bits
            : const <LogicSignal>[
              LogicSignal.low,
              LogicSignal.low,
              LogicSignal.low,
              LogicSignal.low,
            ];
    final int value =
        inputs[2] == LogicSignal.high
            ? _bitsToInt(current) + 1 & 0xF
            : _bitsToInt(current) - 1 & 0xF;
    return state.copyWith(bits: _intToBits(value), initialized: true);
  }

  /// Reads a little endian bit vector (index 0 is the least significant bit).
  static int _bitsToInt(List<LogicSignal> bits) {
    int value = 0;
    for (int i = 3; i >= 0; i--) {
      value =
          (value << 1) |
          (i < bits.length && bits[i] == LogicSignal.high ? 1 : 0);
    }
    return value;
  }

  static List<LogicSignal> _intToBits(int value) {
    return <LogicSignal>[
      value & 0x1 != 0 ? LogicSignal.high : LogicSignal.low,
      value & 0x2 != 0 ? LogicSignal.high : LogicSignal.low,
      value & 0x4 != 0 ? LogicSignal.high : LogicSignal.low,
      value & 0x8 != 0 ? LogicSignal.high : LogicSignal.low,
    ];
  }

  /// All component types that the library can place on the canvas.
  static List<ComponentType> get allTypes {
    return <ComponentType>[
      ...basicGates,
      ...compoundGates,
      ...arithmeticModules,
      ...selectionModules,
      ...sequentialComponents,
    ];
  }

  /// The base elements every circuit can use.
  static const List<ComponentType> baseElements = <ComponentType>[
    ComponentType.inputPin,
    ComponentType.outputPin,
    ComponentType.clockSource,
  ];

  /// Human readable groups used by the component drawer.
  static Map<String, List<ComponentType>> get catalogue {
    return <String, List<ComponentType>>{
      'پایه‌ها': baseElements,
      'گیت‌های پایه': basicGates,
      'گیت‌های مرکب': compoundGates,
      'ماژول‌های حسابی': arithmeticModules,
      'انتخابگر و کدگذار': selectionModules,
      'مدارهای ترتیبی': sequentialComponents,
    };
  }
}
