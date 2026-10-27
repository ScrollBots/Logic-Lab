import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/localization/persian_format.dart';
import '../../../core/theme/logic_lab_theme.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/gate_symbol.dart';
import '../../editor/domain/circuit_models.dart';
import '../../editor/presentation/circuit_preview.dart';
import '../../settings/application/settings_controller.dart';
import '../application/learning_controller.dart';
import '../domain/curriculum.dart';
import '../domain/learning_content.dart';
import '../domain/lesson_models.dart';
import 'challenge_launcher.dart';

/// Runs a learning lesson step by step, or a spaced-review session when
/// [review] is true. Review sessions use the same player and only record
/// answers, never lesson progress.
class LearningSessionScreen extends StatefulWidget {
  const LearningSessionScreen({
    super.key,
    required this.lesson,
    this.review = false,
  });

  final LearningLesson lesson;
  final bool review;

  @override
  State<LearningSessionScreen> createState() => _LearningSessionScreenState();
}

class _LearningSessionScreenState extends State<LearningSessionScreen> {
  int _index = 0;
  int _earnedXp = 0;
  bool _finished = false;
  bool _busy = false;

  StepEvaluation? _evaluation;
  bool _showSolution = false;
  int _attempts = 0;
  int _hintsShown = 0;
  bool _usedHint = false;

  bool? _predictionAnswer;
  List<bool?> _tableAnswers = const <bool?>[];
  List<bool?> _sequenceAnswers = const <bool?>[];
  ComponentType? _gateChoice;
  LessonOption? _textChoice;
  bool _buildPassed = false;
  String? _challengeProjectId;

  LearningController get _learning => context.read<LearningController>();
  LessonStep get _step => widget.lesson.steps[_index];
  bool get _isLastStep => _index >= widget.lesson.steps.length - 1;
  bool get _solved => _evaluation?.correct == true || _showSolution;

  @override
  void initState() {
    super.initState();
    final LearningController learning = context.read<LearningController>();
    _index = widget.review ? 0 : learning.resumeStepIndex(widget.lesson);
    _prepareStep();
  }

  void _prepareStep() {
    _evaluation = null;
    _showSolution = false;
    _attempts = 0;
    _hintsShown = 0;
    _usedHint = false;
    _predictionAnswer = null;
    _gateChoice = null;
    _textChoice = null;
    _buildPassed = false;
    _challengeProjectId = null;
    final LessonStep step = _step;
    if (step is TruthTableStep) {
      _tableAnswers = List<bool?>.filled(step.expectedRows().length, null);
    } else {
      _tableAnswers = const <bool?>[];
    }
    if (step is SequenceStep) {
      _sequenceAnswers = List<bool?>.filled(step.expectedStates().length, null);
    } else {
      _sequenceAnswers = const <bool?>[];
    }
  }

  void _haptic() {
    final SettingsController settings = context.read<SettingsController>();
    AppHaptics.selection(settings.hapticsEnabled);
  }

  Future<int> _record({
    required bool correct,
    required List<String> concepts,
  }) async {
    if (widget.review && concepts.isEmpty) {
      return 0;
    }
    final int xp = await _learning.recordAnswer(
      conceptIds: concepts,
      correct: correct,
      usedHint: _usedHint,
    );
    if (mounted && xp > 0) {
      setState(() => _earnedXp += xp);
    }
    return xp;
  }

  Future<void> _submit() async {
    if (_busy) {
      return;
    }
    final LessonStep step = _step;
    StepEvaluation? evaluation;
    if (step is PredictionStep) {
      if (_predictionAnswer == null) {
        return;
      }
      evaluation = step.check(_predictionAnswer!);
    } else if (step is TruthTableStep) {
      if (_tableAnswers.contains(null)) {
        setState(() {
          _evaluation = null;
        });
        _showMessage('برای همهٔ ردیف‌ها خروجی را انتخاب کنید.');
        return;
      }
      evaluation = step.check(_tableAnswers);
    } else if (step is SequenceStep) {
      if (_sequenceAnswers.contains(null)) {
        setState(() {
          _evaluation = null;
        });
        _showMessage('برای همهٔ مراحل خروجی را انتخاب کنید.');
        return;
      }
      evaluation = step.check(_sequenceAnswers);
    } else if (step is GateChoiceStep) {
      if (_gateChoice == null) {
        return;
      }
      evaluation = step.check(_gateChoice!);
    } else if (step is TextChoiceStep) {
      if (_textChoice == null) {
        return;
      }
      evaluation = step.check(_textChoice!);
    }
    if (evaluation == null) {
      return;
    }
    _haptic();
    setState(() {
      _evaluation = evaluation;
      if (!evaluation!.correct) {
        _attempts++;
        if (_attempts >= 2) {
          _showSolution = true;
        }
      } else {
        _showSolution = true;
      }
    });
    await _record(correct: evaluation.correct, concepts: step.concepts);
  }

