import 'dart:math' as math;

/// A plain 2-D point used by the circuit domain. Deliberately independent of
/// Flutter's Offset so simulation and layout can be tested without widgets.
class CanvasPoint {
  const CanvasPoint(this.x, this.y);

  final double x;
  final double y;

  CanvasPoint translate(double dx, double dy) => CanvasPoint(x + dx, y + dy);

  double distanceTo(CanvasPoint other) {
    return math.sqrt(math.pow(x - other.x, 2) + math.pow(y - other.y, 2));
  }

  bool get isFinite => x.isFinite && y.isFinite;

  Map<String, Object?> toJson() => <String, Object?>{'x': x, 'y': y};

  factory CanvasPoint.fromJson(Object? value) {
    if (value is! Map) {
      throw const FormatException('مختصات نقطه معتبر نیست.');
    }
    final Object? x = value['x'];
    final Object? y = value['y'];
    if (x is! num ||
        y is! num ||
        !x.toDouble().isFinite ||
        !y.toDouble().isFinite) {
      throw const FormatException('مختصات نقطه باید عددی متناهی باشد.');
    }
    return CanvasPoint(x.toDouble(), y.toDouble());
  }

  @override
  bool operator ==(Object other) {
    return other is CanvasPoint && other.x == x && other.y == y;
  }

  @override
  int get hashCode => Object.hash(x, y);

  @override
  String toString() => 'CanvasPoint($x, $y)';
}

/// The four-valued signal model used by the simulator.
///
/// [unknown] is never treated as LOW. It represents a value that cannot be
/// proven because of an unconnected input, an invalid wire, or a combinational
/// cycle. [highImpedance] is the explicit Z state of a tri-state driver: the
/// output does not drive the line at all.
enum LogicSignal {
  low,
  high,
  unknown,
  highImpedance;

  bool? get booleanValue => switch (this) {
    LogicSignal.low => false,
    LogicSignal.high => true,
    LogicSignal.unknown => null,
    LogicSignal.highImpedance => null,
  };

  bool get isKnown => this == LogicSignal.low || this == LogicSignal.high;

  bool get isHighImpedance => this == LogicSignal.highImpedance;

  static LogicSignal fromBool(bool value) => value ? high : low;
}

/// Every component type the laboratory can represent.
///
/// The [jsonName] values are part of the persisted project format. Existing
/// values are never renamed, so circuits saved by older builds keep loading.
/// Unrecognised values are mapped to [ComponentType.unknown] instead of
/// failing the whole project.
enum ComponentType {
  inputPin('input', 'ورودی', 'IN', 'کلید دوحالته با مقدار اولیه'),
  outputPin('output', 'خروجی', 'OUT', 'نمایش نتیجه سیگنال'),
  clockSource('clock', 'کلاک', 'CLK', 'تولید پالس کلاک برای مدارهای ترتیبی'),

  andGate('and', 'AND', 'AND', 'و منطقی با ۲ تا ۸ ورودی'),
  orGate('or', 'OR', 'OR', 'یا منطقی با ۲ تا ۸ ورودی'),
  notGate('not', 'NOT', 'NOT', 'معکوس‌کننده'),
  nandGate('nand', 'NAND', 'NAND', 'معکوس AND با ۲ تا ۸ ورودی'),
  norGate('nor', 'NOR', 'NOR', 'معکوس OR با ۲ تا ۸ ورودی'),
  xorGate('xor', 'XOR', 'XOR', 'یای انحصاری (پاریتی) با ۲ تا ۸ ورودی'),
  xnorGate('xnor', 'XNOR', 'XNOR', 'معکوس XOR با ۲ تا ۸ ورودی'),
  bufferGate('buffer', 'بافر', 'BUF', 'انتقال بدون تغییر سیگنال'),
  triStateBuffer(
    'tristate',
    'بافر سه‌حالته',
    'TRI',
    'با EN فعال خروجی را می‌راند و در غیر این صورت Z می‌شود',
  ),

  aoi21('aoi21', 'AOI21', 'AOI21', 'Y = ¬((A ∧ B) ∨ C)'),
  aoi22('aoi22', 'AOI22', 'AOI22', 'Y = ¬((A ∧ B) ∨ (C ∧ D))'),
  oai21('oai21', 'OAI21', 'OAI21', 'Y = ¬((A ∨ B) ∧ C)'),
  oai22('oai22', 'OAI22', 'OAI22', 'Y = ¬((A ∨ B) ∧ (C ∨ D))'),

  halfAdder('halfadder', 'نیم‌جمع‌کننده', 'HA', 'S = A ⊕ B و C = A ∧ B'),
  fullAdder('fulladder', 'جمع‌کننده کامل', 'FA', 'جمع سه ورودی با بابت حمل'),
  halfSubtractor(
    'halfsubtractor',
    'نیم‌تفریق‌کننده',
    'HS',
    'D = A ⊕ B و Br = ¬A ∧ B',
  ),
  fullSubtractor(
    'fullsubtractor',
    'تفریق‌کننده کامل',
    'FS',
    'تفریق سه ورودی با بابت قرض',
  ),
  comparator(
    'comparator',
    'مقایسه‌گر دوبیتی',
    'CMP',
    'مقایسه A و B و تولید LT، EQ و GT',
  ),

