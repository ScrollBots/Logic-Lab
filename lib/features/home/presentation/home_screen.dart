import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/localization/persian_format.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/gate_symbol.dart';
import '../../boolean_tools/presentation/boolean_workspace_screen.dart';
import '../../editor/domain/circuit_models.dart';
import '../../editor/presentation/circuit_editor_screen.dart';
import '../../editor/presentation/circuit_preview.dart';
import '../../learn/application/learning_controller.dart';
import '../../learn/domain/learning_content.dart';
import '../../projects/application/projects_controller.dart';
import '../../projects/domain/circuit_project.dart';
import '../../settings/application/settings_controller.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    required this.onOpenProjects,
    required this.onOpenLearn,
  });

  final VoidCallback onOpenProjects;
  final VoidCallback onOpenLearn;

  @override
  Widget build(BuildContext context) {
    final ProjectsController projects = context.watch<ProjectsController>();
    final LearningController learning = context.watch<LearningController>();
    final SettingsController settings = context.watch<SettingsController>();

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: () async {
            await projects.refresh();
            await learning.load();
          },
          child: ResponsiveCenter(
            maxWidth: 1120,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
            child: ListView(
              children: <Widget>[
                _header(context, settings),
                const SizedBox(height: 18),
                _heroCard(context),
                const SizedBox(height: 18),
                if (projects.isLoading)
                  const _LoadingBlock()
                else if (projects.isEmpty)
                  _emptyState(context)
                else ...<Widget>[
                  _continueCard(context, projects),
                  const SizedBox(height: 18),
                  _recentProjects(context, projects),
                ],
                const SizedBox(height: 18),
                _quickGates(context),
                const SizedBox(height: 18),
                _learningSection(context, learning),
                const SizedBox(height: 18),
                _toolsSection(context),
                if (projects.loadError != null) ...<Widget>[
                  const SizedBox(height: 18),
                  InfoBanner(
                    tone: InfoBannerTone.danger,
                    message: projects.loadError!,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _header(BuildContext context, SettingsController settings) {
    final ThemeData theme = Theme.of(context);
    final DateTime now = PersianFormat.tehranNow();
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          const BrandMark(size: 42, showName: true),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: theme.colorScheme.outlineVariant),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(
                  Icons.wb_sunny_outlined,
                  size: 15,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
                Text(
                  PersianFormat.clock(now),
                  style: theme.textTheme.labelSmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _heroCard(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'از ایده تا مدار، همین‌جا',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: theme.colorScheme.onPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'گیت‌ها را روی بوم بچینید، سیم بکشید و نتیجه را زنده ببینید. '
                      'همه‌چیز آفلاین روی همین دستگاه ذخیره می‌شود.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onPrimary.withValues(
                          alpha: 0.86,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Opacity(
                opacity: 0.9,
                child: CustomPaint(
                  size: const Size(72, 72),
                  painter: _HeroGlyphPainter(
                    color: theme.colorScheme.onPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: <Widget>[
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: theme.colorScheme.onPrimary,
                  foregroundColor: theme.colorScheme.primary,
                ),
                onPressed: () => EditorLauncher.createAndOpen(context),
                icon: const Icon(Icons.add_rounded),
                label: const Text('مدار جدید'),
              ),
              const SizedBox(width: 10),
              TextButton.icon(
                style: TextButton.styleFrom(
                  foregroundColor: theme.colorScheme.onPrimary,
                ),
                onPressed:
                    () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder:
                            (BuildContext context) =>
                                const BooleanWorkspaceScreen(),
                      ),
                    ),
                icon: const Icon(Icons.functions_rounded),
                label: const Text('عبارت بولی'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _continueCard(BuildContext context, ProjectsController projects) {
    final ThemeData theme = Theme.of(context);
    final CircuitProject? project = projects.mostRecent;
    if (project == null) {
      return const SizedBox.shrink();
    }
    return SurfaceCard(
      onTap: () => EditorLauncher.open(context, project),
      semanticLabel: 'ادامه کار روی ${project.name}',
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
            child: Row(
              children: <Widget>[
                IconTile(icon: Icons.play_circle_outline_rounded),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'ادامه کار',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        project.name,
                        style: theme.textTheme.titleLarge,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'آخرین ویرایش: ${PersianFormat.relativeDate(project.updatedAt)}',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_left_rounded),
              ],
            ),
          ),
          SizedBox(height: 116, child: CircuitPreview(graph: project.graph)),
        ],
      ),
    );
  }

  Widget _recentProjects(BuildContext context, ProjectsController projects) {
    final List<CircuitProject> recent = projects.projects.take(4).toList();
    if (recent.isEmpty) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SectionHeader(
          title: 'مدارهای اخیر',
          subtitle:
              '${PersianFormat.digits(projects.count)} مدار ذخیره شده است.',
          trailing: TextButton.icon(
            onPressed: onOpenProjects,
            icon: const Icon(Icons.list_rounded),
            label: const Text('همه'),
          ),
        ),
        LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final int columns = constraints.maxWidth > 720 ? 4 : 2;
            final double width =
                (constraints.maxWidth - (columns - 1) * 10) / columns;
            return Wrap(
              spacing: 10,
              runSpacing: 10,
              children: recent
                  .map(
                    (CircuitProject project) => SizedBox(
                      width: width,
                      child: _ProjectTile(project: project),
                    ),
                  )
                  .toList(growable: false),
            );
          },
        ),
      ],
    );
  }

  Widget _quickGates(BuildContext context) {
    const List<ComponentType> gates = <ComponentType>[
      ComponentType.andGate,
      ComponentType.orGate,
      ComponentType.notGate,
      ComponentType.xorGate,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const SectionHeader(
          title: 'شروع سریع',
          subtitle:
              'یک مدار آماده با گیت انتخابی بسازید و همان لحظه ویرایش کنید.',
        ),
        SizedBox(
          height: 104,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: gates.length,
            separatorBuilder:
                (BuildContext context, int index) => const SizedBox(width: 10),
            itemBuilder: (BuildContext context, int index) {
              final ComponentType type = gates[index];
              return SurfaceCard(
                onTap:
                    () => EditorLauncher.createAndOpen(
                      context,
                      quickGate: type,
                      name: 'مدار ${type.technicalName}',
                    ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                child: SizedBox(
                  width: 96,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      GateSymbol(type: type, size: 40, strokeWidth: 1.8),
                      const SizedBox(height: 8),
                      Text(
                        type.technicalName,
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _learningSection(BuildContext context, LearningController learning) {
    final ThemeData theme = Theme.of(context);
    final int total = kLessons.length + kChallenges.length;
    final int done = learning.completedCount;
    final double ratio = total == 0 ? 0 : done / total;
    final LearningChallenge? nextChallenge = kChallenges
        .cast<LearningChallenge?>()
        .firstWhere(
          (LearningChallenge? item) =>
              item != null && !learning.isCompleted(item.id),
          orElse: () => null,
        );

    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              IconTile(icon: Icons.school_outlined),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('مسیر یادگیری', style: theme.textTheme.titleMedium),
                    Text(
                      '${PersianFormat.digits(done)} از ${PersianFormat.digits(total)} مورد تکمیل شده',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 7,
              backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
            ),
          ),
          if (nextChallenge != null) ...<Widget>[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: theme.colorScheme.outlineVariant),
              ),
              child: Row(
                children: <Widget>[
                  Icon(
                    Icons.flag_outlined,
                    size: 18,
                    color: theme.colorScheme.tertiary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'چالش بعدی: ${nextChallenge.title}',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          nextChallenge.brief,
                          style: theme.textTheme.bodySmall,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_left_rounded, size: 18),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _toolsSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const SectionHeader(
          title: 'ابزارها',
          subtitle: 'ابزارهای تخصصی برای تحلیل مدارهای ترکیبی.',
        ),
        LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final int columns = constraints.maxWidth > 640 ? 2 : 1;
            final double width =
                (constraints.maxWidth - (columns - 1) * 12) / columns;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: <Widget>[
                SizedBox(
                  width: width,
                  child: _ToolCard(
                    icon: Icons.functions_rounded,
                    title: 'عبارت بولی',
                    description:
                        'تجزیه، جدول حقیقت، ساده‌سازی و مقایسه عبارت‌ها و ساخت مدار از روی عبارت.',
                    actionLabel: 'باز کردن',
                    onTap:
                        () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder:
                                (BuildContext context) =>
                                    const BooleanWorkspaceScreen(),
                          ),
                        ),
                  ),
                ),
                SizedBox(
                  width: width,
                  child: _ToolCard(
                    icon: Icons.school_outlined,
                    title: 'آموزش و چالش',
                    description:
                        'مرجع گیت‌ها، درس‌های گام‌به‌گام و چالش‌هایی که با مدار واقعی سنجیده می‌شوند.',
                    actionLabel: 'دیدن مسیر',
                    onTap: onOpenLearn,
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _emptyState(BuildContext context) {
    return Column(
      children: <Widget>[
        SurfaceCard(
          child: Column(
            children: <Widget>[
              Container(
                width: 62,
                height: 62,
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(
                  Icons.account_tree_outlined,
                  size: 30,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'هنوز مداری نساخته‌اید',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 6),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Text(
                  'اولین مدار خود را بسازید: چند گیت را روی بوم بگذارید، سیم بکشید و نتیجه را ببینید. '
                  'همه چیز آفلاین ذخیره می‌شود.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () => EditorLauncher.createAndOpen(context),
                icon: const Icon(Icons.add_rounded),
                label: const Text('ساخت اولین مدار'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ProjectTile extends StatelessWidget {
  const _ProjectTile({required this.project});

  final CircuitProject project;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return SurfaceCard(
      onTap: () => EditorLauncher.open(context, project),
      padding: EdgeInsets.zero,
      semanticLabel: 'باز کردن ${project.name}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            height: 82,
            child: CircuitPreview(graph: project.graph, padding: 8),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  project.name,
                  style: theme.textTheme.titleSmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  PersianFormat.relativeDate(project.updatedAt),
                  style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ToolCard extends StatelessWidget {
  const _ToolCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.actionLabel,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String description;
  final String actionLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return SurfaceCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              IconTile(icon: icon),
              const SizedBox(width: 10),
              Expanded(child: Text(title, style: theme.textTheme.titleMedium)),
            ],
          ),
          const SizedBox(height: 10),
          Text(description, style: theme.textTheme.bodySmall),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Text(
                actionLabel,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.chevron_left_rounded,
                size: 16,
                color: theme.colorScheme.primary,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LoadingBlock extends StatelessWidget {
  const _LoadingBlock();

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      child: Row(
        children: <Widget>[
          const SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2.4),
          ),
          const SizedBox(width: 14),
          Text(
            'در حال بارگذاری مدارها…',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

class _HeroGlyphPainter extends CustomPainter {
  const _HeroGlyphPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint stroke =
        Paint()
          ..color = color.withValues(alpha: 0.75)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round;
    final double left = size.width * 0.1;
    final double right = size.width * 0.62;
    final double top = size.height * 0.22;
    final double bottom = size.height * 0.78;
    final double mid = size.height * 0.5;
    final Path gate =
        Path()
          ..moveTo(left, top)
          ..lineTo(size.width * 0.36, top)
          ..cubicTo(right, top, right + 6, mid - 6, right, mid)
          ..cubicTo(
            right + 6,
            mid + 6,
            right,
            bottom,
            size.width * 0.36,
            bottom,
          )
          ..lineTo(left, bottom)
          ..close();
    canvas.drawPath(gate, stroke);
    canvas.drawLine(Offset(0, mid), Offset(left, mid), stroke);
    canvas.drawLine(Offset(right, mid), Offset(size.width, mid), stroke);
    canvas.drawCircle(Offset(size.width, mid), 3, Paint()..color = color);
    canvas.drawCircle(
      Offset(size.width * 0.45, top),
      2.4,
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(covariant _HeroGlyphPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}
