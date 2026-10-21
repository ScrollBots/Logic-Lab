import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/localization/persian_format.dart';
import '../../../core/theme/logic_lab_theme.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/gate_symbol.dart';
import '../../editor/domain/circuit_models.dart';
import '../../editor/presentation/circuit_editor_screen.dart';
import '../../projects/application/projects_controller.dart';
import '../../projects/domain/circuit_project.dart';
import '../application/learning_controller.dart';
import '../domain/learning_content.dart';

class LearnScreen extends StatefulWidget {
  const LearnScreen({super.key});

  @override
  State<LearnScreen> createState() => _LearnScreenState();
}

class _LearnScreenState extends State<LearnScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final LearningController learning = context.watch<LearningController>();
    final ThemeData theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ResponsiveCenter(
          maxWidth: 1120,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 12),
                child: Row(
                  children: <Widget>[
                    const BrandMark(size: 40, showName: true),
                    const Spacer(),
                    if (!learning.isLoading) _ProgressBadge(learning: learning),
                  ],
                ),
              ),
              SegmentedButton<int>(
                segments: const <ButtonSegment<int>>[
                  ButtonSegment<int>(
                    value: 0,
                    label: Text('گیت‌ها'),
                    icon: Icon(Icons.looks_one_rounded),
                  ),
                  ButtonSegment<int>(
                    value: 1,
                    label: Text('مسیر یادگیری'),
                    icon: Icon(Icons.route_rounded),
                  ),
                  ButtonSegment<int>(
                    value: 2,
                    label: Text('چالش‌ها'),
                    icon: Icon(Icons.flag_rounded),
                  ),
                ],
                selected: <int>{_tab},
                onSelectionChanged: (Set<int> value) {
                  setState(() => _tab = value.first);
                },
              ),
              const SizedBox(height: 14),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  child: switch (_tab) {
                    0 => const _GatesTab(key: ValueKey<String>('gates')),
                    1 => _PathsTab(
                      key: const ValueKey<String>('paths'),
                      learning: learning,
                    ),
                    _ => _ChallengesTab(
                      key: const ValueKey<String>('challenges'),
                      learning: learning,
                    ),
                  },
                ),
              ),
              if (theme.colorScheme.brightness == Brightness.dark) ...<Widget>[
                const SizedBox(height: 4),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ProgressBadge extends StatelessWidget {
  const _ProgressBadge({required this.learning});

  final LearningController learning;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final int total = kLessons.length + kChallenges.length;
    final int done = learning.completedCount;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          SizedBox(
            width: 26,
            height: 26,
            child: Stack(
              fit: StackFit.expand,
              children: <Widget>[
                CircularProgressIndicator(
                  value: total == 0 ? 0 : done / total,
                  strokeWidth: 3,
                  backgroundColor: theme.colorScheme.primary.withValues(
                    alpha: 0.12,
                  ),
                ),
                Center(
                  child: Text(
                    PersianFormat.digits(done),
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 9),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text('پیشرفت یادگیری', style: theme.textTheme.labelSmall),
              Text(
                '${PersianFormat.digits(done)} از ${PersianFormat.digits(total)}',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _GatesTab extends StatelessWidget {
  const _GatesTab({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: <Widget>[
        const SectionHeader(
          title: 'مرجع گیت‌ها',
          subtitle:
              'هر کارت شامل نماد استاندارد، عبارت بولی و جدول حقیقت واقعی همان گیت است.',
        ),
        LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final int columns =
                constraints.maxWidth > 780
                    ? 2
                    : constraints.maxWidth > 480
                    ? 2
                    : 1;
            final double width =
                (constraints.maxWidth - (columns - 1) * 12) / columns;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: kGateDefinitions
                  .map(
                    (GateDefinition gate) =>
                        SizedBox(width: width, child: _GateCard(gate: gate)),
                  )
                  .toList(growable: false),
            );
          },
        ),
      ],
    );
  }
}

class _GateCard extends StatefulWidget {
  const _GateCard({required this.gate});

  final GateDefinition gate;

  @override
  State<_GateCard> createState() => _GateCardState();
}

class _GateCardState extends State<_GateCard> {
  bool _a = false;
  bool _b = false;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final GateDefinition gate = widget.gate;
    final bool output = gate.outputFor(_a, _b);

    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: theme.colorScheme.outlineVariant),
                ),
                child: Center(
                  child: GateSymbol(
                    type: gate.type,
                    size: 40,
                    strokeWidth: 1.8,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(gate.title, style: theme.textTheme.titleMedium),
                    const SizedBox(height: 3),
                    TechnicalText(
                      gate.expression,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(gate.description, style: theme.textTheme.bodySmall),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: theme.colorScheme.outlineVariant),
            ),
            child: Row(
              children: <Widget>[
                Icon(
                  Icons.tips_and_updates_outlined,
                  size: 16,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(gate.useCase, style: theme.textTheme.bodySmall),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Text('جدول حقیقت', style: theme.textTheme.titleSmall),
              const Spacer(),
              _MiniSwitch(
                label: 'A',
                value: _a,
                onChanged: (bool v) => setState(() => _a = v),
              ),
              const SizedBox(width: 6),
              _MiniSwitch(
                label: 'B',
                value: _b,
                onChanged: (bool v) => setState(() => _b = v),
              ),
              const SizedBox(width: 10),
              SignalPill(value: output, label: 'Y'),
            ],
          ),
          const SizedBox(height: 8),
          _TruthTableStrip(gate: gate, a: _a, b: _b),
          const SizedBox(height: 4),
          Row(
            children: <Widget>[
              Icon(
                Icons.touch_app_outlined,
                size: 14,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  'با تغییر کلیدهای A و B، خروجی زنده گیت به‌روز می‌شود.',
                  style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniSwitch extends StatelessWidget {
  const _MiniSwitch({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final LogicLabColors colors = LogicLabColors.of(context);
    return Semantics(
      label: 'ورودی $label',
      toggled: value,
      button: true,
      child: InkWell(
        onTap: () => onChanged(!value),
        borderRadius: BorderRadius.circular(9),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
          decoration: BoxDecoration(
            color:
                value
                    ? colors.highSignal.withValues(alpha: 0.12)
                    : theme.colorScheme.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(9),
            border: Border.all(
              color:
                  value
                      ? colors.highSignal.withValues(alpha: 0.4)
                      : theme.colorScheme.outlineVariant,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              TechnicalText(
                label,
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 5),
              TechnicalText(
                value ? '1' : '0',
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: value ? colors.highSignal : colors.lowSignal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TruthTableStrip extends StatelessWidget {
  const _TruthTableStrip({
    required this.gate,
    required this.a,
    required this.b,
  });

  final GateDefinition gate;
  final bool a;
  final bool b;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              _cell(context, 'A', header: true),
              _cell(context, 'B', header: true),
              _cell(context, 'Y', header: true),
            ],
          ),
          for (int index = 0; index < 4; index++)
            Row(
              children: <Widget>[
                _cell(context, index >= 2 ? '1' : '0'),
                _cell(context, index.isOdd ? '1' : '0'),
                Builder(
                  builder: (BuildContext context) {
                    final bool value = gate.truthTable[index];
                    final bool active =
                        (index >= 2 ? true : false) == a &&
                        (index.isOdd ? true : false) == b;
                    return Container(
                      width: 52,
                      height: 30,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color:
                            active
                                ? theme.colorScheme.primary.withValues(
                                  alpha: 0.08,
                                )
                                : null,
                        border: const Border(
                          right: BorderSide(color: Color(0x14000000)),
                        ),
                      ),
                      child: SignalPill(value: value, compact: true),
                    );
                  },
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _cell(BuildContext context, String text, {bool header = false}) {
    final ThemeData theme = Theme.of(context);
    return Container(
      width: 52,
      height: 30,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: header ? theme.colorScheme.surfaceContainer : null,
        border: const Border(
          right: BorderSide(color: Color(0x14000000)),
          bottom: BorderSide(color: Color(0x0F000000)),
        ),
      ),
      child: TechnicalText(
        text,
        style: theme.textTheme.labelSmall?.copyWith(
          fontWeight: header ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
    );
  }
}

class _PathsTab extends StatelessWidget {
  const _PathsTab({super.key, required this.learning});

  final LearningController learning;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return ListView(
      children: <Widget>[
        const SectionHeader(
          title: 'مسیرهای یادگیری',
          subtitle: 'از مبانی سیگنال تا طراحی تابع منطقی، مرحله به مرحله.',
        ),
        for (final LearningPath path in kLearningPaths) ...<Widget>[
          SurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Container(
                      width: 34,
                      height: 34,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: Text(
                        PersianFormat.digits(path.level),
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(path.title, style: theme.textTheme.titleMedium),
                          Text(path.subtitle, style: theme.textTheme.bodySmall),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                for (final String lessonId in path.lessonIds)
                  _LessonTile(
                    lesson: kLessons.firstWhere(
                      (LearningLesson lesson) => lesson.id == lessonId,
                    ),
                    completed: learning.isCompleted(lessonId),
                    onTap: () => _openLesson(context, lessonId),
                  ),
                for (final String challengeId in path.challengeIds)
                  _ChallengeTile(
                    challenge: kChallenges.firstWhere(
                      (LearningChallenge challenge) =>
                          challenge.id == challengeId,
                    ),
                    completed: learning.isCompleted(challengeId),
                    onTap: () => _openChallenge(context, challengeId),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _LessonTile extends StatelessWidget {
  const _LessonTile({
    required this.lesson,
    required this.completed,
    required this.onTap,
  });

  final LearningLesson lesson;
  final bool completed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: <Widget>[
            Icon(
              completed
                  ? Icons.check_circle_rounded
                  : Icons.play_circle_outline_rounded,
              color:
                  completed
                      ? LogicLabColors.of(context).success
                      : theme.colorScheme.primary,
              size: 20,
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(lesson.title, style: theme.textTheme.bodyMedium),
                  Text(
                    '${PersianFormat.digits(lesson.minutes)} دقیقه مطالعه',
                    style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_left_rounded,
              size: 18,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

class _ChallengeTile extends StatelessWidget {
  const _ChallengeTile({
    required this.challenge,
    required this.completed,
    required this.onTap,
  });

  final LearningChallenge challenge;
  final bool completed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: <Widget>[
            Icon(
              completed ? Icons.verified_rounded : Icons.flag_outlined,
              color:
                  completed
                      ? LogicLabColors.of(context).success
                      : theme.colorScheme.tertiary,
              size: 20,
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(challenge.title, style: theme.textTheme.bodyMedium),
                  Text(
                    'چالش عملی',
                    style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_left_rounded,
              size: 18,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

class _ChallengesTab extends StatelessWidget {
  const _ChallengesTab({super.key, required this.learning});

  final LearningController learning;

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: <Widget>[
        const SectionHeader(
          title: 'چالش‌های عملی',
          subtitle:
              'پاسخ چالش با شبیه‌سازی واقعی مدار سنجیده می‌شود، نه با حدس زدن.',
        ),
        for (final LearningChallenge challenge in kChallenges)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: SurfaceCard(
              onTap: () => _openChallenge(context, challenge.id),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Icon(
                        learning.isCompleted(challenge.id)
                            ? Icons.verified_rounded
                            : Icons.flag_outlined,
                        color:
                            learning.isCompleted(challenge.id)
                                ? LogicLabColors.of(context).success
                                : Theme.of(context).colorScheme.tertiary,
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Text(
                          challenge.title,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      const Icon(Icons.chevron_left_rounded, size: 18),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    challenge.brief,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: <Widget>[
                      Icon(
                        Icons.lightbulb_outline_rounded,
                        size: 15,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'راهنما: ${challenge.hint}',
                          style: Theme.of(
                            context,
                          ).textTheme.bodySmall?.copyWith(fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

Future<void> _openLesson(BuildContext context, String lessonId) async {
  final LearningLesson lesson = kLessons.firstWhere(
    (LearningLesson item) => item.id == lessonId,
  );
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (BuildContext context) {
      final ThemeData theme = Theme.of(context);
      return DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        maxChildSize: 0.94,
        builder: (BuildContext context, ScrollController controller) {
          return ListView(
            controller: controller,
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
            children: <Widget>[
              Text(lesson.title, style: theme.textTheme.headlineSmall),
              const SizedBox(height: 4),
              Text(
                '${PersianFormat.digits(lesson.minutes)} دقیقه مطالعه',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 14),
              for (final String paragraph in lesson.body) ...<Widget>[
                Text(paragraph, style: theme.textTheme.bodyMedium),
                const SizedBox(height: 12),
              ],
              if (lesson.gateType != null) ...<Widget>[
                Center(
                  child: Container(
                    width: 92,
                    height: 92,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: theme.colorScheme.outlineVariant,
                      ),
                    ),
                    child: Center(
                      child: GateSymbol(type: lesson.gateType!, size: 64),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              FilledButton(
                onPressed: () async {
                  await context.read<LearningController>().markCompleted(
                    lesson.id,
                  );
                  if (context.mounted) {
                    Navigator.pop(context);
                  }
                },
                child: const Text('این درس را خواندم'),
              ),
            ],
          );
        },
      );
    },
  );
}

Future<void> _openChallenge(BuildContext context, String challengeId) async {
  final LearningChallenge challenge = kChallenges.firstWhere(
    (LearningChallenge item) => item.id == challengeId,
  );
  final ProjectsController projects = context.read<ProjectsController>();
  final CircuitGraph graph = _challengeStarterGraph();
  try {
    final CircuitProject project = await projects.createNew(
      graph: graph,
      name: 'چالش: ${challenge.title}',
    );
    if (!context.mounted) {
      return;
    }
    await EditorLauncher.open(context, project, challenge: challenge);
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text('ساخت پروژه چالش انجام نشد: $error')),
        );
    }
  }
}

/// Builds the starter circuit for a challenge: two inputs and one output.
CircuitGraph _challengeStarterGraph() {
  return CircuitGraph(
    nodes: <CircuitNode>[
      CircuitNode(
        id: 'challenge-in-a',
        type: ComponentType.inputPin,
        position: const CanvasPoint(150, 190),
        label: 'A',
      ),
      CircuitNode(
        id: 'challenge-in-b',
        type: ComponentType.inputPin,
        position: const CanvasPoint(150, 340),
        label: 'B',
      ),
      CircuitNode(
        id: 'challenge-out',
        type: ComponentType.outputPin,
        position: const CanvasPoint(700, 265),
        label: 'Y',
      ),
    ],
  );
}
