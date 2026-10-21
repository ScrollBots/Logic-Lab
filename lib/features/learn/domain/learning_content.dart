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
    description:
        'خروجی تنها زمانی ۱ است که همه ورودی‌ها ۱ باشند. این دروازه معادل «و» در منطق ریاضی است.',
    useCase:
        'فعال‌سازی چند شرط هم‌زمان، مثل روشن شدن سیستم وقتی هم قفل بسته است و هم کلید فعال است.',
    truthTable: <bool>[false, false, false, true],
  ),
  GateDefinition(
    type: ComponentType.orGate,
    title: 'دروازه OR',
    expression: 'Y = A + B',
    description:
        'خروجی وقتی ۱ است که حداقل یکی از ورودی‌ها ۱ باشد. این دروازه معادل «یا» است.',
    useCase: 'فعال کردن زنگ هشدار از هر یک از چند حسگر.',
    truthTable: <bool>[false, true, true, true],
  ),
  GateDefinition(
    type: ComponentType.notGate,
    title: 'دروازه NOT',
    expression: 'Y = ¬A',
    description:
        'خروجی را معکوس می‌کند: ورودی ۱ به خروجی ۰ و ورودی ۰ به خروجی ۱ تبدیل می‌شود.',
    useCase: 'ساخت مدار نات (NAND) و نور (NOR) با کمترین قطعه.',
    truthTable: <bool>[true, true, false, false],
  ),
  GateDefinition(
    type: ComponentType.nandGate,
    title: 'دروازه NAND',
    expression: 'Y = ¬(A · B)',
    description:
        'معکوس خروجی AND است. در سخت‌افزار دیجیتال پرکاربرد است چون با NOR می‌توان هر تابعی را ساخت.',
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
    description:
        'خروجی ۱ است وقتی دو ورودی متفاوت باشند؛ یعنی تعداد ورودی‌های ۱ فرد باشد.',
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
class LearningLesson {
  const LearningLesson({
    required this.id,
    required this.title,
    required this.summary,
    required this.body,
    required this.minutes,
    this.gateType,
  });

  final String id;
  final String title;
  final String summary;
  final List<String> body;
  final int minutes;
  final ComponentType? gateType;
}

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
}

const List<LearningLesson> kLessons = <LearningLesson>[
  LearningLesson(
    id: 'lesson_signals',
    title: 'سیگنال دیجیتال چیست؟',
    summary: 'سطوح ۰ و ۱ و معنای آن‌ها در مدارهای منطقی',
    minutes: 4,
    body: <String>[
      'در الکترونیک دیجیتال، اطلاعات با دو سطح ولتاژ نمایش داده می‌شود: پایین (۰) و بالا (۱). '
          'هر سیگنال در هر لحظه دقیقاً یکی از این دو مقدار را دارد.',
      'این دو مقدار با صفر و یک منطقی نیز نمایش داده می‌شوند. ۱ یعنی «درست/فعال» و ۰ یعنی «نادرست/غیرفعال».',
      'در این برنامه، ورودی‌ها کلید دوحالته‌اند. با ضربه زدن روی آن‌ها مقدارشان بین ۰ و ۱ تغییر می‌کند '
          'و خروجی مدار بلافاصله دوباره محاسبه می‌شود.',
      'اگر ورودی‌ای به قطعه‌ای وصل نباشد، مقدار آن «نامشخص» در نظر گرفته می‌شود. '
          'مدار نامعتبر هرگز نتیجه قطعی نمایش نمی‌دهد.',
    ],
  ),
  LearningLesson(
    id: 'lesson_wiring',
    title: 'سیم‌کشی درست',
    summary: 'پایه خروجی، پایه ورودی و قواعد اتصال',
    minutes: 5,
    body: <String>[
      'هر قطعه یک یا چند پایه ورودی دارد و بیشتر آن‌ها یک پایه خروجی. سیگنال فقط از پایه خروجی '
          'به پایه ورودی جریان پیدا می‌کند.',
      'برای اتصال: ابتدا پایه خروجی را انتخاب کنید، سپس پایه ورودی مقصد را بزنید. '
          'پایه‌های معتبر در همان لحظه برجسته می‌شوند.',
      'اتصال‌های نامعتبر مانند اتصال خروجی به خروجی، اتصال دو سیم به یک پایه، یا ساختن چرخه '
          'ترکیبی رد می‌شوند و پیام راهنما نمایش داده می‌شود.',
      'اگر دروازه‌ای حتی یک ورودی متصل نداشته باشد، مدار نامعتبر است و مقدار آن نامشخص باقی می‌ماند.',
    ],
  ),
  LearningLesson(
    id: 'lesson_and',
    title: 'دروازه AND',
    summary: 'و منطقی و جدول حقیقت آن',
    minutes: 4,
    gateType: ComponentType.andGate,
    body: <String>[
      'دروازه AND وقتی خروجی ۱ می‌دهد که همه ورودی‌ها ۱ باشند. در بقیه حالت‌ها خروجی صفر است.',
      'جدول حقیقت AND با دو ورودی فقط یک ردیف با خروجی ۱ دارد: حالتی که هر دو ورودی ۱ هستند.',
      'اگر یک مدار AND را بسازید و جدول حقیقت آن را با دروازه AND مقایسه کنید، دقیقاً یکسان خواهد بود.',
    ],
  ),
  LearningLesson(
    id: 'lesson_or_not',
    title: 'دروازه‌های OR و NOT',
    summary: 'یا منطقی و معکوس‌کننده',
    minutes: 4,
    gateType: ComponentType.orGate,
    body: <String>[
      'دروازه OR زمانی خروجی ۱ می‌دهد که حداقل یک ورودی ۱ باشد.',
      'دروازه NOT تنها یک ورودی دارد و خروجی را معکوس می‌کند. از NOT برای ساخت NAND و NOR استفاده می‌شود.',
      'ترکیب NOT با AND یا OR یکی از پرکاربردترین الگوهای طراحی مدار است.',
    ],
  ),
  LearningLesson(
    id: 'lesson_composite',
    title: 'دروازه‌های مرکب',
    summary: 'NAND، NOR، XOR و XNOR',
    minutes: 6,
    gateType: ComponentType.xorGate,
    body: <String>[
      'NAND معکوس AND است و NOR معکوس OR. هر دو با یک ورودی فعال (مثلاً ۰) سیگنال فعال می‌دهند.',
      'XOR تنها وقتی ۱ است که دو ورودی متفاوت باشند؛ یعنی تعداد ورودی‌های ۱ فرد باشد. '
          'XNOR معکوس آن است.',
      'اگر دروازه XOR را به‌صورت AND و NOT بسازید، جدول حقیقت نهایی باید دقیقاً با XOR یکسان شود.',
    ],
  ),
  LearningLesson(
    id: 'lesson_decomposition',
    title: 'شکستن مدار به گیت',
    summary: 'ساخت هر تابع منطقی از گیت‌های پایه',
    minutes: 7,
    body: <String>[
      'هر تابع منطقی دودویی را می‌توان فقط با گیت‌های NAND ساخت. این اصل پایه صنعت سخت‌افزار دیجیتال است.',
      'برای تمرین، ابتدا جدول حقیقت تابع را بنویسید، سپس برای هر ردیفی که خروجی ۱ دارد یک جمله '
          'بسازید و آن‌ها را با OR ترکیب کنید.',
      'اگر نمی‌توانید مستقیم گیت NAND بسازید، ابتدا AND و NOT را بسازید و سپس آن‌ها را به NAND تبدیل کنید.',
    ],
  ),
];

