import '../../editor/domain/circuit_models.dart';
import 'learning_content.dart';
import 'lesson_models.dart';

/// The complete, offline curriculum.
///
/// Lessons keep the ids of the previous version where the subject is the same,
/// so progress made before this redesign is not lost. Units are ordered: a
/// lesson unlocks only after the previous lesson has been completed.
final List<LearningUnit> kCurriculum = <LearningUnit>[
  LearningUnit(
    id: 'unit_basics',
    title: 'پایه‌ها',
    subtitle: 'سیگنال، سیم و اولین مدار',
    lessons: <LearningLesson>[
      LearningLesson(
        id: 'lesson_signals',
        title: 'سیگنال دیجیتال',
        subtitle: 'معنای ۰ و ۱ در مدار',
        minutes: 3,
        steps: <LessonStep>[
          ConceptStep(
            id: 'signals_concept',
            title: 'فقط دو حالت',
            objective: 'بفهمید هر سیگنال دیجیتال در هر لحظه فقط یک مقدار دارد.',
            concepts: <String>['signal'],
            paragraphs: <String>[
              'در الکترونیک دیجیتال اطلاعات با دو سطح ولتاژ نمایش داده می‌شود: پایین (۰) و بالا (۱). '
                  'هر سیم در هر لحظه دقیقاً یکی از این دو مقدار را دارد.',
              'منطق ۰ را «نادرست» یا «غیرفعال» و منطق ۱ را «درست» یا «فعال» می‌خوانیم. '
                  'این نام‌ها فقط یک قرارداد هستند؛ مقدار الکتریکی همان ولتاژ است.',
              'همین دو حالت برای ساختن جدول حقیقت، حافظه و پردازنده کافی است.',
            ],
            explanation: 'خلاصه: یک سیگنال دیجیتال همیشه ۰ یا ۱ است؛ هرگز هم‌زمان هر دو.',
          ),
          ConceptStep(
            id: 'signals_switches',
            title: 'کلیدها، ورودی و خروجی',
            objective: 'بدانید در این برنامه ورودی‌ها چگونه تغییر می‌کنند.',
            concepts: <String>['signal'],
            paragraphs: <String>[
              'ورودی‌های مدار کلید دوحالته‌اند. با ضربه زدن روی کلید، مقدار آن بین ۰ و ۱ عوض می‌شود.',
              'خروجی هر گیت از ورودی‌هایش محاسبه می‌شود. اگر ورودی‌ای به جایی وصل نباشد، '
                  'مقدار آن «نامشخص» می‌ماند و برنامه نتیجهٔ قطعی نشان نمی‌دهد.',
              'در بخش آزمایشگاه می‌توانید ورودی‌ها را زنده تغییر دهید و اثر آن را روی خروجی ببینید.',
            ],
            explanation:
                'قاعدهٔ مهم: بدون ورودی معتبر، خروجی معتبری وجود ندارد.',
          ),
          PredictionStep(
            id: 'signals_predict_buffer',
            title: 'حدس بزنید',
            objective: 'خروجی یک بافر را وقتی ورودی آن ۱ است پیش‌بینی کنید.',
            concepts: <String>['signal', 'buffer'],
            circuit: gateExercise(ComponentType.bufferGate),
            inputs: <String, bool>{'A': true},
            hints: <String>[
              'بافر هیچ کاری با سیگنال نمی‌کند؛ آن را همان‌طور که هست جلو می‌فرستد.',
            ],
            explanation:
                'بافر مقدار ورودی را بدون تغییر منتقل می‌کند. پس ورودی ۱ یعنی خروجی ۱. '
                'کاربرد اصلی بافر تقویت سیگنال و جداسازی بخش‌های مدار است.',
          ),
          GateChoiceStep(
            id: 'signals_choose_buffer',
            title: 'قطعهٔ مناسب',
            objective:
                'قطعه‌ای را انتخاب کنید که سیگنال را بدون تغییر منتقل می‌کند.',
            concepts: <String>['signal', 'buffer'],
            options: <ComponentType>[
              ComponentType.andGate,
              ComponentType.orGate,
              ComponentType.notGate,
              ComponentType.bufferGate,
            ],
            correct: ComponentType.bufferGate,
            behavior: gateExercise(ComponentType.bufferGate),
            showBehaviorTable: false,
            hints: <String>[
              'AND و OR خروجی را بر اساس هر دو ورودی تغییر می‌دهند.',
              'NOT مقدار را معکوس می‌کند؛ ما دنبال تغییر نکردن هستیم.',
            ],
            explanation: 'بافر خروجی را برابر ورودی نگه می‌دارد. سه گیت دیگر همیشه ورودی را دگرگون می‌کنند.',
          ),
        ],
      ),
      LearningLesson(
        id: 'lesson_wiring',
        title: 'سیم‌کشی درست',
        subtitle: 'پایه خروجی، پایه ورودی و اولین مدار',
        minutes: 5,
        steps: <LessonStep>[
          ConceptStep(
            id: 'wiring_ports',
            title: 'جهت سیگنال',
            objective: 'یاد بگیرید سیگنال از کدام پایه به کدام پایه می‌رود.',
            concepts: <String>['wiring'],
            gateType: ComponentType.andGate,
            paragraphs: <String>[
              'هر قطعه یک یا چند پایهٔ ورودی و معمولاً یک پایهٔ خروجی دارد. '
                  'سیگنال فقط از خروجی یک قطعه به ورودی قطعهٔ بعدی می‌رود.',
              'برای سیم‌کشی، ابتدا پایهٔ خروجی را انتخاب کنید و سپس پایهٔ ورودی مقصد را بزنید. '
                  'پایه‌های معتبر در همان لحظه روی بوم برجسته می‌شوند.',
              'در ویرایشگر، هر اتصال پیش از ثبت با قوانین مدار بررسی می‌شود.',
            ],
            explanation: 'سیگنال همیشه یک‌طرفه است: خروجی ← ورودی.',
          ),
          ConceptStep(
            id: 'wiring_rules',
            title: 'اتصال‌های ردشده',
            objective: 'بدانید چه اتصالی مدار را نامعتبر می‌کند.',
            concepts: <String>['wiring'],
            paragraphs: <String>[
              'اتصال خروجی به خروجی، اتصال دو سیم به یک پایهٔ ورودی، و ساختن چرخهٔ ترکیبی '
                  'بدون عنصر حافظه مجاز نیستند.',
              'اگر ورودی گیتی خالی بماند، خروجی آن نامشخص است و مدار نامعتبر می‌شود.',
              'این محدودیت‌ها از نمایش نتیجهٔ گمراه‌کننده جلوگیری می‌کنند.',
            ],
            explanation: 'اتصال معتبر همیشه از خروجی به ورودی است و هر ورودی فقط یک منبع دارد.',
          ),
          TextChoiceStep(
            id: 'wiring_choose_connection',
            title: 'کدام اتصال؟',
            objective: 'اتصال مجاز را از بین گزینه‌ها انتخاب کنید.',
            concepts: <String>['wiring'],
            options: <LessonOption>[
              LessonOption(
                text: 'از پایهٔ خروجی گیت به پایهٔ ورودی قطعهٔ بعدی',
                correct: true,
              ),
              LessonOption(
                text: 'از پایهٔ ورودی گیت به پایهٔ ورودی قطعهٔ بعدی',
                correct: false,
              ),
              LessonOption(
                text: 'از پایهٔ خروجی گیت به پایهٔ خروجی قطعهٔ بعدی',
                correct: false,
              ),
            ],
            hints: <String>[
              'فقط یک پایه سیگنال تولید می‌کند و فقط یک پایه آن را می‌پذیرد.',
            ],
            explanation: 'سیگنال از خروجی تولید می‌شود و به ورودی می‌رسد. دو گزینهٔ دیگر جهت سیگنال را نقض می‌کنند.',
          ),
          BuildCircuitStep(
            id: 'wiring_build',
            title: 'اولین مدار را بسازید',
            objective: 'در ویرایشگر، ورودی A را بدون تغییر به خروجی Y برسانید.',
            concepts: <String>['wiring', 'buffer'],
            challengeId: 'challenge_buffer',
            hints: <String>[
              'یک بافر روی بوم بگذارید.',
              'خروجی A را به ورودی بافر و خروجی بافر را به Y وصل کنید.',
            ],
            explanation:
                'مدار شما با شبیه‌ساز واقعی سنجیده می‌شود. اگر بافر درست وصل شده باشد، '
                'خروجی همیشه برابر A خواهد بود.',
          ),
        ],
      ),
    ],
  ),
  LearningUnit(
    id: 'unit_basic_gates',
    title: 'دروازه‌های پایه',
    subtitle: 'AND، OR و NOT',
    lessons: <LearningLesson>[
      LearningLesson(
        id: 'lesson_and',
        title: 'دروازه AND',
        subtitle: 'و منطقی و جدول حقیقت',
        minutes: 4,
        steps: <LessonStep>[
          ConceptStep(
            id: 'and_concept',
            title: 'همه‌چیز یا هیچ‌چیز',
            objective: 'قاعدهٔ AND را یاد بگیرید.',
            concepts: <String>['and'],
            gateType: ComponentType.andGate,
            paragraphs: <String>[
              'خروجی AND تنها زمانی ۱ است که همهٔ ورودی‌ها ۱ باشند. اگر حتی یک ورودی ۰ باشد، '
                  'خروجی ۰ می‌شود.',
              'این گیت معادل «و» در زبان است: چراغ روشن می‌شود اگر کلید روشن باشد و حسگر حرکت را ببیند.',
              'با دو ورودی، فقط یک ردیف از چهار ردیف جدول حقیقت خروجی ۱ دارد.',
            ],
            explanation: 'AND = همهٔ ورودی‌ها باید ۱ باشند.',
          ),
          TruthTableStep(
            id: 'and_table',
            title: 'جدول حقیقت AND',
            objective: 'ستون خروجی Y را برای همهٔ ردیف‌ها کامل کنید.',
            concepts: <String>['and', 'truth-table'],
            circuit: gateExercise(ComponentType.andGate),
            hints: <String>['فقط ردیفی که A و B هر دو ۱ هستند خروجی ۱ دارد.'],
            explanation:
                'تنها ردیف A=1,B=1 خروجی ۱ دارد. این تعریف کامل AND است.',
          ),
          PredictionStep(
            id: 'and_predict',
            title: 'حدس بزنید',
            objective: 'خروجی AND را برای A=1 و B=1 پیش‌بینی کنید.',
            concepts: <String>['and'],
            circuit: gateExercise(ComponentType.andGate),
            inputs: <String, bool>{'A': true, 'B': true},
            hints: <String>['هر دو ورودی ۱ هستند؛ شرط AND برقرار است.'],
            explanation: 'وقتی هر دو ورودی ۱ باشند، AND خروجی ۱ می‌دهد.',
          ),
          BuildCircuitStep(
            id: 'and_build',
            title: 'AND را بسازید',
            objective: 'در ویرایشگر یک گیت AND با دو ورودی بسازید.',
            concepts: <String>['and'],
            challengeId: 'challenge_and',
            hints: <String>[
              'یک گیت AND روی بوم قرار دهید.',
              'هر دو ورودی A و B را به آن وصل کنید و خروجی گیت را به Y ببرید.',
            ],
            explanation: 'مدار شما با شبیه‌ساز بررسی می‌شود؛ اگر جدول خروجی با AND یکسان باشد، قبول است.',
          ),
        ],
      ),
      LearningLesson(
        id: 'lesson_or_not',
        title: 'دروازه‌های OR و NOT',
        subtitle: 'یا منطقی و معکوس‌کننده',
        minutes: 5,
        steps: <LessonStep>[
          ConceptStep(
            id: 'or_concept',
            title: 'کافی است یکی',
            objective: 'قاعدهٔ OR را یاد بگیرید.',
            concepts: <String>['or'],
            gateType: ComponentType.orGate,
            paragraphs: <String>[
              'خروجی OR وقتی ۱ است که حداقل یکی از ورودی‌ها ۱ باشد. '
                  'تنها زمانی ۰ می‌شود که همهٔ ورودی‌ها ۰ باشند.',
              'OR برای جمع‌کردن هشدارها و فعال‌سازی از چند منبع استفاده می‌شود.',
              'تفاوت آن با XOR در این است که OR با دو ورودی ۱ هم خروجی ۱ می‌دهد.',
            ],
            explanation: 'OR = حداقل یک ورودی ۱.',
          ),
          TruthTableStep(
            id: 'or_table',
            title: 'جدول حقیقت OR',
            objective: 'ستون خروجی OR را کامل کنید.',
            concepts: <String>['or', 'truth-table'],
            circuit: gateExercise(ComponentType.orGate),
            hints: <String>['فقط ردیف A=0,B=0 خروجی ۰ دارد.'],
            explanation:
                'سه ردیف اول خروجی ۱ دارند و فقط ردیف A=0,B=0 خروجی ۰ است.',
          ),
          ConceptStep(
            id: 'not_concept',
            title: 'معکوس‌کننده',
            objective: 'یاد بگیرید NOT چه کاری می‌کند.',
            concepts: <String>['not'],
            gateType: ComponentType.notGate,
            paragraphs: <String>[
              'NOT تنها یک ورودی دارد و خروجی را برعکس می‌کند: ۰ به ۱ و ۱ به ۰.',
              'در عبارت‌های بولی، NOT را با ¬ یا خط روی متغیر نشان می‌دهیم.',
              'NOT پایهٔ ساخت NAND، NOR و بسیاری از مدارهای دیگر است.',
            ],
            explanation: 'NOT = برعکس کردن مقدار ورودی.',
          ),
          PredictionStep(
            id: 'not_predict',
            title: 'حدس بزنید',
            objective: 'خروجی NOT را برای ورودی ۰ پیش‌بینی کنید.',
            concepts: <String>['not'],
            circuit: gateExercise(ComponentType.notGate),
            inputs: <String, bool>{'A': false},
            hints: <String>['NOT مقدار را برعکس می‌کند.'],
            explanation: 'ورودی ۰ با NOT به ۱ تبدیل می‌شود.',
          ),
          BuildCircuitStep(
            id: 'or_build',
            title: 'OR را بسازید',
            objective: 'در ویرایشگر گیت OR را با دو ورودی بسازید.',
            concepts: <String>['or'],
            challengeId: 'challenge_or',
            hints: <String>[
              'یک گیت OR روی بوم بگذارید.',
              'A و B را به ورودی‌های آن و خروجی گیت را به Y وصل کنید.',
            ],
            explanation: 'اگر خروجی مدار تنها در حالت A=0,B=0 صفر باشد، مدار OR درست ساخته شده است.',
          ),
        ],
      ),
    ],
  ),
  LearningUnit(
    id: 'unit_composite_gates',
    title: 'دروازه‌های مرکب',
    subtitle: 'NAND، NOR، XOR و XNOR',
    lessons: <LearningLesson>[
      LearningLesson(
        id: 'lesson_composite',
        title: 'NAND، NOR و XOR',
        subtitle: 'معکوس‌ها و تفاوت',
        minutes: 6,
        steps: <LessonStep>[
          ConceptStep(
            id: 'composite_concept',
            title: 'معکوسِ AND و OR',
            objective: 'NAND و NOR را بشناسید.',
            concepts: <String>['nand', 'nor'],
            gateType: ComponentType.nandGate,
            paragraphs: <String>[
              'NAND خروجی AND را معکوس می‌کند؛ فقط وقتی هر دو ورودی ۱ باشند خروجی ۰ است.',
              'NOR خروجی OR را معکوس می‌کند؛ فقط وقتی هر دو ورودی ۰ باشند خروجی ۱ است.',
              'NAND و NOR هر دو «دروازهٔ جهانی» هستند: با تکرار یکی از آن‌ها می‌توان هر تابع منطقی را ساخت.',
            ],
            explanation: 'NAND = ¬(A·B) و NOR = ¬(A+B).',
          ),
          TruthTableStep(
            id: 'nand_table',
            title: 'جدول حقیقت NAND',
            objective: 'ستون خروجی NAND را کامل کنید.',
            concepts: <String>['nand', 'truth-table'],
            circuit: gateExercise(ComponentType.nandGate),
            hints: <String>['NAND دقیقاً برعکس AND است.'],
            explanation:
                'تنها ردیف A=1,B=1 خروجی ۰ دارد؛ بقیهٔ ردیف‌ها ۱ هستند.',
          ),
          PredictionStep(
            id: 'nor_predict',
            title: 'حدس بزنید',
            objective: 'خروجی NOR را برای A=0 و B=0 پیش‌بینی کنید.',
            concepts: <String>['nor'],
            circuit: gateExercise(ComponentType.norGate),
            inputs: <String, bool>{'A': false, 'B': false},
            hints: <String>['NOR وقتی ۱ می‌دهد که همهٔ ورودی‌ها ۰ باشند.'],
            explanation: 'در NOR، هر دو ورودی ۰ به خروجی ۱ منجر می‌شود.',
          ),
          GateChoiceStep(
            id: 'xor_choose',
            title: 'گیت تفاوت',
            objective:
                'گیتی را انتخاب کنید که ورودی‌های متفاوت را تشخیص می‌دهد.',
            concepts: <String>['xor'],
            options: <ComponentType>[
              ComponentType.andGate,
              ComponentType.orGate,
              ComponentType.xorGate,
              ComponentType.norGate,
            ],
            correct: ComponentType.xorGate,
            behavior: gateExercise(ComponentType.xorGate),
            showBehaviorTable: false,
            hints: <String>[
              'OR با دو ورودی ۱ هم خروجی ۱ می‌دهد؛ ما خروجی ۰ می‌خواهیم.',
              'به گیتی فکر کنید که «یا یکی یا دیگری» را نشان می‌دهد.',
            ],
            explanation: 'XOR تنها وقتی ۱ است که ورودی‌ها متفاوت باشند. OR برای دو ورودی ۱ هم ۱ می‌دهد.',
          ),
          BuildCircuitStep(
            id: 'xor_build',
            title: 'XOR را بسازید',
            objective: 'مداری بسازید که خروجی آن تفاوت دو ورودی را نشان دهد.',
            concepts: <String>['xor'],
            challengeId: 'challenge_xor',
            hints: <String>[
              'می‌توانید مستقیماً از XOR استفاده کنید.',
              'یا XOR را با AND، OR و NOT بسازید.',
            ],
            explanation: 'هر مداری که جدول حقیقت XOR را تولید کند پذیرفته می‌شود؛ شبیه‌ساز همهٔ چهار حالت را بررسی می‌کند.',
          ),
        ],
      ),
      LearningLesson(
        id: 'lesson_universal',
        title: 'XNOR و ساخت از گیت‌ها',
        subtitle: 'مقایسهٔ برابری',
        minutes: 5,
        steps: <LessonStep>[
          ConceptStep(
            id: 'universal_concept',
            title: 'از NAND تا هر مدار',
            objective: 'ببینید چگونه گیت‌های ساده مدارهای پیچیده می‌سازند.',
            concepts: <String>['nand'],
            gateType: ComponentType.nandGate,
            paragraphs: <String>[
              'با NAND می‌توان NOT، AND، OR و در نهایت هر تابع منطقی را ساخت.',
              'به همین دلیل NAND در سخت‌افزار واقعی بسیار پرکاربرد است.',
              'XNOR معکوس XOR است: وقتی خروجی ۱ می‌دهد که دو ورودی برابر باشند.',
            ],
            explanation: 'ترکیب گیت‌ها همان کاری است که ویرایشگر انجام می‌دهد؛ هر گیت خروجی خود را به ورودی بعدی می‌دهد.',
          ),
          TruthTableStep(
            id: 'xnor_table',
            title: 'جدول حقیقت XNOR',
            objective: 'ستون خروجی XNOR را کامل کنید.',
            concepts: <String>['xnor', 'truth-table'],
            circuit: gateExercise(ComponentType.xnorGate),
            hints: <String>['XNOR دقیقاً برعکس XOR است.'],
            explanation: 'ردیف‌های A=0,B=0 و A=1,B=1 خروجی ۱ دارند؛ دو ردیف دیگر ۰ هستند.',
          ),
          PredictionStep(
            id: 'xnor_built_predict',
            title: 'مدار مرکب',
            objective: 'خروجی مداری از AND، OR و NOT را پیش‌بینی کنید.',
            concepts: <String>['xnor', 'and', 'or', 'not'],
            circuit: xnorFromGatesExercise(),
            inputs: <String, bool>{'A': true, 'B': false},
            hints: <String>[
              'وقتی A=1 و B=0 باشد، جملهٔ A·B صفر و جملهٔ A̅·B̅ هم صفر است.',
            ],
            explanation: 'هر دو جملهٔ AND صفر می‌شوند و OR خروجی ۰ می‌دهد. این مدار همان XNOR است.',
          ),
          BuildCircuitStep(
            id: 'xnor_build',
            title: 'XNOR را بسازید',
            objective: 'مداری بسازید که تساوی دو ورودی را تشخیص دهد.',
            concepts: <String>['xnor'],
            challengeId: 'challenge_xnor',
            hints: <String>[
              'XNOR آماده را امتحان کنید یا XOR را با NOT ترکیب کنید.',
            ],
            explanation: 'اگر خروجی فقط در حالت‌های ۰۰ و ۱۱ برابر ۱ باشد، مدار رفتار XNOR دارد.',
          ),
        ],
      ),
    ],
  ),
  LearningUnit(
    id: 'unit_functions',
    title: 'از جدول تا تابع',
    subtitle: 'خواندن جدول حقیقت و طراحی تابع',
    lessons: <LearningLesson>[
      LearningLesson(
        id: 'lesson_truth_table',
        title: 'جدول حقیقت',
        subtitle: 'خواندن رفتار مدار',
        minutes: 6,
        steps: <LessonStep>[
          ConceptStep(
            id: 'table_concept',
            title: 'جدول، شناسنامهٔ مدار',
            objective: 'یاد بگیرید جدول حقیقت چه اطلاعاتی می‌دهد.',
            concepts: <String>['truth-table'],
            paragraphs: <String>[
              'جدول حقیقت همهٔ ترکیب‌های ممکن ورودی و خروجی متناظرشان را نشان می‌دهد.',
              'با n ورودی، جدول ۲ به توان n ردیف دارد. برای دو ورودی، چهار ردیف داریم.',
              'اگر دو مدار جدول حقیقت یکسان داشته باشند، از نظر منطقی هم‌ارز هستند؛ '
                  'حتی اگر تعداد گیت‌هایشان متفاوت باشد.',
            ],
            explanation: 'دو مدار هم‌ارز، جدول حقیقت یکسان دارند.',
          ),
          TruthTableStep(
            id: 'table_simplify',
            title: 'مدار ساده‌تر از ظاهرش',
            objective: 'جدول مداری را کامل کنید که به نظر پیچیده می‌آید.',
            concepts: <String>['truth-table', 'and', 'or', 'not'],
            circuit: combiningExercise(),
            hints: <String>[
              'هر دو جملهٔ AND را جدا حساب کنید.',
              'وقتی A=0 باشد، هر دو جمله ۰ می‌شوند؛ وقتی A=1 باشد، یکی از آن‌ها ۱ می‌شود.',
            ],
            explanation:
                'خروجی این مدار برابر خود A است: A·B + A·B̅ = A. '
                'جدول حقیقت همین را نشان می‌دهد و ثابت می‌کند مدار بافر است.',
          ),
          PredictionStep(
            id: 'table_predict',
            title: 'حدس بزنید',
            objective: 'با استفاده از جدول، خروجی مدار را برای A=0 و B=1 پیش‌بینی کنید.',
            concepts: <String>['truth-table', 'and', 'or', 'not'],
            circuit: combiningExercise(),
            inputs: <String, bool>{'A': false, 'B': true},
            hints: <String>[
              'جملهٔ A·B صفر است چون A=0 است.',
              'جملهٔ A·B̅ هم صفر است. OR دو صفر برابر صفر است.',
            ],
            explanation: 'هر دو جملهٔ AND صفر می‌شوند، پس خروجی ۰ است. این همان رفتار بافر با ورودی A=0 است.',
          ),
          BuildCircuitStep(
            id: 'table_build',
            title: 'تابع تک‌حالته',
            objective: 'تابعی بسازید که فقط در حالت A=1,B=0 خروجی ۱ بدهد.',
            concepts: <String>['sop', 'and', 'not'],
            challengeId: 'challenge_mixed',
            hints: <String>[
              'برای هر ردیف با خروجی ۱ یک جملهٔ AND بسازید.',
              'در حالت ۱۰، B باید معکوس شود.',
            ],
            explanation: 'این تابع «مین‌ترم» نام دارد: یک جملهٔ AND که همهٔ ورودی‌ها را دقیقاً برای یک حالت تعیین می‌کند.',
          ),
        ],
      ),
      LearningLesson(
        id: 'lesson_decomposition',
        title: 'طراحی تابع',
        subtitle: 'از جدول به عبارت و مدار',
        minutes: 7,
        steps: <LessonStep>[
          ConceptStep(
            id: 'sop_concept',
            title: 'از ردیف‌ها تا عبارت',
            objective: 'روش ساختن عبارت از جدول حقیقت را یاد بگیرید.',
            concepts: <String>['sop'],
            paragraphs: <String>[
              'برای هر ردیفی که خروجی ۱ دارد، یک جملهٔ AND بسازید؛ متغیرهایی که ۰ هستند را NOT کنید.',
              'سپس جمله‌ها را با OR ترکیب کنید. این شکل، «مجموع حاصل‌ضرب‌ها» یا SOP نام دارد.',
              'همین روش برای هر تابع منطقی کار می‌کند و نیازی به حدس زدن ندارد.',
            ],
            explanation: 'هر ردیف با خروجی ۱ یک جمله می‌سازد؛ OR جمله‌ها تابع را کامل می‌کند.',
          ),
          TextChoiceStep(
            id: 'sop_expression',
            title: 'عبارت درست',
            objective: 'برای تابع داده‌شده، عبارت درست را انتخاب کنید.',
            concepts: <String>['sop', 'not', 'or'],
            behavior: implicationExercise(),
            options: <LessonOption>[
              LessonOption(text: 'Y = ¬A + B', correct: true, technical: true),
              LessonOption(text: 'Y = A + ¬B', correct: false, technical: true),
              LessonOption(text: 'Y = A · B', correct: false, technical: true),
              LessonOption(text: 'Y = A ⊕ B', correct: false, technical: true),
            ],
            hints: <String>[
              'تابع فقط در حالت A=1,B=0 خروجی ۰ دارد.',
              'ردیف‌های خروجی ۱ را بنویسید و جمله‌ها را OR کنید؛ نتیجه ساده می‌شود.',
            ],
            explanation:
                'تابع در همهٔ حالت‌ها به‌جز A=1,B=0 خروجی ۱ دارد؛ یعنی ¬A + B. '
                'این همان استلزام منطقی A → B است.',
          ),
          PredictionStep(
            id: 'sop_predict',
            title: 'حدس بزنید',
            objective: 'خروجی مدار ¬A + B را برای A=1 و B=0 پیش‌بینی کنید.',
            concepts: <String>['not', 'or', 'sop'],
            circuit: implicationExercise(),
            inputs: <String, bool>{'A': true, 'B': false},
            hints: <String>['¬A برابر ۰ و B هم ۰ است.'],
            explanation: 'OR دو مقدار ۰ خروجی ۰ می‌دهد. این تنها حالتی است که استلزام نادرست می‌شود.',
          ),
          BuildCircuitStep(
            id: 'sop_build',
            title: 'استلزام را بسازید',
            objective: 'مداری بسازید که فقط در حالت A=1,B=0 خروجی ۰ دهد.',
            concepts: <String>['sop', 'not', 'or'],
            challengeId: 'challenge_implication',
            hints: <String>[
              'به NOT روی A و سپس OR با B نیاز دارید.',
              'خروجی OR را به Y وصل کنید.',
            ],
            explanation: 'هر ترکیب معتبری از گیت‌ها پذیرفته می‌شود؛ مهم این است که جدول حقیقت تابع درست باشد.',
          ),
        ],
      ),
    ],
  ),
  LearningUnit(
    id: 'unit_real_circuits',
    title: 'مدارهای واقعی',
    subtitle: 'نیم‌جمع‌کننده و مقایسه‌گر',
    lessons: <LearningLesson>[
      LearningLesson(
        id: 'lesson_half_adder',
        title: 'نیم‌جمع‌کننده',
        subtitle: 'جمع دو بیت',
        minutes: 6,
        steps: <LessonStep>[
          ConceptStep(
            id: 'half_adder_concept',
            title: 'جمع در دنیای دودویی',
            objective: 'ببینید جمع دو بیت چگونه به XOR و AND تبدیل می‌شود.',
            concepts: <String>['half-adder'],
            paragraphs: <String>[
              'برای جمع دو بیت A و B، خروجی S (مجموع) و C (بابت حمل) داریم.',
              'وقتی هر دو ورودی ۰ باشند مجموع ۰ است؛ وقتی متفاوت باشند مجموع ۱ و '
                  'وقتی هر دو ۱ باشند مجموع ۰ با بابت حمل ۱ است.',
              'این رفتار دقیقاً همان XOR برای S و AND برای C است.',
            ],
            explanation: 'نیم‌جمع‌کننده = XOR برای مجموع + AND برای بابت حمل.',
          ),
          TruthTableStep(
            id: 'half_adder_sum_table',
            title: 'ستون مجموع',
            objective: 'ستون S نیم‌جمع‌کننده را کامل کنید.',
            concepts: <String>['half-adder', 'xor', 'truth-table'],
            circuit: gateExercise(ComponentType.xorGate),
            hints: <String>['مجموع دو بیت همان XOR است.'],
            explanation:
                'S برای ورودی‌های برابر ۰ و برای ورودی‌های متفاوت ۱ است.',
          ),
          PredictionStep(
            id: 'half_adder_carry',
            title: 'حدس بزنید',
            objective: 'وقتی هر دو بیت ۱ هستند، خروجی C را پیش‌بینی کنید.',
            concepts: <String>['half-adder', 'and'],
            circuit: gateExercise(ComponentType.andGate),
            inputs: <String, bool>{'A': true, 'B': true},
            hints: <String>[
              'وقتی مجموع دو بیت از ۱ بیشتر شود، بابت حمل ۱ می‌شود.',
            ],
            explanation:
                '۱+۱ در دودویی ۱۰ است: مجموع ۰ و بابت حمل ۱. پس C=1 و S=0.',
          ),
          BuildCircuitStep(
            id: 'half_adder_build',
            title: 'نیم‌جمع‌کننده را بسازید',
            objective: 'دو خروجی S و C را با گیت‌ها به ورودی‌ها وصل کنید.',
            concepts: <String>['half-adder', 'xor', 'and'],
            challengeId: 'challenge_half_adder',
            hints: <String>[
              'برای S از XOR و برای C از AND استفاده کنید.',
              'خروجی‌های S و C از قبل روی بوم هستند؛ فقط سیم‌کشی کنید.',
            ],
            explanation:
                'این مدار پایهٔ جمع‌کننده‌های چندبیتی است. با کنار هم گذاشتن چند نیم‌جمع‌کننده '
                'و افزودن بابت حمل، جمع‌کنندهٔ کامل ساخته می‌شود.',
          ),
        ],
      ),
      LearningLesson(
        id: 'lesson_equality',
        title: 'مقایسه‌گر برابری',
        subtitle: 'تشخیص تساوی دو مقدار',
        minutes: 5,
        steps: <LessonStep>[
          ConceptStep(
            id: 'equality_concept',
            title: 'آیا برابرند؟',
            objective: 'بفهمید مقایسهٔ برابری با XNOR ساخته می‌شود.',
            concepts: <String>['comparator'],
            paragraphs: <String>[
              'برای مقایسهٔ دو بیت، خروجی ۱ یعنی برابر و ۰ یعنی متفاوت.',
              'XNOR دقیقاً همین رفتار را دارد: در حالت‌های ۰۰ و ۱۱ خروجی ۱ می‌دهد.',
              'در پردازنده‌ها، مقایسه‌گرها ورودی دستور پرش شرطی و تصمیم‌گیری هستند.',
            ],
            explanation: 'مقایسهٔ تساوی = XNOR.',
          ),
          PredictionStep(
            id: 'equality_predict',
            title: 'حدس بزنید',
            objective: 'خروجی مقایسه‌گر را برای A=1 و B=1 پیش‌بینی کنید.',
            concepts: <String>['comparator', 'xnor'],
            circuit: xnorFromGatesExercise(),
            inputs: <String, bool>{'A': true, 'B': true},
            hints: <String>['دو ورودی برابر هستند؛ خروجی برابر باید ۱ باشد.'],
            explanation: 'وقتی A=B=1 باشد، جملهٔ A·B برابر ۱ می‌شود و OR خروجی ۱ می‌دهد.',
          ),
          GateChoiceStep(
            id: 'equality_choose',
            title: 'قطعهٔ مناسب',
            objective: 'گیت مقایسهٔ برابری را انتخاب کنید.',
            concepts: <String>['comparator', 'xnor'],
            options: <ComponentType>[
              ComponentType.xorGate,
              ComponentType.xnorGate,
              ComponentType.orGate,
              ComponentType.andGate,
            ],
            correct: ComponentType.xnorGate,
            behavior: gateExercise(ComponentType.xnorGate),
            showBehaviorTable: false,
            hints: <String>['XOR تفاوت را نشان می‌دهد؛ ما دنبال تساوی هستیم.'],
            explanation:
                'XNOR معکوس XOR است و در ورودی‌های برابر خروجی ۱ می‌دهد.',
          ),
          BuildCircuitStep(
            id: 'equality_build',
            title: 'مقایسه‌گر را بسازید',
            objective: 'خروجی EQ را فقط در حالت تساوی ۱ کنید.',
            concepts: <String>['comparator', 'xnor'],
            challengeId: 'challenge_equality',
            hints: <String>[
              'XNOR آماده را امتحان کنید یا XOR را با NOT ترکیب کنید.',
            ],
            explanation: 'اگر خروجی EQ در حالت‌های ۰۰ و ۱۱ برابر ۱ باشد، مقایسه‌گر درست است.',
          ),
        ],
      ),
    ],
  ),
  LearningUnit(
    id: 'unit_sequential',
    title: 'حافظه و ترتیب',
    subtitle: 'قفل، فلیپ‌فلپ، رجیستر و شمارنده',
    lessons: <LearningLesson>[
      LearningLesson(
        id: 'lesson_latch',
        title: 'قفل (Latch)',
        subtitle: 'نخستین حافظهٔ مدار',
        minutes: 5,
        steps: <LessonStep>[
          ConceptStep(
            id: 'latch_concept',
            title: 'حافظه با بازخورد',
            objective: 'بفهمید یک قفل چگونه مقدار را نگه می‌دارد.',
            concepts: <String>['latch', 'signal'],
            sequentialCircuit: dLatchHoldExercise(),
            paragraphs: <String>[
              'همهٔ مدارهایی که تا اینجا ساختید فقط به ورودی‌های همان لحظه وابسته بودند. '
                  'قفل نخستین قطعه‌ای است که می‌تواند یک مقدار را به یاد بسپارد.',
              'قفل D دو ورودی دارد: D (داده) و EN (فعال‌ساز). تا وقتی EN=۱ است، خروجی Q '
                  'مقدار D را دنبال می‌کند. به این حالت «شفاف» می‌گویند.',
              'وقتی EN=۰ می‌شود، قفل بسته می‌شود و آخرین مقدار را نگه می‌دارد؛ حتی اگر D تغییر کند.',
              'قفل بر اساس سطح کار می‌کند، نه لبه؛ یعنی تا زمانی که EN فعال است، Q زندهٔ D است.',
            ],
            explanation: 'قفل = حافظهٔ سطحی: EN=۱ شفاف، EN=۰ نگه‌دارنده.',
          ),
          SequenceStep(
            id: 'latch_transparent',
            title: 'دریچهٔ باز',
            objective: 'با EN=۱ خروجی Q را در دو تغییر D پیش‌بینی کنید.',
            concepts: <String>['latch'],
            circuit: dLatchTransparentExercise(),
            hints: <String>[
              'تا وقتی EN=۱ است، Q همان D است؛ کاری به مقدار قبلی نداشته باشید.',
            ],
            explanation: 'در هر دو گام EN=۱ بود، پس قفل شفاف بود و Q دقیقاً D را دنبال کرد: ۱ و سپس ۰.',
          ),
          SequenceStep(
            id: 'latch_hold',
            title: 'بستن دریچه',
            objective: 'پس از EN=۰، خروجی را در دو گام بعدی پیش‌بینی کنید.',
            concepts: <String>['latch', 'signal'],
            circuit: dLatchHoldExercise(),
            hints: <String>[
              'در گام اول مقدار ۱ ذخیره شده است.',
              'در گام‌های بعد EN=۰ است؛ D اجازهٔ تغییر Q را ندارد.',
            ],
            explanation:
                'در گام اول Q=۱ ذخیره شد. با EN=۰ قفل بسته شد و هر دو تغییر بعدی D اثری نداشتند؛ '
                'Q همچنان ۱ ماند.',
          ),
          TextChoiceStep(
            id: 'latch_choice',
            title: 'قاعدهٔ قفل',
            objective: 'رفتار قفل D را در دو حالت EN انتخاب کنید.',
            concepts: <String>['latch'],
            options: <LessonOption>[
              LessonOption(
                text: 'EN=۱: Q از D پیروی می‌کند؛ EN=۰: Q مقدار قبلی را نگه می‌دارد',
                correct: true,
              ),
              LessonOption(
                text: 'EN=۱: Q مقدار قبلی را نگه می‌دارد؛ EN=۰: Q از D پیروی می‌کند',
                correct: false,
              ),
              LessonOption(
                text: 'در هر حالت Q همیشه برابر D است',
                correct: false,
              ),
            ],
            hints: <String>['EN مخفف Enable است؛ یعنی «فعال بودن» قفل.'],
            explanation:
                'EN=۱ یعنی قفل فعال و شفاف است؛ EN=۰ یعنی بسته و نگه‌دارنده.',
          ),
        ],
      ),
      LearningLesson(
        id: 'lesson_flip_flop',
        title: 'فلیپ‌فلپ D',
        subtitle: 'ذخیره در لبهٔ کلاک',
        minutes: 6,
        steps: <LessonStep>[
          ConceptStep(
            id: 'flip_flop_concept',
            title: 'فقط در یک لحظه',
            objective: 'تفاوت فلیپ‌فلپ لبه‌ای با قفل سطحی را بشناسید.',
            concepts: <String>['flip-flop', 'latch'],
            sequentialCircuit: dFlipFlopExercise(),
            paragraphs: <String>[
              'فلیپ‌فلپ D هم مثل قفل D یک بیت را ذخیره می‌کند، اما فقط در یک لحظهٔ مشخص: '
                  'لبهٔ بالاروندهٔ کلاک.',
              'کلاک سیگنالی است که مثل ضربان قلب مدار، لحظهٔ ذخیره‌سازی را تعیین می‌کند. '
                  'بین لبه‌ها، فلیپ‌فلپ کاملاً از ورودی D جدا است و مقدارش را نگه می‌دارد.',
              'این جدایی باعث می‌شود همهٔ فلیپ‌فلپ‌های یک مدار هم‌زمان و هماهنگ به‌روز شوند؛ '
                  'همین اصل پایهٔ پردازنده‌ها و شمارنده‌هاست.',
            ],
            explanation: 'فلیپ‌فلپ = حافظهٔ لبه‌ای: فقط در لبهٔ بالاروندهٔ کلاک مقدار D را می‌گیرد.',
          ),
          SequenceStep(
            id: 'ff_capture',
            title: 'گرفتن مقدار',
            objective:
                'پس از هر لبه، مقدار Q را برای D داده‌شده پیش‌بینی کنید.',
            concepts: <String>['flip-flop'],
            circuit: dFlipFlopExercise(),
            hints: <String>[
              'برای هر لبه، فقط مقدار D در همان لحظه مهم است.',
              'مقدار Q در هر لبه برابر D همان لبه می‌شود.',
            ],
            explanation:
                'در لبهٔ اول D=۱ بود پس Q=۱ شد؛ در لبهٔ دوم D=۰ و Q=۰ شد؛ در لبهٔ سوم دوباره D=۱ '
                'و Q=۱ شد.',
          ),
          SequenceStep(
            id: 'ff_toggle',
            title: 'وارونگی با T',
            objective: 'رفتار فلیپ‌فلپ T را در چهار لبه پیش‌بینی کنید.',
            concepts: <String>['flip-flop'],
            circuit: tFlipFlopExercise(),
            hints: <String>[
              'T=۱ یعنی «وارونه کن». مقدار اولیه Q صفر است.',
              'هر لبه مقدار Q را برعکس لبهٔ قبل می‌کند.',
            ],
            explanation:
                'با T=۱ هر لبه Q را وارونه می‌کند: ۱، ۰، ۱، ۰. به همین دلیل فلیپ‌فلپ T '
                'برای ساختن شمارندهٔ دودویی استفاده می‌شود.',
          ),
          TextChoiceStep(
            id: 'ff_choice',
            title: 'لحظهٔ ذخیره',
            objective: 'مشخص کنید فلیپ‌فلپ D چه زمانی داده را می‌گیرد.',
            concepts: <String>['flip-flop'],
            options: <LessonOption>[
              LessonOption(text: 'فقط در لبهٔ بالاروندهٔ کلاک', correct: true),
              LessonOption(text: 'در تمام مدتی که کلاک ۱ است', correct: false),
              LessonOption(text: 'هر بار که D تغییر کند', correct: false),
            ],
            hints: <String>['تفاوت اصلی فلیپ‌فلپ با قفل در همین «لحظه» است.'],
            explanation:
                'فلیپ‌فلپ لبه‌ای است: فقط در گذر کلاک از ۰ به ۱ داده را می‌گیرد. گزینهٔ دوم '
                'رفتار قفل سطحی است و گزینهٔ سوم اصلاً حافظهٔ هماهنگ نیست.',
          ),
        ],
      ),
      LearningLesson(
        id: 'lesson_counter',
        title: 'شمارنده و رجیستر',
        subtitle: 'حافظهٔ چندبیتی و شمارش',
        minutes: 6,
        steps: <LessonStep>[
          ConceptStep(
            id: 'counter_concept',
            title: 'شمردن با کلاک',
            objective: 'ببینید بیت‌های یک شمارنده چگونه تقسیم می‌شوند.',
            concepts: <String>['counter', 'flip-flop'],
            sequentialCircuit: counterBitExercise(0),
            paragraphs: <String>[
              'اگر چند فلیپ‌فلپ T را زنجیره کنید، هر کلاک یک واحد به عدد ذخیره‌شده اضافه می‌شود. '
                  'این مجموعه «شمارندهٔ دودویی» است.',
              'کم‌ارزش‌ترین بیت Q0 با هر لبه وارونه می‌شود. Q1 با هر دو لبه، Q2 با هر چهار لبه و '
                  'Q3 با هر هشت لبه یک بار عوض می‌شود.',
              'شمارندهٔ ۴ بیتی از ۰۰۰۰ تا ۱۱۱۱ (یعنی ۰ تا ۱۵) می‌شمارد و سپس به صفر برمی‌گردد.',
              'ورودی RST شمارنده را صفر می‌کند؛ به همین دلیل در تمرین‌ها همیشه ۰ نگه داشته شده است.',
            ],
            explanation: 'Q0 سریع‌ترین بیت است؛ هر بیت بعدی با نصف سرعت بیت قبلی عوض می‌شود.',
          ),
          SequenceStep(
            id: 'counter_lsb',
            title: 'بیت کم‌ارزش',
            objective: 'خروجی Q0 شمارنده را در چهار لبه پیش‌بینی کنید.',
            concepts: <String>['counter'],
            circuit: counterBitExercise(0),
            hints: <String>[
              'Q0 کم‌ارزش‌ترین بیت است و با هر لبه وارونه می‌شود.',
              'شمارنده از ۰ شروع می‌کند: ۰، ۱، ۲، ۳، ۴.',
            ],
            explanation: 'مقادیر شمارنده پس از هر لبه ۱، ۲، ۳ و ۴ است؛ بیت Q0 آن‌ها ۱، ۰، ۱، ۰ می‌شود.',
          ),
          SequenceStep(
            id: 'counter_second_bit',
            title: 'بیت دوم',
            objective: 'خروجی Q1 شمارنده را در چهار لبه پیش‌بینی کنید.',
            concepts: <String>['counter'],
            circuit: counterBitExercise(1),
            hints: <String>[
              'Q1 فقط وقتی عوض می‌شود که Q0 از ۱ به ۰ برگردد.',
              'مقادیر ۱، ۲، ۳ و ۴ را دودویی بنویسید: ۰۱، ۱۰، ۱۱ و ۱۰۰.',
            ],
            explanation:
                'Q1 پس از لبه‌ها برابر ۰، ۱، ۱ و ۰ است: در شمارش ۱، ۲، ۳ و ۴ بیت دوم '
                'یک بار روشن می‌ماند و سپس خاموش می‌شود.',
          ),
          TextChoiceStep(
            id: 'counter_choice',
            title: 'کدام بیت سریع‌تر؟',
            objective: 'بیتی را انتخاب کنید که با هر لبهٔ کلاک وارونه می‌شود.',
            concepts: <String>['counter'],
            options: <LessonOption>[
              LessonOption(text: 'Q0', correct: true, technical: true),
              LessonOption(text: 'Q1', correct: false, technical: true),
              LessonOption(text: 'Q3', correct: false, technical: true),
            ],
            hints: <String>['بیت کم‌ارزش همیشه سریع‌ترین بیت است.'],
            explanation:
                'Q0 کم‌ارزش‌ترین بیت است و در هر لبه وارونه می‌شود. هر بیت بالاتر با نصف '
                'سرعت عوض می‌شود.',
          ),
          ConceptStep(
            id: 'register_concept',
            title: 'رجیستر: ذخیرهٔ یک کلمه',
            objective: 'بدانید رجیستر چه تفاوتی با یک فلیپ‌فلپ دارد.',
            concepts: <String>['register'],
            paragraphs: <String>[
              'رجیستر چند فلیپ‌فلپ کنار هم است که با یک کلاک مشترک کار می‌کنند. '
                  'در هر لبه، همهٔ بیت‌های ورودی با هم ذخیره می‌شوند.',
              'رجیستر ۴ بیتی ورودی‌های D0 تا D3 را می‌گیرد و در Q0 تا Q3 نگه می‌دارد. '
                  'این یعنی یک «کلمه» چهاربیتی به‌صورت اتمی ذخیره می‌شود.',
              'رجیسترها در پردازنده برای نگه‌داشتن operandها، آدرس‌ها و نتیجهٔ محاسبات به کار می‌روند.',
            ],
            explanation: 'رجیستر = چند بیت حافظه با کلاک مشترک؛ همهٔ بیت‌ها هم‌زمان ذخیره می‌شوند.',
          ),
        ],
      ),
    ],
  ),
];

