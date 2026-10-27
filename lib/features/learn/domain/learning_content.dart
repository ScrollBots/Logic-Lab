import 'package:flutter/foundation.dart';

import '../../editor/domain/circuit_models.dart';

@immutable
class GateDefinition {
  const GateDefinition({
    required this.type,
    required this.title,
    required this.expression,
    required this.description,
    required this.useCase,
    required this.truthTable,
  });

  final ComponentType type;
  final String title;
  final String expression;
  final String description;
  final String useCase;

  /// Row order: A=0,B=0 then A=0,B=1 then A=1,B=0 then A=1,B=1.
  final List<bool> truthTable;

  bool outputFor(bool a, bool b) {
    final int index = (a ? 2 : 0) + (b ? 1 : 0);
    return truthTable[index];
  }
}

const List<GateDefinition> kGateDefinitions = <GateDefinition>[
  GateDefinition(
    type: ComponentType.andGate,
    title: 'دروازه AND',
    expression: 'Y = A · B',
    description: 'خروجی تنها زمانی ۱ است که همه ورودی‌ها ۱ باشند. این دروازه معادل «و» در منطق ریاضی است.',
    useCase: 'فعال‌سازی چند شرط هم‌زمان، مثل روشن شدن سیستم وقتی هم قفل بسته است و هم کلید فعال است.',
    truthTable: <bool>[false, false, false, true],
  ),
  GateDefinition(
    type: ComponentType.orGate,
    title: 'دروازه OR',
    expression: 'Y = A + B',
    description: 'خروجی وقتی ۱ است که حداقل یکی از ورودی‌ها ۱ باشد. این دروازه معادل «یا» است.',
    useCase: 'فعال کردن زنگ هشدار از هر یک از چند حسگر.',
    truthTable: <bool>[false, true, true, true],
  ),
  GateDefinition(
    type: ComponentType.notGate,
    title: 'دروازه NOT',
    expression: 'Y = ¬A',
    description: 'خروجی را معکوس می‌کند: ورودی ۱ به خروجی ۰ و ورودی ۰ به خروجی ۱ تبدیل می‌شود.',
    useCase: 'ساخت مدار نات (NAND) و نور (NOR) با کمترین قطعه.',
    truthTable: <bool>[true, true, false, false],
  ),
  GateDefinition(
    type: ComponentType.nandGate,
    title: 'دروازه NAND',
    expression: 'Y = ¬(A · B)',
    description: 'معکوس خروجی AND است. در سخت‌افزار دیجیتال پرکاربرد است چون با NOR می‌توان هر تابعی را ساخت.',
    useCase: 'ساخت مدارهای پیچیده با کمترین تعداد قطعه در فناوری CMOS.',
    truthTable: <bool>[true, true, true, false],
  ),
  GateDefinition(
    type: ComponentType.norGate,
    title: 'دروازه NOR',
    expression: 'Y = ¬(A + B)',
    description:
        'معکوس خروجی OR است؛ تنها وقتی ۱ است که همه ورودی‌ها صفر باشند.',
    useCase: 'مدار تشخیص «همه خاموش» در یک گروه از دستگاه‌ها.',
    truthTable: <bool>[true, false, false, false],
  ),
  GateDefinition(
    type: ComponentType.xorGate,
    title: 'دروازه XOR',
    expression: 'Y = A ⊕ B',
    description: 'خروجی ۱ است وقتی دو ورودی متفاوت باشند؛ یعنی تعداد ورودی‌های ۱ فرد باشد.',
    useCase: 'مقایسه دو بیت، تشخیص تغییر وضعیت و ساخت نیم‌جمع‌کننده.',
    truthTable: <bool>[false, true, true, false],
  ),
  GateDefinition(
    type: ComponentType.xnorGate,
    title: 'دروازه XNOR',
    expression: 'Y = A ⊙ B',
    description: 'معکوس XOR است؛ خروجی ۱ است وقتی دو ورودی یکسان باشند.',
    useCase: 'مقایسه برابری دو مقدار در مدارهای تشخیص خطا.',
    truthTable: <bool>[true, false, false, true],
  ),
];

@immutable
class LearningChallenge {
  const LearningChallenge({
    required this.id,
    required this.title,
    required this.brief,
    required this.hint,
    required this.expectedOutputs,
    this.allowedGates,
    this.requiredOutputCount = 1,
    this.inputLabels = const <String>['A', 'B'],
    this.outputLabels = const <String>['Y'],
    this.expectedOutputsByLabel,
    this.concepts = const <String>[],
  });

  final String id;
  final String title;
  final String brief;
  final String hint;

  /// Expected output for A=0,B=0 / A=0,B=1 / A=1,B=0 / A=1,B=1.
  final List<bool> expectedOutputs;

  /// null means any gate type is allowed.
  final List<ComponentType>? allowedGates;
  final int requiredOutputCount;

  /// Labels of the starter pins created by the learning screens.
  final List<String> inputLabels;

  /// Output pins the learner has to provide. A two-output challenge such as a
  /// half adder requires both labels and [expectedOutputsByLabel].
  final List<String> outputLabels;

  /// Multi-output challenges are validated per label instead of relying on the
  /// order in which outputs happen to be created.
  final Map<String, List<bool>>? expectedOutputsByLabel;

  /// Concepts that are credited when this challenge is completed.
  final List<String> concepts;
}

