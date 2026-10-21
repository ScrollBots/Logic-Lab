import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/localization/persian_format.dart';
import '../../../core/widgets/common.dart';
import '../../editor/domain/circuit_models.dart';
import '../../editor/domain/circuit_simulator.dart';
import '../../projects/application/projects_controller.dart';
import '../../projects/domain/circuit_project.dart';
import '../domain/circuit_analyzer.dart';

/// Analysis screen for a circuit.
///
/// It shows the static structure of the circuit (gate count, depth, …) and
/// lets the user compare the circuit with a second one through their real
/// truth tables.
class CircuitAnalysisScreen extends StatefulWidget {
  const CircuitAnalysisScreen({
    super.key,
    required this.project,
    required this.graph,
  });

  final CircuitProject project;
  final CircuitGraph graph;

  @override
  State<CircuitAnalysisScreen> createState() => _CircuitAnalysisScreenState();
}

class _CircuitAnalysisScreenState extends State<CircuitAnalysisScreen> {
  CircuitProject? _comparison;
  CircuitComparison? _result;
  bool _busy = false;

  Future<void> _pickComparison() async {
    final ProjectsController projects = context.read<ProjectsController>();
    final List<CircuitProject> candidates =
        projects.projects
            .where((CircuitProject project) => project.id != widget.project.id)
            .toList();
    if (candidates.isEmpty) {
      _toast('مدار دیگری برای مقایسه وجود ندارد. ابتدا یک مدار دیگر بسازید.');
      return;
    }
    final CircuitProject? selected = await showModalBottomSheet<CircuitProject>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (BuildContext context) {
        final ThemeData theme = Theme.of(context);
        return ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
              child: Text(
                'انتخاب مدار برای مقایسه',
                style: theme.textTheme.titleLarge,
              ),
            ),
            for (final CircuitProject project in candidates)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: SurfaceCard(
                  onTap: () => Navigator.pop(context, project),
                  child: Row(
                    children: <Widget>[
                      IconTile(icon: Icons.account_tree_outlined, size: 38),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              project.name,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              '${PersianFormat.digits(project.componentCount)} قطعه',
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_left_rounded),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
    if (selected == null || !mounted) {
      return;
    }
    setState(() {
      _busy = true;
      _comparison = selected;
    });
    final CircuitComparison result = CircuitAnalyzer.compare(
      widget.graph,
      selected.graph,
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _result = result;
      _busy = false;
    });
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final CircuitStatistics statistics = CircuitAnalyzer.statisticsOf(
      widget.graph,
    );
    final SimulationResult simulation =
        CircuitSimulator(widget.graph).evaluate();

    return Scaffold(
      appBar: AppBar(title: const Text('تحلیل مدار')),
      body: SafeArea(
        top: false,
        child: ResponsiveCenter(
          maxWidth: 900,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: ListView(
            children: <Widget>[
              SurfaceCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      widget.project.name,
                      style: theme.textTheme.titleLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'ساختار مدار و وضعیت محاسبه‌شده توسط شبیه‌ساز واقعی.',
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: <Widget>[
                        _Stat(
                          icon: Icons.memory_rounded,
                          label: 'گیت',
                          value: PersianFormat.digits(statistics.gateCount),
                        ),
                        _Stat(
                          icon: Icons.widgets_rounded,
                          label: 'قطعه',
                          value: PersianFormat.digits(
                            statistics.componentCount,
                          ),
                        ),
                        _Stat(
                          icon: Icons.linear_scale_rounded,
                          label: 'سیم',
                          value: PersianFormat.digits(statistics.wireCount),
                        ),
                        _Stat(
                          icon: Icons.login_rounded,
                          label: 'ورودی',
                          value: PersianFormat.digits(statistics.inputCount),
                        ),
                        _Stat(
                          icon: Icons.logout_rounded,
                          label: 'خروجی',
                          value: PersianFormat.digits(statistics.outputCount),
                        ),
                        _Stat(
                          icon: Icons.account_tree_rounded,
                          label: 'عمق',
                          value: PersianFormat.digits(statistics.depth),
                        ),
                        _Stat(
                          icon: Icons.schedule_rounded,
                          label: 'ترتیبی',
                          value: PersianFormat.digits(
                            statistics.sequentialCount,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              SurfaceCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    SectionHeader(
                      title: 'وضعیت محاسبه',
                      subtitle:
                          'نتیجه از اجرای شبیه‌ساز روی همین مدار به دست آمده است.',
                    ),
                    if (simulation.isValid)
                      const InfoBanner(
                        tone: InfoBannerTone.success,
                        message:
                            'مدار معتبر است و همه سیگنال‌ها مقدار قطعی دارند.',
                      )
                    else ...<Widget>[
                      for (final CircuitProblem problem in simulation.errors
                          .take(4))
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: InfoBanner(
                            tone: InfoBannerTone.danger,
                            message: problem.message,
                          ),
                        ),
                      if (simulation.errors.length > 4)
                        Text(
                          '${PersianFormat.digits(simulation.errors.length - 4)} مشکل دیگر وجود دارد.',
                          style: theme.textTheme.bodySmall,
                        ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 14),
              SurfaceCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    SectionHeader(
                      title: 'مقایسه با مدار دیگر',
                      subtitle:
                          'دو مدار با جدول حقیقت واقعی‌شان مقایسه می‌شوند.',
                    ),
                    if (_comparison == null)
                      FilledButton.tonalIcon(
                        onPressed: _pickComparison,
                        icon: const Icon(Icons.compare_arrows_rounded),
                        label: const Text('انتخاب مدار دوم'),
                      )
                    else ...<Widget>[
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: Text(
                              'مقایسه با «${_comparison!.name}»',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: _pickComparison,
                            child: const Text('تغییر'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      if (_busy)
                        const LinearProgressIndicator(minHeight: 3)
                      else if (_result != null) ...<Widget>[
                        InfoBanner(
                          tone:
                              _result!.equivalent
                                  ? InfoBannerTone.success
                                  : InfoBannerTone.warning,
                          icon:
                              _result!.equivalent
                                  ? Icons.verified_rounded
                                  : Icons.warning_amber_rounded,
                          message:
                              _result!.equivalent
                                  ? 'دو مدار برای همه ترکیب‌ها رفتار یکسانی دارند و هم‌ارز هستند.'
                                  : _result!.mismatchDescription,
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: <Widget>[
                            _Stat(
                              icon: Icons.table_rows_rounded,
                              label: 'ردیف مقایسه',
                              value: PersianFormat.digits(
                                _result!.comparedRows,
                              ),
                            ),
                            const SizedBox(width: 8),
                            _Stat(
                              icon: Icons.flag_outlined,
                              label: 'اولین اختلاف',
                              value:
                                  _result!.firstMismatchIndex == null
                                      ? '—'
                                      : PersianFormat.digits(
                                        _result!.firstMismatchIndex! + 1,
                                      ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 15, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 6),
          Text(label, style: theme.textTheme.labelSmall),
          const SizedBox(width: 5),
          Text(
            value,
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