List<LearningLesson> get kLessons => <LearningLesson>[
  for (final LearningUnit unit in kCurriculum) ...unit.lessons,
];

final Map<String, LearningLesson> kLessonById = <String, LearningLesson>{
  for (final LearningLesson lesson in kLessons) lesson.id: lesson,
};

final Map<String, LearningUnit> kUnitByLessonId = <String, LearningUnit>{
  for (final LearningUnit unit in kCurriculum)
    for (final LearningLesson lesson in unit.lessons) lesson.id: unit,
};

final Map<String, LearningChallenge> kChallengeById =
    <String, LearningChallenge>{
      for (final LearningChallenge challenge in kChallenges)
        challenge.id: challenge,
    };

LearningLesson? lessonById(String id) => kLessonById[id];

LearningChallenge? challengeById(String id) => kChallengeById[id];

LearningUnit? unitOfLesson(String lessonId) => kUnitByLessonId[lessonId];

int lessonIndex(String lessonId) =>
    kLessons.indexWhere((LearningLesson lesson) => lesson.id == lessonId);

bool isLessonUnlocked(String lessonId, Set<String> completedLessons) {
  final int index = lessonIndex(lessonId);
  if (index < 0) {
    return false;
  }
  if (completedLessons.contains(lessonId)) {
    return true;
  }
  return index == 0 || completedLessons.contains(kLessons[index - 1].id);
}