  Future<void> _submitBuild() async {
    final BuildCircuitStep step = _step as BuildCircuitStep;
    final LearningChallenge? challenge = challengeById(step.challengeId);
    if (challenge == null || _busy) {
      return;
    }
    setState(() => _busy = true);
    try {
      if (_challengeProjectId == null) {
        _challengeProjectId = await launchChallenge(context, challenge);
      } else {
        await reopenChallenge(context, _challengeProjectId!, challenge);
      }
      if (!mounted) {
        return;
      }
      final bool passed = _learning.isCompleted(challenge.id);
      setState(() {
        _buildPassed = passed;
        _evaluation = StepEvaluation(
          correct: passed,
          feedback: passed
              ? 'مدار شما با شبیه‌ساز بررسی و تأیید شد.'
              : 'مدار هنوز شرایط چالش را برآورده نمی‌کند. می‌توانید '
                    'همان پروژه را باز کنید و سیم‌کشی را اصلاح کنید.',
          solution: step.explanation,
        );
        _showSolution = passed;
      });
      if (passed) {
        AppHaptics.impact(context.read<SettingsController>().hapticsEnabled);
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _advance() async {
    if (_busy) {
      return;
    }
    if (!widget.review) {
      await _learning.markStepDone(widget.lesson.id, _index);
    }
    if (!mounted) {
      return;
    }
    if (_isLastStep) {
      await _finish();
      return;
    }
    setState(() {
      _index++;
      _prepareStep();
    });
  }

  Future<void> _finish() async {
    setState(() => _busy = true);
    if (!widget.review) {
      final int bonus = await _learning.completeLesson(widget.lesson.id);
      if (mounted && bonus > 0) {
        setState(() => _earnedXp += bonus);
      }
    }
    if (mounted) {
      setState(() {
        _finished = true;
        _busy = false;
      });
    }
  }

  void _revealHint() {
    if (_hintsShown >= _step.hints.length) {
      return;
    }
    _haptic();
    setState(() {
      _hintsShown++;
      _usedHint = true;
    });
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  bool get _canContinue {
    final LessonStep step = _step;
    if (step is ConceptStep) {
      return true;
    }
    if (step is BuildCircuitStep) {
      return _buildPassed;
    }
    return _solved;
  }

  bool get _answerReady {
    final LessonStep step = _step;
    if (step is PredictionStep) {
      return _predictionAnswer != null;
    }
    if (step is TruthTableStep) {
      return !_tableAnswers.contains(null);
    }
    if (step is SequenceStep) {
      return !_sequenceAnswers.contains(null);
    }
    if (step is GateChoiceStep) {
      return _gateChoice != null;
    }
    if (step is TextChoiceStep) {
      return _textChoice != null;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'بستن',
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          widget.review ? 'مرور هوشمند' : widget.lesson.title,
          style: theme.textTheme.titleMedium,
        ),
        centerTitle: false,
      ),
      body: _finished
          ? _SummaryView(
              lesson: widget.lesson,
              review: widget.review,
              earnedXp: _earnedXp,
              onClose: () => Navigator.of(context).pop(),
              onNext: _openNextLesson,
            )
          : SafeArea(
              top: false,
              child: ResponsiveCenter(
                maxWidth: 720,
                child: Column(
                  children: <Widget>[
                    _SessionProgress(
                      index: _index,
                      total: widget.lesson.steps.length,
                      earnedXp: _earnedXp,
                    ),
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                        children: <Widget>[
                          Text(
                            _step.title,
                            style: theme.textTheme.headlineSmall,
                          ),
                          const SizedBox(height: 5),
                          Text(
                            _step.objective,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                              height: 1.6,
                            ),
                          ),
                          const SizedBox(height: 16),
                          _buildStepContent(context),
                          if (_hintsShown > 0) ...<Widget>[
                            const SizedBox(height: 14),
                            for (int index = 0; index < _hintsShown; index++)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: InfoBanner(
                                  icon: Icons.lightbulb_outline_rounded,
                                  message: _step.hints[index],
                                ),
                              ),
                          ],
                          if (_evaluation != null) ...<Widget>[
                            const SizedBox(height: 14),
                            _FeedbackPanel(
                              evaluation: _evaluation!,
                              revealSolution: _showSolution,
                            ),
                          ],
                        ],
                      ),
                    ),
                    _buildBottomBar(context),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildStepContent(BuildContext context) {
    final LessonStep step = _step;
    return switch (step) {
      ConceptStep() => _ConceptView(step: step),
      PredictionStep() => _PredictionView(
        step: step,
        answer: _predictionAnswer,
        locked: _solved,
        onChanged: (bool value) {
          _haptic();
          setState(() => _predictionAnswer = value);
        },
      ),
      TruthTableStep() => _TruthTableView(
        step: step,
        answers: _tableAnswers,
        mismatchRows: _evaluation?.mismatchRows ?? const <int>[],
        locked: _solved,
        onChanged: (int row, bool value) {
          _haptic();
          setState(() {
            final List<bool?> next = List<bool?>.from(_tableAnswers);
            next[row] = value;
            _tableAnswers = next;
          });
        },
      ),
      SequenceStep() => _SequenceView(
        step: step,
        answers: _sequenceAnswers,
        mismatchRows: _evaluation?.mismatchRows ?? const <int>[],
        locked: _solved,
        onChanged: (int index, bool value) {
          _haptic();
          setState(() {
            final List<bool?> next = List<bool?>.from(_sequenceAnswers);
            next[index] = value;
            _sequenceAnswers = next;
          });
        },
      ),
      GateChoiceStep() => _GateChoiceView(
        step: step,
        choice: _gateChoice,
        locked: _solved,
        onChanged: (ComponentType value) {
          _haptic();
          setState(() => _gateChoice = value);
        },
      ),
      TextChoiceStep() => _TextChoiceView(
        step: step,
        choice: _textChoice,
        locked: _solved,
        onChanged: (LessonOption value) {
          _haptic();
          setState(() => _textChoice = value);
        },
      ),
      BuildCircuitStep() => _BuildView(step: step, passed: _buildPassed),
    };
  }

  Widget _buildBottomBar(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final LessonStep step = _step;
    final bool showHint =
        step.hints.isNotEmpty &&
        !_canContinue &&
        _hintsShown < step.hints.length;

    final String label;
    final VoidCallback? action;
    if (step is ConceptStep) {
      label = _isLastStep ? 'پایان درس' : 'ادامه';
      action = _advance;
    } else if (step is BuildCircuitStep) {
      if (_buildPassed) {
        label = _isLastStep ? 'پایان درس' : 'ادامه';
        action = _advance;
      } else {
        label = _busy ? 'در حال باز کردن…' : 'ساخت در ویرایشگر';
        action = _busy ? null : _submitBuild;
      }
    } else if (_canContinue) {
      label = _isLastStep ? 'پایان درس' : 'ادامه';
      action = _busy ? null : _advance;
    } else {
      label = 'بررسی پاسخ';
      action = _answerReady && !_busy ? _submit : null;
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLowest,
        border: Border(
          top: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: <Widget>[
            if (showHint) ...<Widget>[
              OutlinedButton.icon(
                onPressed: _revealHint,
                icon: const Icon(Icons.lightbulb_outline_rounded, size: 18),
                label: Text(_hintsShown == 0 ? 'راهنما' : 'راهنمای بعدی'),
              ),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: FilledButton(onPressed: action, child: Text(label)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openNextLesson() async {
    final int index = lessonIndex(widget.lesson.id);
    if (index < 0 || index >= kLessons.length - 1) {
      Navigator.of(context).pop();
      return;
    }
    final LearningLesson next = kLessons[index + 1];
    await Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => LearningSessionScreen(lesson: next),
      ),
    );
  }
}

class _SessionProgress extends StatelessWidget {
  const _SessionProgress({
    required this.index,
    required this.total,
    required this.earnedXp,
  });

  final int index;
  final int total;
  final int earnedXp;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final LogicLabColors colors = LogicLabColors.of(context);
    final double value = total == 0 ? 0 : (index + 1) / total;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              Text(
                'گام ${PersianFormat.digits(index + 1)} از ${PersianFormat.digits(total)}',
                style: theme.textTheme.labelSmall,
              ),
              const Spacer(),
              if (earnedXp > 0)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(Icons.bolt_rounded, size: 15, color: colors.warning),
                    const SizedBox(width: 3),
                    Text(
                      '+${PersianFormat.digits(earnedXp)} XP',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colors.warning,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 7),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: value,
              minHeight: 7,
              backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
            ),
          ),
        ],
      ),
    );
  }
}

class _ConceptView extends StatelessWidget {
  const _ConceptView({required this.step});

  final ConceptStep step;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ExerciseCircuit? circuit = step.circuit;
    final SequentialExercise? sequential = step.sequentialCircuit;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (step.gateType != null)
          Center(
            child: Container(
              width: 94,
              height: 94,
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: theme.colorScheme.outlineVariant),
              ),
              child: Center(child: GateSymbol(type: step.gateType!, size: 64)),
            ),
          ),
        if (circuit != null)
          SizedBox(
            height: 170,
            child: CircuitPreview(
              graph: circuit.build(circuit.valuesForRow(0)),
            ),
          ),
        if (sequential != null)
          SizedBox(
            height: 170,
            child: CircuitPreview(
              graph: sequential.build(sequential.steps.first),
            ),
          ),
        if (step.gateType != null || circuit != null || sequential != null)
          const SizedBox(height: 16),
        for (final String paragraph in step.paragraphs) ...<Widget>[
          Text(
            paragraph,
            style: theme.textTheme.bodyMedium?.copyWith(height: 1.8),
          ),
          const SizedBox(height: 12),
        ],
        InfoBanner(
          tone: InfoBannerTone.success,
          icon: Icons.key_rounded,
          message: step.explanation,
        ),
      ],
    );
  }
}