const List<LearningChallenge> kChallenges = <LearningChallenge>[
  LearningChallenge(
    id: 'challenge_and',
    title: 'گیت AND بسازید',
    brief:
        'با دو ورودی A و B و یک خروجی، مداری بسازید که فقط وقتی هر دو ورودی ۱ باشند خروجی ۱ شود.',
    hint: 'یک دروازه AND کافی است؛ هر دو ورودی را به آن وصل کنید.',
    expectedOutputs: <bool>[false, false, false, true],
    allowedGates: <ComponentType>[ComponentType.andGate],
  ),
  LearningChallenge(
    id: 'challenge_xor',
    title: 'گیت XOR بسازید',
    brief:
        'مداری بسازید که خروجی آن فقط وقتی ۱ باشد که دو ورودی متفاوت باشند. استفاده از گیت XOR مجاز است.',
    hint: 'می‌توانید از XOR مستقیم استفاده کنید یا آن را از AND و NOT بسازید.',
    expectedOutputs: <bool>[false, true, true, false],
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
  ),
  LearningChallenge(
    id: 'challenge_mixed',
    title: 'تابع ترکیبی',
    brief:
        'مداری بسازید که خروجی آن وقتی ۱ باشد که A=1 و B=0 باشد؛ یعنی فقط حالت ۱۰ خروجی ۱ بدهد.',
    hint:
        'برای حالت ۱۰ از AND با NOT روی B استفاده کنید و ورودی‌های دیگر را ببندید.',
    expectedOutputs: <bool>[false, false, true, false],
  ),
];

@immutable
class LearningPath {
  const LearningPath({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.level,
    required this.lessonIds,
    required this.challengeIds,
  });

  final String id;
  final String title;
  final String subtitle;
  final int level;
  final List<String> lessonIds;
  final List<String> challengeIds;
}

const List<LearningPath> kLearningPaths = <LearningPath>[
  LearningPath(
    id: 'path_beginner',
    title: 'شروع از صفر',
    subtitle: 'سیگنال، سیم و سه گیت پایه',
    level: 1,
    lessonIds: <String>['lesson_signals', 'lesson_wiring', 'lesson_and'],
    challengeIds: <String>['challenge_and'],
  ),
  LearningPath(
    id: 'path_intermediate',
    title: 'گیت‌های ترکیبی',
    subtitle: 'NOT، OR و مدارهای مرکب',
    level: 2,
    lessonIds: <String>['lesson_or_not', 'lesson_composite'],
    challengeIds: <String>['challenge_nor', 'challenge_xor'],
  ),
  LearningPath(
    id: 'path_advanced',
    title: 'طراحی تابع',
    subtitle: 'شکستن تابع منطقی به گیت‌های پایه',
    level: 3,
    lessonIds: <String>['lesson_decomposition'],
    challengeIds: <String>['challenge_xnor', 'challenge_mixed'],
  ),
];