  mux2('mux2', 'مالتی‌پلکسر ۲ به ۱', 'MUX2', 'Y = S ? I1 : I0'),
  mux4('mux4', 'مالتی‌پلکسر ۴ به ۱', 'MUX4', 'انتخاب یکی از چهار ورودی'),
  demux1to2(
    'demux2',
    'دیمالتی‌پلکسر ۱ به ۲',
    'DEM2',
    'هدایت داده به یکی از دو خروجی',
  ),
  demux1to4(
    'demux4',
    'دیمالتی‌پلکسر ۱ به ۴',
    'DEM4',
    'هدایت داده به یکی از چهار خروجی',
  ),
  decoder2to4(
    'decoder4',
    'دیکودر ۲ به ۴',
    'DEC4',
    'فعال‌سازی یکی از چهار خروجی',
  ),
  decoder3to8(
    'decoder8',
    'دیکودر ۳ به ۸',
    'DEC8',
    'فعال‌سازی یکی از هشت خروجی',
  ),
  encoder4to2('encoder2', 'انکودر ۴ به ۲', 'ENC2', 'کد دودویی ورودی فعال'),
  encoder8to3('encoder3', 'انکودر ۸ به ۳', 'ENC3', 'کد سه‌بیتی ورودی فعال'),
  priorityEncoder(
    'priorityencoder',
    'انکودر اولویت‌دار',
    'PENC',
    'بالاترین ورودی فعال انتخاب می‌شود',
  ),

  srLatch('srlatch', 'قفل SR', 'SR', 'قفل سطح‌حساس با S و R فعال‌بالا'),
  gatedSrLatch(
    'gatedsrlatch',
    'قفل SR فعال‌شونده',
    'GSR',
    'قفل SR فقط هنگام فعال بودن EN',
  ),
  dLatch('dlatch', 'قفل D', 'DL', 'قفل داده با فعال‌سازی EN'),
  dFlipFlop('dff', 'فلیپ‌فلپ D', 'DFF', 'ذخیره D با لبه بالارونده کلاک'),
  tFlipFlop('tff', 'فلیپ‌فلپ T', 'TFF', 'وارونه‌سازی وضعیت با T=۱'),
  jkFlipFlop('jkff', 'فلیپ‌فلپ JK', 'JKFF', 'رفتار JK با J=K=۱ وارونه می‌کند'),
  register4('register4', 'رجیستر ۴ بیتی', 'REG4', 'ذخیره چهار بیت با لبه کلاک'),
  shiftRegister4(
    'shiftregister4',
    'رجیستر شیفت ۴ بیتی',
    'SR4',
    'جابه‌جایی داده با هر لبه کلاک',
  ),
  counter4('counter4', 'شمارنده ۴ بیتی', 'CNT4', 'شمارش صعودی با هر لبه کلاک'),
  upDownCounter4(
    'updowncounter4',
    'شمارنده بالا/پایین',
    'UDC4',
    'شمارش صعودی یا نزولی',
  ),

  unknown(
    'unknown',
    'قطعه پشتیبانی‌نشده',
    '?',
    'این نوع قطعه در این نسخه شناخته نمی‌شود',
  );

  const ComponentType(
    this.jsonName,
    this.persianName,
    this.technicalName,
    this.description,
  );

  final String jsonName;
  final String persianName;
  final String technicalName;
  final String description;

  bool get isInput => this == ComponentType.inputPin;
  bool get isOutput => this == ComponentType.outputPin;
  bool get isClock => this == ComponentType.clockSource;
  bool get isGate => switch (this) {
    ComponentType.andGate ||
    ComponentType.orGate ||
    ComponentType.notGate ||
    ComponentType.nandGate ||
    ComponentType.norGate ||
    ComponentType.xorGate ||
    ComponentType.xnorGate ||
    ComponentType.bufferGate ||
    ComponentType.triStateBuffer => true,
    _ => false,
  };

  bool get isBinaryGate =>
      isGate &&
      this != ComponentType.notGate &&
      this != ComponentType.bufferGate;

  bool get producesSignal => !isOutput;
  bool get acceptsInputs => !isInput && !isClock;

  /// Maps a persisted name to a type. Unknown names are mapped to
  /// [ComponentType.unknown] so that a project written by a newer build can
  /// still be opened and the unsupported component can be reported.
  static ComponentType fromJson(String? value) {
    if (value == null) {
      return ComponentType.unknown;
    }
    for (final ComponentType type in ComponentType.values) {
      if (type.jsonName == value || type.name == value) {
        return type;
      }
    }
    return ComponentType.unknown;
  }
}