class _PredictionView extends StatelessWidget {
  const _PredictionView({
    required this.step,
    required this.answer,
    required this.locked,
    required this.onChanged,
  });

  final PredictionStep step;
  final bool? answer;
  final bool locked;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final LogicLabColors colors = LogicLabColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SizedBox(
          height: 170,
          child: CircuitPreview(graph: step.circuit.build(step.inputs)),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            for (final MapEntry<String, bool> entry in step.inputs.entries)
              SignalPill(value: entry.value, label: entry.key),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: <Widget>[
            Expanded(
              child: _BinaryChoice(
                label: '۰',
                hint: 'پایین',
                selected: answer == false,
                color: colors.lowSignal,
                enabled: !locked,
                onTap: () => onChanged(false),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _BinaryChoice(
                label: '۱',
                hint: 'بالا',
                selected: answer == true,
                color: colors.highSignal,
                enabled: !locked,
                onTap: () => onChanged(true),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'خروجی ${step.circuit.outputLabel} در این وضعیت چه مقداری دارد؟',
          style: theme.textTheme.bodySmall,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _BinaryChoice extends StatelessWidget {
  const _BinaryChoice({
    required this.label,
    required this.hint,
    required this.selected,
    required this.color,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final String hint;
  final bool selected;
  final Color color;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Semantics(
      button: true,
      selected: selected,
      label: 'خروجی $label، $hint',
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(vertical: 18),
          decoration: BoxDecoration(
            color: selected
                ? color.withValues(alpha: 0.13)
                : theme.colorScheme.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected
                  ? color.withValues(alpha: 0.65)
                  : theme.colorScheme.outlineVariant,
              width: selected ? 2 : 1,
            ),
          ),
          child: Column(
            children: <Widget>[
              TechnicalText(
                label,
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: selected ? color : theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                hint,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TruthTableView extends StatelessWidget {
  const _TruthTableView({
    required this.step,
    required this.answers,
    required this.mismatchRows,
    required this.locked,
    required this.onChanged,
  });

  final TruthTableStep step;
  final List<bool?> answers;
  final List<int> mismatchRows;
  final bool locked;
  final void Function(int row, bool value) onChanged;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final List<String> labels = step.circuit.inputLabels;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SizedBox(
          height: 150,
          child: CircuitPreview(
            graph: step.circuit.build(step.circuit.valuesForRow(0)),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'عبارت: ${step.circuit.expression}',
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 10),
        for (int row = 0; row < answers.length; row++)
          _TruthTableRow(
            row: row,
            labels: labels,
            answer: answers[row],
            mismatch: mismatchRows.contains(row),
            locked: locked,
            onChanged: (bool value) => onChanged(row, value),
          ),
        const SizedBox(height: 6),
        Text(
          'خروجی هر ردیف را با ۰ یا ۱ کامل کنید.',
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _TruthTableRow extends StatelessWidget {
  const _TruthTableRow({
    required this.row,
    required this.labels,
    required this.answer,
    required this.mismatch,
    required this.locked,
    required this.onChanged,
  });

  final int row;
  final List<String> labels;
  final bool? answer;
  final bool mismatch;
  final bool locked;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final LogicLabColors colors = LogicLabColors.of(context);
    final bool a = labels.length == 1 ? false : row >= 2;
    final bool b = row.isOdd;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: mismatch
            ? colors.danger.withValues(alpha: 0.06)
            : theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: mismatch
              ? colors.danger.withValues(alpha: 0.4)
              : theme.colorScheme.outlineVariant,
        ),
      ),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 30,
            child: Text(
              PersianFormat.digits(row + 1),
              style: theme.textTheme.labelSmall,
            ),
          ),
          for (final String label in labels) ...<Widget>[
            TechnicalText(
              '$label=${labels.length == 1 ? (row == 1 ? 1 : 0) : (label == labels[0] ? (a ? 1 : 0) : (b ? 1 : 0))}',
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 10),
          ],
          const Spacer(),
          _TableToggle(
            label: '0',
            selected: answer == false,
            color: colors.lowSignal,
            enabled: !locked,
            onTap: () => onChanged(false),
          ),
          const SizedBox(width: 6),
          _TableToggle(
            label: '1',
            selected: answer == true,
            color: colors.highSignal,
            enabled: !locked,
            onTap: () => onChanged(true),
          ),
        ],
      ),
    );
  }
}

class _TableToggle extends StatelessWidget {
  const _TableToggle({
    required this.label,
    required this.selected,
    required this.color,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final Color color;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Semantics(
      button: true,
      selected: selected,
      label: 'خروجی $label',
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: 46,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected
                ? color.withValues(alpha: 0.13)
                : theme.colorScheme.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected
                  ? color.withValues(alpha: 0.6)
                  : theme.colorScheme.outlineVariant,
              width: selected ? 1.6 : 1,
            ),
          ),
          child: TechnicalText(
            label,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: selected ? color : theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}

class _SequenceView extends StatelessWidget {
  const _SequenceView({
    required this.step,
    required this.answers,
    required this.mismatchRows,
    required this.locked,
    required this.onChanged,
  });

  final SequenceStep step;
  final List<bool?> answers;
  final List<int> mismatchRows;
  final bool locked;
  final void Function(int index, bool value) onChanged;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final SequentialExercise circuit = step.circuit;
    final List<String> inputs = circuit.shownInputLabels;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SizedBox(
          height: 170,
          child: CircuitPreview(graph: circuit.build(circuit.steps.first)),
        ),
        const SizedBox(height: 10),
        Text('رفتار: ${circuit.expression}', style: theme.textTheme.bodySmall),
        const SizedBox(height: 10),
        for (int index = 0; index < answers.length; index++)
          _SequenceRow(
            label: circuit.clocked
                ? 'لبهٔ ${PersianFormat.digits(index + 1)}'
                : 'گام ${PersianFormat.digits(index + 1)}',
            inputs: <String>[
              for (final String label in inputs)
                '$label=${circuit.steps[index][label] == true ? 1 : 0}',
            ],
            answer: answers[index],
            mismatch: mismatchRows.contains(index),
            locked: locked,
            onChanged: (bool value) => onChanged(index, value),
          ),
        const SizedBox(height: 6),
        Text(
          circuit.clocked
              ? 'پس از هر لبهٔ کلاک، مقدار ${circuit.outputLabel} را انتخاب کنید.'
              : 'در هر گام، پس از تغییر ورودی‌ها مقدار ${circuit.outputLabel} را انتخاب کنید.',
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _SequenceRow extends StatelessWidget {
  const _SequenceRow({
    required this.label,
    required this.inputs,
    required this.answer,
    required this.mismatch,
    required this.locked,
    required this.onChanged,
  });

  final String label;
  final List<String> inputs;
  final bool? answer;
  final bool mismatch;
  final bool locked;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final LogicLabColors colors = LogicLabColors.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: mismatch
            ? colors.danger.withValues(alpha: 0.06)
            : theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: mismatch
              ? colors.danger.withValues(alpha: 0.4)
              : theme.colorScheme.outlineVariant,
        ),
      ),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 46,
            child: Text(label, style: theme.textTheme.labelSmall),
          ),
          Expanded(
            child: Wrap(
              spacing: 8,
              runSpacing: 2,
              children: <Widget>[
                for (final String input in inputs)
                  TechnicalText(
                    input,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          _TableToggle(
            label: '0',
            selected: answer == false,
            color: colors.lowSignal,
            enabled: !locked,
            onTap: () => onChanged(false),
          ),
          const SizedBox(width: 6),
          _TableToggle(
            label: '1',
            selected: answer == true,
            color: colors.highSignal,
            enabled: !locked,
            onTap: () => onChanged(true),
          ),
        ],
      ),
    );
  }
}

class _GateChoiceView extends StatelessWidget {
  const _GateChoiceView({
    required this.step,
    required this.choice,
    required this.locked,
    required this.onChanged,
  });

  final GateChoiceStep step;
  final ComponentType? choice;
  final bool locked;
  final ValueChanged<ComponentType> onChanged;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (final ComponentType type in step.options)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _ChoiceTile(
              selected: choice == type,
              correct: locked && type == step.correct,
              semanticLabel: type.persianName,
              onTap: locked ? null : () => onChanged(type),
              child: Row(
                children: <Widget>[
                  GateSymbol(type: type, size: 44, strokeWidth: 1.7),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          type.persianName,
                          style: theme.textTheme.titleSmall,
                        ),
                        TechnicalText(
                          type.technicalName,
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _TextChoiceView extends StatelessWidget {
  const _TextChoiceView({
    required this.step,
    required this.choice,
    required this.locked,
    required this.onChanged,
  });

  final TextChoiceStep step;
  final LessonOption? choice;
  final bool locked;
  final ValueChanged<LessonOption> onChanged;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (step.behavior != null) ...<Widget>[
          SizedBox(
            height: 160,
            child: CircuitPreview(
              graph: step.behavior!.build(step.behavior!.valuesForRow(0)),
            ),
          ),
          const SizedBox(height: 12),
        ],
        for (final LessonOption option in step.options)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _ChoiceTile(
              selected: choice == option,
              correct: locked && option.correct,
              semanticLabel: option.text,
              onTap: locked ? null : () => onChanged(option),
              child: option.technical
                  ? TechnicalText(
                      option.text,
                      style: theme.textTheme.titleSmall,
                    )
                  : Text(option.text, style: theme.textTheme.bodyMedium),
            ),
          ),
      ],
    );
  }
}

class _ChoiceTile extends StatelessWidget {
  const _ChoiceTile({
    required this.selected,
    required this.correct,
    required this.semanticLabel,
    required this.onTap,
    required this.child,
  });

  final bool selected;
  final bool correct;
  final String semanticLabel;
  final VoidCallback? onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final LogicLabColors colors = LogicLabColors.of(context);
    final Color border = correct
        ? colors.success
        : selected
        ? theme.colorScheme.primary
        : theme.colorScheme.outlineVariant;
    return Semantics(
      button: true,
      selected: selected,
      label: semanticLabel,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: correct
                ? colors.success.withValues(alpha: 0.08)
                : selected
                ? theme.colorScheme.primary.withValues(alpha: 0.08)
                : theme.colorScheme.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: border,
              width: selected || correct ? 1.8 : 1,
            ),
          ),
          child: Row(
            children: <Widget>[
              Expanded(child: child),
              if (correct)
                Icon(
                  Icons.check_circle_rounded,
                  size: 20,
                  color: colors.success,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BuildView extends StatelessWidget {
  const _BuildView({required this.step, required this.passed});

  final BuildCircuitStep step;
  final bool passed;

  @override
  Widget build(BuildContext context) {
    final LearningChallenge? challenge = challengeById(step.challengeId);
    final ThemeData theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SurfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  IconTile(
                    icon: passed
                        ? Icons.verified_rounded
                        : Icons.account_tree_outlined,
                    color: passed ? LogicLabColors.of(context).success : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      challenge?.title ?? step.title,
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                ],
              ),
              if (challenge != null) ...<Widget>[
                const SizedBox(height: 10),
                Text(challenge.brief, style: theme.textTheme.bodySmall),
                const SizedBox(height: 10),
                Text(
                  'ورودی‌ها: ${challenge.inputLabels.join('، ')} — '
                  'خروجی‌ها: ${challenge.outputLabels.join('، ')}',
                  style: theme.textTheme.bodySmall?.copyWith(height: 1.6),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        InfoBanner(
          icon: Icons.info_outline_rounded,
          message:
              'پس از پایان کار در ویرایشگر، دکمهٔ بررسی چالش را بزنید و '
              'سپس به این صفحه برگردید. نتیجه با شبیه‌ساز واقعی سنجیده می‌شود.',
        ),
      ],
    );
  }
}

class _FeedbackPanel extends StatelessWidget {
  const _FeedbackPanel({
    required this.evaluation,
    required this.revealSolution,
  });

  final StepEvaluation evaluation;
  final bool revealSolution;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final LogicLabColors colors = LogicLabColors.of(context);
    final bool correct = evaluation.correct;
    final Color color = correct ? colors.success : colors.warning;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(
                correct
                    ? Icons.check_circle_rounded
                    : Icons.error_outline_rounded,
                size: 20,
                color: color,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  evaluation.feedback,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          if (revealSolution) ...<Widget>[
            const SizedBox(height: 10),
            if (!correct && evaluation.correctLabel != null) ...<Widget>[
              Text(
                'پاسخ درست: ${evaluation.correctLabel}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
              const SizedBox(height: 8),
            ],
            Text(
              evaluation.solution,
              style: theme.textTheme.bodySmall?.copyWith(height: 1.75),
            ),
          ] else ...<Widget>[
            const SizedBox(height: 6),
            Text(
              'دوباره تلاش کنید یا از راهنما استفاده کنید.',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}

class _SummaryView extends StatelessWidget {
  const _SummaryView({
    required this.lesson,
    required this.review,
    required this.earnedXp,
    required this.onClose,
    required this.onNext,
  });

  final LearningLesson lesson;
  final bool review;
  final int earnedXp;
  final VoidCallback onClose;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final LogicLabColors colors = LogicLabColors.of(context);
    final int index = lessonIndex(lesson.id);
    final bool hasNext = !review && index >= 0 && index < kLessons.length - 1;
    return SafeArea(
      child: ResponsiveCenter(
        maxWidth: 560,
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: ListView(
          children: <Widget>[
            const SizedBox(height: 20),
            Center(
              child: Container(
                width: 92,
                height: 92,
                decoration: BoxDecoration(
                  color: colors.success.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: colors.success.withValues(alpha: 0.3),
                    width: 2,
                  ),
                ),
                child: Icon(
                  Icons.emoji_events_rounded,
                  size: 46,
                  color: colors.success,
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              review ? 'مرور انجام شد' : 'درس کامل شد',
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineSmall,
            ),
            const SizedBox(height: 6),
            Text(
              lesson.title,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 22),
            SurfaceCard(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: <Widget>[
                  _SummaryStat(
                    value: PersianFormat.digits(lesson.steps.length),
                    label: 'گام',
                  ),
                  _SummaryStat(
                    value: earnedXp > 0
                        ? '+${PersianFormat.digits(earnedXp)}'
                        : '۰',
                    label: 'XP این جلسه',
                  ),
                  _SummaryStat(
                    value: PersianFormat.digits(
                      context.watch<LearningController>().streak,
                    ),
                    label: 'روز پیاپی',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            InfoBanner(
              tone: InfoBannerTone.success,
              icon: Icons.auto_awesome_outlined,
              message:
                  'پیشرفت شما ذخیره شد. مفاهیم این درس در بخش مرور، در زمان '
                  'مناسب دوباره تمرین می‌شوند.',
            ),
            const SizedBox(height: 18),
            if (hasNext)
              FilledButton.icon(
                onPressed: onNext,
                icon: const Icon(Icons.arrow_forward_rounded),
                label: Text('درس بعدی: ${kLessons[index + 1].title}'),
              ),
            if (hasNext) const SizedBox(height: 10),
            OutlinedButton(
              onPressed: onClose,
              child: Text(review ? 'پایان مرور' : 'بازگشت به مسیر'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryStat extends StatelessWidget {
  const _SummaryStat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Column(
      children: <Widget>[
        TechnicalText(
          value,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 3),
        Text(label, style: theme.textTheme.bodySmall),
      ],
    );
  }
}
