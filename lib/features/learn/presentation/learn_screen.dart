import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/localization/persian_format.dart';
import '../../../core/theme/logic_lab_theme.dart';
import '../../../core/widgets/common.dart';
import '../../editor/presentation/circuit_editor_screen.dart';
import '../application/learning_controller.dart';
import '../domain/curriculum.dart';
import '../domain/learning_content.dart';
import '../domain/lesson_models.dart';
import '../domain/review_bank.dart';
import 'gate_reference_screen.dart';
import 'learning_session_screen.dart';
import 'practice_screen.dart';

/// The learning home: where to continue, the unit map, spaced review and
/// free practice. It never locks the rest of the app; the editor stays a tap
/// away for learners who only want to build circuits.
class LearnScreen extends StatelessWidget {
  const LearnScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final LearningController learning = context.watch<LearningController>();
    final ThemeData theme = Theme.of(context);
    if (learning.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ResponsiveCenter(
          maxWidth: 940,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
          child: ListView(
            children: <Widget>[
              _Header(learning: learning),
              const SizedBox(height: 16),
              _ContinueCard(learning: learning),
              if (!learning.state.onboardingSeen) ...<Widget>[
                const SizedBox(height: 14),
                _OnboardingCard(learning: learning),
              ],
              const SizedBox(height: 22),
              SectionHeader(
                title: 'مسیر یادگیری',
                subtitle:
                    'درس‌ها یکی‌یکی باز می‌شوند؛ هر درس کوتاه است و با تمرین تمام می‌شود.',
                trailing: Text(
                  '${PersianFormat.digits(_completedLessons(learning))} از '
                  '${PersianFormat.digits(kLessons.length)}',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              for (int index = 0; index < kCurriculum.length; index++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _UnitCard(
                    unit: kCurriculum[index],
                    number: index + 1,
                    learning: learning,
                  ),
                ),
              const SizedBox(height: 10),
              _ReviewCard(learning: learning),
              const SizedBox(height: 18),
              _QuickActions(learning: learning),
            ],
          ),
        ),
      ),
    );
  }
}

int _completedLessons(LearningController learning) =>
    kLessons
        .where((LearningLesson lesson) => learning.isLessonCompleted(lesson.id))
        .length;

class _Header extends StatelessWidget {
  const _Header({required this.learning});