const List<LearningChallenge> kChallenges = <LearningChallenge>[
  LearningChallenge(
    id: 'challenge_and',
    title: 'گیت AND بسازید',
    brief: 'با دو ورودی A و B و یک خروجی، مداری بسازید که فقط وقتی هر دو ورودی ۱ باشند خروجی ۱ شود.',
    hint: 'یک دروازه AND کافی است؛ هر دو ورودی را به آن وصل کنید.',
    expectedOutputs: <bool>[false, false, false, true],
    allowedGates: <ComponentType>[ComponentType.andGate],
    concepts: <String>['and'],
  ),
  LearningChallenge(
    id: 'challenge_or',
    title: 'گیت OR بسازید',
    brief:
        'مداری بسازید که وقتی حداقل یکی از ورودی‌ها ۱ است، خروجی ۱ داشته باشد.',
    hint: 'یک دروازه OR کافی است؛ هر دو ورودی را به آن وصل کنید.',
    expectedOutputs: <bool>[false, true, true, true],
    allowedGates: <ComponentType>[ComponentType.orGate],
    concepts: <String>['or'],
  ),
  LearningChallenge(
    id: 'challenge_buffer',
    title: 'سیگنال را منتقل کنید',
    brief: 'ورودی A را بدون تغییر به خروجی Y برسانید. مقدار B در این مدار اهمیتی ندارد.',
    hint: 'یک بافر (BUF) بردارید؛ ورودی A را به آن و خروجی بافر را به Y وصل کنید.',
    expectedOutputs: <bool>[false, false, true, true],
    allowedGates: <ComponentType>[ComponentType.bufferGate],
    concepts: <String>['buffer', 'wiring'],
  ),
  LearningChallenge(
    id: 'challenge_xor',
    title: 'گیت XOR بسازید',
    brief: 'مداری بسازید که خروجی آن فقط وقتی ۱ باشد که دو ورودی متفاوت باشند. استفاده از گیت XOR مجاز است.',
    hint: 'می‌توانید از XOR مستقیم استفاده کنید یا آن را از AND و OR و NOT بسازید.',
    expectedOutputs: <bool>[false, true, true, false],
    concepts: <String>['xor'],
  ),
  LearningChallenge(
    id: 'challenge_nor',
    title: 'گیت NOR بسازید',
    brief: 'مداری بسازید که خروجی تنها زمانی ۱ باشد که هر دو ورودی صفر باشند.',
    hint: 'NOR آماده است؛ در غیر این صورت OR را با NOT ترکیب کنید.',
    expectedOutputs: <bool>[true, false, false, false],
    allowedGates: <ComponentType>[
      ComponentType.norGate,
      ComponentType.orGate,
      ComponentType.notGate,
    ],
    concepts: <String>['nor'],
  ),
  LearningChallenge(
    id: 'challenge_xnor',
    title: 'گیت XNOR بسازید',
    brief:
        'مداری بسازید که خروجی آن ۱ باشد وقتی دو ورودی برابرند (۰,۰ یا ۱,۱).',
    hint: 'XNOR آماده است؛ در غیر این صورت XOR را با NOT ترکیب کنید.',
    expectedOutputs: <bool>[true, false, false, true],
    allowedGates: <ComponentType>[
      ComponentType.xnorGate,
      ComponentType.xorGate,
      ComponentType.notGate,
    ],
    concepts: <String>['xnor'],
  ),
  LearningChallenge(
    id: 'challenge_mixed',
    title: 'تابع ترکیبی',
    brief: 'مداری بسازید که خروجی آن وقتی ۱ باشد که A=1 و B=0 باشد؛ یعنی فقط حالت ۱۰ خروجی ۱ بدهد.',
    hint: 'برای حالت ۱۰ از AND با NOT روی B استفاده کنید و ورودی‌های دیگر را ببندید.',
    expectedOutputs: <bool>[false, false, true, false],
    concepts: <String>['and', 'not', 'sop'],
  ),
  LearningChallenge(
    id: 'challenge_implication',
    title: 'استلزام منطقی',
    brief: 'مداری بسازید که فقط در حالت A=1 و B=0 خروجی ۰ بدهد؛ در بقیهٔ حالت‌ها خروجی ۱ باشد.',
    hint: 'خروجی برابر است با NOT روی A، یا B. از یک OR و یک NOT استفاده کنید.',
    expectedOutputs: <bool>[true, true, false, true],
    concepts: <String>['not', 'or', 'sop'],
  ),
  LearningChallenge(
    id: 'challenge_equality',
    title: 'مقایسه‌گر برابری',
    brief: 'مداری بسازید که وقتی دو ورودی برابرند خروجی EQ برابر ۱ داشته باشد.',
    hint: 'برای برابری می‌توانید از XNOR استفاده کنید.',
    expectedOutputs: <bool>[true, false, false, true],
    outputLabels: <String>['EQ'],
    concepts: <String>['xnor', 'comparator'],
  ),
  LearningChallenge(
    id: 'challenge_half_adder',
    title: 'نیم‌جمع‌کننده',
    brief:
        'دو خروجی S (مجموع) و C (بابت حمل) بسازید تا A و B را جمع کند. '
        'خروجی‌ها از قبل با نام S و C ساخته شده‌اند.',
    hint: 'مجموع دو بیت همان XOR است و بابت حمل همان AND. یک XOR و یک AND بردارید.',
    expectedOutputs: <bool>[false, true, true, false],
    requiredOutputCount: 2,
    outputLabels: <String>['S', 'C'],
    expectedOutputsByLabel: <String, List<bool>>{
      'S': <bool>[false, true, true, false],
      'C': <bool>[false, false, false, true],
    },
    concepts: <String>['xor', 'and', 'half-adder'],
  ),
];
