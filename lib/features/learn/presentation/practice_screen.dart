import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/localization/persian_format.dart';
import '../../../core/theme/logic_lab_theme.dart';
import '../../../core/widgets/common.dart';
import '../application/learning_controller.dart';
import '../domain/learning_content.dart';
import '../domain/lesson_models.dart';
import 'challenge_launcher.dart';

/// Free practice: every challenge of the curriculum is playable at any time,
/// independent of the lesson path. Solutions are validated by the simulator.
class PracticeScreen extends StatelessWidget {
  const PracticeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final LearningController learning = context.watch<LearningController>();
    final int done = kChallenges
        .where((LearningChallenge item) => learning.isCompleted(item.id))
        .length;
    return Scaffold(
      appBar: AppBar(title: const Text('تمرین آزاد')),
      body: SafeArea(
        bottom: false,
        child: ResponsiveCenter(
          maxWidth: 860,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
          child: ListView(
            children: <Widget>[
              SectionHeader(
                title: 'چالش‌های مدار',
                subtitle:
                    'هر پاسخ با شبیه‌ساز واقعی سنجیده می‌شود؛ '
                    '${PersianFormat.digits(done)} از ${PersianFormat.digits(kChallenges.length)} چالش تکمیل شده است.',
              ),
              for (final LearningChallenge challenge in kChallenges)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _ChallengeCard(
                    challenge: challenge,
                    completed: learning.isCompleted(challenge.id),
                    onTap: () => launchChallenge(context, challenge),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChallengeCard extends StatelessWidget {
  const _ChallengeCard({
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
    final LogicLabColors colors = LogicLabColors.of(context);
    return SurfaceCard(
      onTap: onTap,
      semanticLabel: challenge.title,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(
                completed ? Icons.verified_rounded : Icons.flag_outlined,
                color: completed ? colors.success : theme.colorScheme.tertiary,
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  challenge.title,
                  style: theme.textTheme.titleMedium,
                ),
              ),
              const Icon(Icons.chevron_left_rounded, size: 18),
            ],
          ),
          const SizedBox(height: 7),
          Text(challenge.brief, style: theme.textTheme.bodySmall),
          if (challenge.concepts.isNotEmpty) ...<Widget>[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: <Widget>[
                for (final String concept in challenge.concepts)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: theme.colorScheme.outlineVariant,
                      ),
                    ),
                    child: Text(
                      conceptLabel(concept),
                      style: theme.textTheme.labelSmall,
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