  final LearningController learning;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final LogicLabColors colors = LogicLabColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const BrandMark(size: 42, showName: true),
              const Spacer(),
              IconButton(
                tooltip: 'راهنمای یادگیری',
                onPressed: () => showLearningHelp(context),
                icon: const Icon(Icons.help_outline_rounded),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              _StatPill(
                icon: Icons.bolt_rounded,
                label: '${PersianFormat.digits(learning.xp)} XP',
                color: colors.warning,
              ),
              _StatPill(
                icon: Icons.local_fire_department_outlined,
                label: '${PersianFormat.digits(learning.streak)} روز پیاپی',
                color: theme.colorScheme.tertiary,
              ),
              _StatPill(
                icon: Icons.workspace_premium_outlined,
                label: 'سطح ${PersianFormat.digits(learning.level)}',
                color: theme.colorScheme.primary,
              ),
              if (learning.practicedConceptCount > 0)
                _StatPill(
                  icon: Icons.psychology_outlined,
                  label:
                      '${PersianFormat.digits(learning.masteredConceptCount)} مفهوم مسلط',
                  color: colors.success,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  const _StatPill({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _ContinueCard extends StatelessWidget {
  const _ContinueCard({required this.learning});

  final LearningController learning;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final LearningLesson? next = learning.nextLesson;
    final bool allDone = next == null;
    final LearningLesson lesson = next ?? kLessons.last;
    final LearningUnit unit = unitOfLesson(lesson.id) ?? kCurriculum.first;
    final double lessonProgress = learning.lessonProgress(lesson);
    final int completed = _completedLessons(learning);
    final double courseProgress =
        kLessons.isEmpty ? 0 : completed / kLessons.length;
    final int resume = learning.resumeStepIndex(lesson);
    final bool started = lessonProgress > 0;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(
                allDone
                    ? Icons.emoji_events_rounded
                    : Icons.play_circle_outline_rounded,
                size: 18,
                color: theme.colorScheme.onPrimary,
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  allDone ? 'دوره کامل شد' : 'ادامهٔ یادگیری',
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.onPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${PersianFormat.digits(completed)}/${PersianFormat.digits(kLessons.length)} درس',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onPrimary.withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            unit.title,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onPrimary.withValues(alpha: 0.75),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            lesson.title,
            style: theme.textTheme.headlineSmall?.copyWith(
              color: theme.colorScheme.onPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            allDone
                ? 'همهٔ درس‌ها را کامل کرده‌اید. با مرور هوشمند و تمرین آزاد ادامه دهید.'
                : lesson.subtitle,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onPrimary.withValues(alpha: 0.85),
              height: 1.6,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 6,
            children: <Widget>[
              _HeroMeta(
                icon: Icons.schedule_rounded,
                label: '${PersianFormat.digits(lesson.minutes)} دقیقه',
              ),
              _HeroMeta(
                icon: Icons.format_list_numbered_rounded,
                label: '${PersianFormat.digits(lesson.steps.length)} گام',
              ),
              if (started && !allDone)
                _HeroMeta(
                  icon: Icons.play_arrow_rounded,
                  label: 'ادامه از گام ${PersianFormat.digits(resume + 1)}',
                ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: allDone ? 1 : courseProgress,
              minHeight: 7,
              backgroundColor: theme.colorScheme.onPrimary.withValues(
                alpha: 0.22,
              ),
              color: theme.colorScheme.onPrimary,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: <Widget>[
              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: theme.colorScheme.onPrimary,
                    foregroundColor: theme.colorScheme.primary,
                  ),
                  onPressed: () => _openLesson(context, lesson),
                  icon: Icon(
                    allDone
                        ? Icons.replay_rounded
                        : started
                        ? Icons.play_arrow_rounded
                        : Icons.rocket_launch_rounded,
                  ),
                  label: Text(
                    allDone
                        ? 'مرور دوبارهٔ درس'
                        : started
                        ? 'ادامهٔ درس'
                        : 'شروع درس',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: theme.colorScheme.onPrimary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: <Widget>[
                Icon(
                  Icons.today_outlined,
                  size: 16,
                  color: theme.colorScheme.onPrimary,
                ),
                const SizedBox(width: 7),
                Text(
                  'هدف امروز',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: learning.dailyProgress,
                      minHeight: 5,
                      backgroundColor: theme.colorScheme.onPrimary.withValues(
                        alpha: 0.2,
                      ),
                      color: theme.colorScheme.onPrimary,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  '${PersianFormat.digits(learning.xpToday)}/'
                  '${PersianFormat.digits(learning.dailyGoalXp)}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroMeta extends StatelessWidget {
  const _HeroMeta({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(icon, size: 14, color: theme.colorScheme.onPrimary),
        const SizedBox(width: 4),
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onPrimary.withValues(alpha: 0.9),
          ),
        ),
      ],
    );
  }
}

class _OnboardingCard extends StatelessWidget {
  const _OnboardingCard({required this.learning});

  final LearningController learning;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const IconTile(icon: Icons.explore_outlined),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'چطور یاد بگیریم؟',
                      style: theme.textTheme.titleMedium,
                    ),
                    Text(
                      'یک راهنمای کوتاه برای شروع',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const _OnboardingPoint(
            icon: Icons.timer_outlined,
            text:
                'هر درس فقط ۳ تا ۷ دقیقه است؛ همان روز یک مفهوم را تمام کنید.',
          ),
          const _OnboardingPoint(
            icon: Icons.touch_app_outlined,
            text:
                'بین توضیح‌ها، خروجی را حدس بزنید، جدول را کامل کنید و مدار بسازید.',
          ),
          const _OnboardingPoint(
            icon: Icons.save_outlined,
            text: 'پیشرفت، XP و مرور خودکار ذخیره می‌شوند؛ همه‌چیز آفلاین است.',
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Expanded(
                child: FilledButton(
                  onPressed: () => learning.saveOnboardingSeen(),
                  child: const Text('شروع می‌کنم'),
                ),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: () => showLearningHelp(context),
                child: const Text('راهنمای کامل'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _OnboardingPoint extends StatelessWidget {
  const _OnboardingPoint({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, size: 17, color: theme.colorScheme.primary),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodySmall?.copyWith(height: 1.7),
            ),
          ),
        ],
      ),
    );
  }
}

class _UnitCard extends StatelessWidget {
  const _UnitCard({
    required this.unit,
    required this.number,
    required this.learning,
  });

  final LearningUnit unit;
  final int number;
  final LearningController learning;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final int done =
        unit.lessons
            .where(
              (LearningLesson lesson) => learning.isLessonCompleted(lesson.id),
            )
            .length;
    final bool unitComplete = done == unit.lessons.length;
    return SurfaceCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Row(
              children: <Widget>[
                Container(
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color:
                        unitComplete
                            ? LogicLabColors.of(
                              context,
                            ).success.withValues(alpha: 0.12)
                            : theme.colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    PersianFormat.digits(number),
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color:
                          unitComplete
                              ? LogicLabColors.of(context).success
                              : theme.colorScheme.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(unit.title, style: theme.textTheme.titleMedium),
                      Text(unit.subtitle, style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
                Text(
                  '${PersianFormat.digits(done)}/${PersianFormat.digits(unit.lessons.length)}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          for (final LearningLesson lesson in unit.lessons)
            _LessonRow(lesson: lesson, learning: learning),
        ],
      ),
    );
  }
}

class _LessonRow extends StatelessWidget {
  const _LessonRow({required this.lesson, required this.learning});

  final LearningLesson lesson;
  final LearningController learning;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final LogicLabColors colors = LogicLabColors.of(context);
    final bool completed = learning.isLessonCompleted(lesson.id);
    final bool unlocked = learning.canOpenLesson(lesson.id);
    final bool current = learning.nextLesson?.id == lesson.id;
    final double progress = learning.lessonProgress(lesson);
    final int doneSteps = (progress * lesson.steps.length).round();

    final String status;
    final Color statusColor;
    if (completed) {
      status = 'کامل شد';
      statusColor = colors.success;
    } else if (!unlocked) {
      status = 'قفل';
      statusColor = theme.colorScheme.onSurfaceVariant;
    } else if (progress > 0) {
      status =
          'گام ${PersianFormat.digits(doneSteps)} از ${PersianFormat.digits(lesson.steps.length)}';
      statusColor = theme.colorScheme.primary;
    } else {
      status = '${PersianFormat.digits(lesson.minutes)} دقیقه';
      statusColor = theme.colorScheme.onSurfaceVariant;
    }

    return Opacity(
      opacity: unlocked ? 1 : 0.55,
      child: InkWell(
        onTap:
            unlocked
                ? () => _openLesson(context, lesson)
                : () => _lockedMessage(context),
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
          decoration: BoxDecoration(
            color:
                current && !completed
                    ? theme.colorScheme.primary.withValues(alpha: 0.045)
                    : null,
            border: Border(
              top: BorderSide(color: theme.colorScheme.outlineVariant),
            ),
          ),
          child: Row(
            children: <Widget>[
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color:
                      completed
                          ? colors.success.withValues(alpha: 0.12)
                          : unlocked
                          ? theme.colorScheme.primary.withValues(alpha: 0.08)
                          : theme.colorScheme.surfaceContainer,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color:
                        completed
                            ? colors.success.withValues(alpha: 0.3)
                            : unlocked
                            ? theme.colorScheme.primary.withValues(alpha: 0.2)
                            : theme.colorScheme.outlineVariant,
                  ),
                ),
                child: Icon(
                  completed
                      ? Icons.check_rounded
                      : unlocked
                      ? Icons.play_arrow_rounded
                      : Icons.lock_outline_rounded,
                  size: 18,
                  color:
                      completed
                          ? colors.success
                          : unlocked
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Flexible(
                          child: Text(
                            lesson.title,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight:
                                  current && !completed
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                            ),
                          ),
                        ),
                        if (current && !completed) ...<Widget>[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary.withValues(
                                alpha: 0.1,
                              ),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'بعدی',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.w700,
                                fontSize: 9.5,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      lesson.subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                status,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: statusColor,
                  fontWeight: completed || current ? FontWeight.w600 : null,
                ),
              ),
              const SizedBox(width: 2),
              Icon(
                unlocked ? Icons.chevron_left_rounded : Icons.lock_rounded,
                size: 17,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({required this.learning});

  final LearningController learning;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final LogicLabColors colors = LogicLabColors.of(context);
    final List<String> concepts = learning.reviewConceptIds;
    final bool hasReview = concepts.isNotEmpty;
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              IconTile(
                icon: Icons.auto_awesome_outlined,
                color: hasReview ? colors.warning : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('مرور هوشمند', style: theme.textTheme.titleMedium),
                    Text(
                      hasReview
                          ? 'این مفاهیم برای تثبیت به تمرین کوتاه نیاز دارند.'
                          : 'با تمرین کردن، مفاهیم ضعیف یا سررسیده اینجا ظاهر می‌شوند.',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (hasReview) ...<Widget>[
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: <Widget>[
                for (final String concept in concepts)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: colors.warning.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: colors.warning.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Text(
                      conceptLabel(concept),
                      style: theme.textTheme.labelSmall,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: FilledButton.tonalIcon(
                onPressed: () => _startReview(context, learning),
                icon: const Icon(Icons.replay_rounded, size: 18),
                label: const Text('شروع مرور'),
              ),
            ),
          ] else ...<Widget>[
            const SizedBox(height: 10),
            Text(
              'پس از پاسخ به تمرین‌ها، زمان مرور هر مفهوم به‌صورت شفاف '
              'محاسبه و ذخیره می‌شود.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.7,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({required this.learning});

  final LearningController learning;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final int doneChallenges =
        kChallenges
            .where((LearningChallenge item) => learning.isCompleted(item.id))
            .length;
    return SurfaceCard(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        children: <Widget>[
          _QuickRow(
            icon: Icons.flag_outlined,
            title: 'تمرین آزاد',
            subtitle:
                '${PersianFormat.digits(doneChallenges)} از '
                '${PersianFormat.digits(kChallenges.length)} چالش تکمیل شده',
            onTap:
                () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (BuildContext context) => const PracticeScreen(),
                  ),
                ),
          ),
          Divider(height: 1, color: theme.colorScheme.outlineVariant),
          _QuickRow(
            icon: Icons.menu_book_outlined,
            title: 'مرجع گیت‌ها',
            subtitle: 'نماد، عبارت و جدول حقیقت تعاملی هفت گیت',
            onTap:
                () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder:
                        (BuildContext context) => const GateReferenceScreen(),
                  ),
                ),
          ),
          Divider(height: 1, color: theme.colorScheme.outlineVariant),
          _QuickRow(
            icon: Icons.add_box_outlined,
            title: 'ساخت مدار',
            subtitle: 'ورود مستقیم به ویرایشگر، بدون نیاز به درس',
            onTap: () => EditorLauncher.createAndOpen(context),
          ),
        ],
      ),
    );
  }
}

class _QuickRow extends StatelessWidget {
  const _QuickRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Row(
          children: <Widget>[
            Icon(icon, size: 21, color: theme.colorScheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(title, style: theme.textTheme.bodyMedium),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_left_rounded, size: 18),
          ],
        ),
      ),
    );
  }
}

Future<void> _openLesson(BuildContext context, LearningLesson lesson) {
  return Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (BuildContext context) => LearningSessionScreen(lesson: lesson),
    ),
  );
}

void _lockedMessage(BuildContext context) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      const SnackBar(
        content: Text('برای باز شدن این درس، درس قبلی را کامل کنید.'),
      ),
    );
}

void _startReview(BuildContext context, LearningController learning) {
  final List<LessonStep> steps = buildReviewSteps(learning.reviewConceptIds);
  if (steps.isEmpty) {
    return;
  }
  final LearningLesson review = LearningLesson(
    id: 'review',
    title: 'مرور هوشمند',
    subtitle: 'تمرین کوتاه مفاهیم نیازمند مرور',
    minutes: 3,
    steps: steps,
  );
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder:
          (BuildContext context) =>
              LearningSessionScreen(lesson: review, review: true),
    ),
  );
}

/// Revisitable walkthrough: explains the learning loop without blocking use of
/// the editor. Opened from the help icon and from the first-run card.
Future<void> showLearningHelp(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (BuildContext context) {
      final ThemeData theme = Theme.of(context);
      return DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        maxChildSize: 0.92,
        builder: (BuildContext context, ScrollController controller) {
          return ListView(
            controller: controller,
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
            children: <Widget>[
              Text('راهنمای یادگیری', style: theme.textTheme.headlineSmall),
              const SizedBox(height: 6),
              Text(
                'مسیر یادگیری اختیاری است؛ هر زمان بخواهید می‌توانید مستقیم '
                'به ویرایشگر بروید.',
                style: theme.textTheme.bodySmall?.copyWith(height: 1.7),
              ),
              const SizedBox(height: 16),
              const _HelpItem(
                icon: Icons.route_outlined,
                title: 'از کجا شروع کنم؟',
                body:
                    'کارت «ادامهٔ یادگیری» همیشه درس بعدی را نشان می‌دهد. '
                    'درس‌ها به ترتیب باز می‌شوند و هر کدام چند دقیقه است.',
              ),
              const _HelpItem(
                icon: Icons.touch_app_outlined,
                title: 'در هر درس چه کار می‌کنم؟',
                body:
                    'اول یک مفهوم کوتاه را می‌بینید، بعد خروجی را حدس می‌زنید، '
                    'جدول حقیقت را کامل می‌کنید یا در ویرایشگر واقعی مدار می‌سازید.',
              ),
              const _HelpItem(
                icon: Icons.tips_and_updates_outlined,
                title: 'اگر اشتباه کنم؟',
                body:
                    'هیچ امتیازی از دست نمی‌دهید. بازخورد دقیق می‌بینید، '
                    'می‌توانید راهنمای مرحله‌ای بگیرید و دوباره تلاش کنید. '
                    'پاسخ درست فقط پس از تلاش کافی نمایش داده می‌شود.',
              ),
              const _HelpItem(
                icon: Icons.auto_awesome_outlined,
                title: 'مرور چطور کار می‌کند؟',
                body:
                    'هر پاسخ، تسلط شما روی آن مفهوم را به‌روز می‌کند. مفاهیم '
                    'ضعیف یا سررسیده در «مرور هوشمند» دوباره تمرین می‌شوند. '
                    'این برنامه از قاعدهٔ ساده و شفاف استفاده می‌کند، نه مدل پنهان.',
              ),
              const _HelpItem(
                icon: Icons.save_outlined,
                title: 'پیشرفت کجا ذخیره می‌شود؟',
                body:
                    'همه‌چیز روی همین دستگاه و بدون اینترنت ذخیره می‌شود. '
                    'با پشتیبان JSON در تنظیمات می‌توانید آن را منتقل کنید.',
              ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('متوجه شدم'),
              ),
            ],
          );
        },
      );
    },
  );
}

class _HelpItem extends StatelessWidget {
  const _HelpItem({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          IconTile(icon: icon, size: 38, iconSize: 19),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(title, style: theme.textTheme.titleSmall),
                const SizedBox(height: 3),
                Text(
                  body,
                  style: theme.textTheme.bodySmall?.copyWith(height: 1.7),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
