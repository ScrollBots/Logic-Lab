import '../../editor/domain/circuit_models.dart';
import 'lesson_models.dart';

/// Short, self-contained exercises used for spaced review. They never open the
/// editor, so a review session stays a two-minute activity on a phone.
final List<LessonStep> kReviewBank = <LessonStep>[
  PredictionStep(
    id: 'review_and',
    title: 'AND',
    objective: 'خروجی AND را برای A=0 و B=1 پیش‌بینی کنید.',
    concepts: <String>['and'],
    circuit: gateExercise(ComponentType.andGate),
    inputs: <String, bool>{'A': false, 'B': true},
    hints: <String>['AND فقط با دو ورودی ۱ خروجی ۱ می‌دهد.'],
    explanation: 'چون A=0 است، شرط AND برقرار نیست و خروجی ۰ می‌شود.',
  ),
  TruthTableStep(
    id: 'review_or',
    title: 'جدول OR',
    objective: 'ستون خروجی OR را کامل کنید.',
    concepts: <String>['or', 'truth-table'],
    circuit: gateExercise(ComponentType.orGate),
    hints: <String>['OR فقط وقتی ۰ می‌دهد که همهٔ ورودی‌ها ۰ باشند.'],
    explanation: 'OR در سه ردیف اول ۱ و فقط در ردیف ۰۰ صفر است.',
  ),
  PredictionStep(
    id: 'review_not',
    title: 'NOT',
    objective: 'خروجی NOT را برای ورودی ۱ پیش‌بینی کنید.',
    concepts: <String>['not'],
    circuit: gateExercise(ComponentType.notGate),
    inputs: <String, bool>{'A': true},
    hints: <String>['NOT مقدار را برعکس می‌کند.'],
    explanation: 'ورودی ۱ با NOT به ۰ تبدیل می‌شود.',
  ),
  TruthTableStep(
    id: 'review_nand',
    title: 'جدول NAND',
    objective: 'ستون خروجی NAND را کامل کنید.',
    concepts: <String>['nand', 'truth-table'],
    circuit: gateExercise(ComponentType.nandGate),
    hints: <String>['NAND برعکس AND است.'],
    explanation: 'فقط ردیف A=1,B=1 خروجی ۰ دارد.',
  ),
  PredictionStep(
    id: 'review_nor',
    title: 'NOR',
    objective: 'خروجی NOR را برای A=0 و B=1 پیش‌بینی کنید.',
    concepts: <String>['nor'],
    circuit: gateExercise(ComponentType.norGate),
    inputs: <String, bool>{'A': false, 'B': true},
    hints: <String>['NOR به یک ورودی ۱ واکنش نشان می‌دهد.'],
    explanation: 'OR با یک ورودی ۱ خروجی ۱ می‌دهد و NOR آن را معکوس می‌کند؛ پس خروجی ۰ است.',
  ),
  PredictionStep(
    id: 'review_xor',
    title: 'XOR',
    objective: 'خروجی XOR را برای A=1 و B=1 پیش‌بینی کنید.',
    concepts: <String>['xor'],
    circuit: gateExercise(ComponentType.xorGate),
    inputs: <String, bool>{'A': true, 'B': true},
    hints: <String>['XOR فقط با ورودی‌های متفاوت ۱ می‌شود.'],
    explanation: 'ورودی‌ها برابر هستند، پس XOR خروجی ۰ می‌دهد.',
  ),
  TruthTableStep(
    id: 'review_xnor',
    title: 'جدول XNOR',
    objective: 'ستون خروجی XNOR را کامل کنید.',
    concepts: <String>['xnor', 'truth-table'],
    circuit: gateExercise(ComponentType.xnorGate),
    hints: <String>['XNOR برعکس XOR است.'],
    explanation: 'در ورودی‌های برابر خروجی ۱ و در ورودی‌های متفاوت ۰ است.',
  ),
  GateChoiceStep(
    id: 'review_buffer',
    title: 'قطعهٔ انتقال',
    objective: 'گیتی را انتخاب کنید که ورودی را بدون تغییر منتقل می‌کند.',
    concepts: <String>['buffer', 'signal'],
    options: <ComponentType>[
      ComponentType.andGate,
      ComponentType.bufferGate,
      ComponentType.notGate,
      ComponentType.xorGate,
    ],
    correct: ComponentType.bufferGate,
    behavior: gateExercise(ComponentType.bufferGate),
    showBehaviorTable: false,
    hints: <String>['بافر تنها گیتی است که ورودی را بدون تغییر عبور می‌دهد.'],
    explanation: 'بافر خروجی را برابر ورودی نگه می‌دارد.',
  ),
  TextChoiceStep(
    id: 'review_implication',
    title: 'عبارت استلزام',
    objective:
        'عبارت معادل تابعی را انتخاب کنید که فقط در A=1,B=0 خروجی ۰ دارد.',
    concepts: <String>['sop', 'not', 'or'],
    behavior: implicationExercise(),
    options: <LessonOption>[
      LessonOption(text: 'Y = ¬A + B', correct: true, technical: true),
      LessonOption(text: 'Y = A · B', correct: false, technical: true),
      LessonOption(text: 'Y = A ⊕ B', correct: false, technical: true),
      LessonOption(text: 'Y = A + B', correct: false, technical: true),
    ],
    hints: <String>['به حالتی فکر کنید که A=1 است و B=0.'],
    explanation: 'تابع فقط در A=1,B=0 صفر است؛ یعنی ¬A + B.',
  ),
  TruthTableStep(
    id: 'review_combining',
    title: 'جدول ساده‌شده',
    objective: 'جدول مداری از چند گیت را کامل کنید.',
    concepts: <String>['truth-table', 'and', 'not'],
    circuit: combiningExercise(),
    hints: <String>['نتیجهٔ نهایی این مدار برابر یکی از ورودی‌ها است.'],
    explanation: 'مدار A·B + A·B̅ در واقع برابر A است.',
  ),
  PredictionStep(
    id: 'review_half_adder',
    title: 'مجموع نیم‌جمع‌کننده',
    objective: 'خروجی S را برای A=1 و B=0 پیش‌بینی کنید.',
    concepts: <String>['half-adder', 'xor'],
    circuit: gateExercise(ComponentType.xorGate),
    inputs: <String, bool>{'A': true, 'B': false},
    hints: <String>['مجموع دو بیت با XOR محاسبه می‌شود.'],
    explanation: 'ورودی‌ها متفاوت‌اند؛ S=1 و بابت حملی وجود ندارد.',
  ),
  PredictionStep(
    id: 'review_comparator',
    title: 'برابری',
    objective: 'خروجی مقایسه‌گر را برای A=0 و B=1 پیش‌بینی کنید.',
    concepts: <String>['comparator', 'xnor'],
    circuit: gateExercise(ComponentType.xnorGate),
    inputs: <String, bool>{'A': false, 'B': true},
    hints: <String>['مقایسه‌گر برای برابری از XNOR استفاده می‌کند.'],
    explanation: 'ورودی‌ها برابر نیستند، پس خروجی برابری ۰ است.',
  ),
  SequenceStep(
    id: 'review_latch',
    title: 'حفظ مقدار',
    objective: 'پس از بسته شدن EN، خروجی قفل D را پیش‌بینی کنید.',
    concepts: <String>['latch'],
    circuit: dLatchHoldExercise(),
    hints: <String>[
      'قفل فقط تا وقتی EN=۱ است شفاف می‌ماند.',
      'پس از EN=۰، تغییر D روی Q اثر ندارد.',
    ],
    explanation: 'در گام اول Q=۱ ذخیره شد و پس از بسته شدن قفل، هر دو تغییر D نادیده گرفته شد.',
  ),
  SequenceStep(
    id: 'review_flip_flop',
    title: 'لبهٔ کلاک',
    objective: 'مقدار Q فلیپ‌فلپ D را در سه لبه پیش‌بینی کنید.',
    concepts: <String>['flip-flop'],
    circuit: dFlipFlopExercise(),
    hints: <String>['در هر لبه، Q برابر D همان لحظه می‌شود.'],
    explanation: 'D به‌ترتیب ۱، ۰ و ۱ بود؛ پس Q هم ۱، ۰ و ۱ شد.',
  ),
  SequenceStep(
    id: 'review_counter',
    title: 'بیت کم‌ارزش شمارنده',
    objective: 'خروجی Q0 شمارنده را در چهار لبه پیش‌بینی کنید.',
    concepts: <String>['counter'],
    circuit: counterBitExercise(0),
    hints: <String>[
      'Q0 با هر لبه وارونه می‌شود.',
      'شمارنده از صفر شروع می‌کند و با هر لبه یکی زیاد می‌شود.',
    ],
    explanation: 'مقادیر ۱، ۲، ۳ و ۴ باعث می‌شوند Q0 برابر ۱، ۰، ۱ و ۰ شود.',
  ),
];

/// Selects up to [limit] exercises for the given concepts. Concepts with an
/// exercise are preferred; the function never repeats an exercise in a
/// session.
List<LessonStep> buildReviewSteps(List<String> conceptIds, {int limit = 6}) {
  final List<LessonStep> selected = <LessonStep>[];
  final Set<String> used = <String>{};
  for (final String concept in conceptIds) {
    for (final LessonStep step in kReviewBank) {
      if (selected.length >= limit) {
        break;
      }
      if (used.contains(step.id) || !step.concepts.contains(concept)) {
        continue;
      }
      used.add(step.id);
      selected.add(step);
    }
  }
  if (selected.length >= limit) {
    return selected;
  }
  // Fill the session with related practice, still without duplicates. This
  // keeps a review useful when a concept only has one exercise.
  for (final LessonStep step in kReviewBank) {
    if (selected.length >= limit) {
      break;
    }
    if (!used.contains(step.id)) {
      used.add(step.id);
      selected.add(step);
    }
  }
  return selected;
}
