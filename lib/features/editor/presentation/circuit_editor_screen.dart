import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/services/file_exchange.dart';
import '../../../core/theme/logic_lab_theme.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/gate_symbol.dart';
import '../../projects/application/projects_controller.dart';
import '../../projects/domain/circuit_project.dart';
import '../../analysis/presentation/circuit_analysis_screen.dart';
import '../../settings/application/settings_controller.dart';
import '../../truth_table/presentation/truth_table_screen.dart';
import '../../learn/application/learning_controller.dart';
import '../../learn/domain/challenge_validator.dart';
import '../../learn/domain/learning_content.dart';
import '../application/circuit_editor_controller.dart';
import '../domain/circuit_models.dart';
import '../domain/component_spec.dart';
import '../domain/circuit_validator.dart';
import 'circuit_canvas.dart';

class CircuitEditorScreen extends StatefulWidget {
  const CircuitEditorScreen({
    super.key,
    required this.project,
    required this.projectsController,
    this.challenge,
  });

  final CircuitProject project;
  final ProjectsController projectsController;

  /// When present the editor shows a challenge banner and a "check answer"
  /// action that validates the real circuit behaviour.
  final LearningChallenge? challenge;

  @override
  State<CircuitEditorScreen> createState() => _CircuitEditorScreenState();
}

class _CircuitEditorScreenState extends State<CircuitEditorScreen> {
  late final CircuitEditorController _editor;
  final CircuitCanvasController _canvasController = CircuitCanvasController();
  bool _closing = false;
  bool _allowPop = false;
  bool _showGrid = true;

  @override
  void initState() {
    super.initState();
    _editor = CircuitEditorController(
      project: widget.project,
      onSave: (CircuitProject project, CircuitGraph graph) {
        return widget.projectsController.saveGraph(project, graph);
      },
    );
  }

  @override
  void dispose() {
    _editor.dispose();
    super.dispose();
  }

  Future<void> _closeEditor() async {
    if (_closing) {
      return;
    }
    _closing = true;
    await _editor.flush();
    if (!mounted) {
      return;
    }
    if (_editor.saveStatus == SaveStatus.error) {
      final bool? leave = await showDialog<bool>(
        context: context,
        builder:
            (BuildContext context) => AlertDialog(
              title: const Text('ذخیره انجام نشد'),
              content: const Text(
                'آخرین تغییرات روی این دستگاه ذخیره نشده است. می‌خواهید بدون ذخیره خارج شوید؟',
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('تلاش دوباره'),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.error,
                  ),
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('خروج بدون ذخیره'),
                ),
              ],
            ),
      );
      if (!mounted) {
        return;
      }
      if (leave != true) {
        _closing = false;
        await _editor.saveNow();
        if (_editor.saveStatus == SaveStatus.error) {
          _closing = false;
          _toast('ذخیره همچنان انجام نمی‌شود.');
          return;
        }
      }
    }
    if (!mounted) {
      return;
    }
    setState(() => _allowPop = true);
    // Wait for the PopScope to be rebuilt with canPop enabled before popping.
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) {
      return;
    }
    Navigator.of(context).pop();
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _renameProject() async {
    final TextEditingController controller = TextEditingController(
      text: _editor.name,
    );
    final String? name = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('نام‌گذاری مدار'),
          content: TextField(
            controller: controller,
            autofocus: true,
            maxLength: 80,
            textInputAction: TextInputAction.done,
            onSubmitted: (String value) => Navigator.pop(context, value),
            decoration: const InputDecoration(
              labelText: 'نام پروژه',
              hintText: 'مثلاً: مقایسه‌گر یک بیت',
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('انصراف'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, controller.text),
              child: const Text('ذخیره نام'),
            ),
          ],
        );
      },
    );
    controller.dispose();
    if (name == null || name.trim().isEmpty) {
      return;
    }
    _editor.rename(name);
    _toast('نام مدار به‌روز شد.');
  }

  Future<void> _openTruthTable() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder:
            (BuildContext context) => TruthTableScreen(
              projectName: _editor.name,
              graph: _editor.graph,
            ),
      ),
    );
  }

  Future<void> _shareProject() async {
    try {
      await _editor.flush();
      final CircuitProject snapshot = _editor.project.copyWith(
        graph: _editor.graph,
        updatedAt: DateTime.now(),
      );
      await FileExchange.shareTextFile(
        fileName: '${ProjectCodec.safeFileName(snapshot.name)}.json',
        content: ProjectCodec.encode(snapshot),
        mimeType: 'application/json',
        subject: 'پروژه Logic Lab — ${snapshot.name}',
      );
    } catch (error) {
      if (mounted) {
        _toast('خروجی گرفتن انجام نشد: $error');
      }
    }
  }

  Future<void> _deleteProject() async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder:
          (BuildContext context) => AlertDialog(
            title: const Text('حذف مدار'),
            content: Text(
              'مدار «${_editor.name}» برای همیشه حذف می‌شود. این عمل قابل بازگشت نیست.',
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('انصراف'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error,
                ),
                onPressed: () => Navigator.pop(context, true),
                child: const Text('حذف کن'),
              ),
            ],
          ),
    );
    if (confirmed != true) {
      return;
    }
    try {
      await widget.projectsController.deleteProject(_editor.project.id);
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (error) {
      if (mounted) {
        _toast('حذف انجام نشد: $error');
      }
    }
  }

  Future<void> _showComponentTray() async {
    final ComponentType? type = await showModalBottomSheet<ComponentType>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (BuildContext context) => const _ComponentTray(),
    );
    if (type == null || !mounted) {
      return;
    }
    final CanvasPoint? center = _canvasController.visibleCenter();
    final int offset = _editor.graph.nodes.length % 6;
    final CanvasPoint position = CanvasPoint(
      (center?.x ?? 420) + offset * 18,
      (center?.y ?? 320) + offset * 14,
    );
    _editor.addNode(type, position);
  }

  Future<void> _showNodeSettings() async {
    final CircuitNode? node = _editor.selectedNode;
    if (node == null) {
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder:
          (BuildContext context) => _NodeSettingsSheet(
            editor: _editor,
            node: node,
            onDelete: () {
              Navigator.pop(context);
              _editor.deleteSelected();
            },
            onDuplicate: () {
              Navigator.pop(context);
              _editor.duplicateSelected();
            },
          ),
    );
  }

  Future<void> _checkChallenge() async {
    final LearningChallenge? challenge = widget.challenge;
    if (challenge == null) {
      return;
    }
    final ChallengeResult result = ChallengeValidator.validate(
      _editor.graph,
      challenge,
    );
    if (!mounted) {
      return;
    }
    if (result.passed) {
      await context.read<LearningController>().markCompleted(challenge.id);
    } else {
      await context.read<LearningController>().recordAttempt(
        challenge.id,
        passed: false,
      );
    }
    if (!mounted) {
      return;
    }
    await showDialog<void>(
      context: context,
      builder:
          (BuildContext context) => AlertDialog(
            icon: Icon(
              result.passed
                  ? Icons.verified_rounded
                  : Icons.assignment_late_rounded,
              color:
                  result.passed
                      ? LogicLabColors.of(context).success
                      : Theme.of(context).colorScheme.error,
            ),
            title: Text(result.title),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(result.message),
                if (result.details.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 12),
                  for (final String detail in result.details)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: TechnicalText(
                        detail,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                ],
                if (!result.passed) ...<Widget>[
                  const SizedBox(height: 12),
                  InfoBanner(
                    tone: InfoBannerTone.neutral,
                    icon: Icons.lightbulb_outline_rounded,
                    message: 'راهنما: ${challenge.hint}',
                  ),
                ],
              ],
            ),
            actions: <Widget>[
              FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('متوجه شدم'),
              ),
            ],
          ),
    );
  }

  Future<void> _openAnalysis() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder:
            (BuildContext context) => CircuitAnalysisScreen(
              project: _editor.project,
              graph: _editor.graph,
            ),
      ),
    );
  }

  void _showCircuitReport() {
    final SimulationResult report = _editor.report;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (BuildContext context) {
        final ThemeData theme = Theme.of(context);
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text('وضعیت مدار', style: theme.textTheme.titleLarge),
              const SizedBox(height: 6),
              Text(
                'این گزارش از شبیه‌ساز واقعی مدار ساخته شده است.',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 14),
              if (report.problems.isEmpty)
                const InfoBanner(
                  tone: InfoBannerTone.success,
                  icon: Icons.verified_rounded,
                  message:
                      'همه اتصال‌ها معتبر است و مدار یک مقدار قطعی برای هر خروجی دارد.',
                )
              else
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: report.problems.length,
                    itemBuilder: (BuildContext context, int index) {
                      final CircuitProblem problem = report.problems[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: InfoBanner(
                          tone:
                              problem.isError
                                  ? InfoBannerTone.danger
                                  : InfoBannerTone.warning,
                          message: problem.message,
                        ),
                      );
                    },
                  ),
                ),
              const SizedBox(height: 10),
              Row(
                children: <Widget>[
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _openTruthTable();
                      },
                      icon: const Icon(Icons.table_rows_rounded),
                      label: const Text('جدول حقیقت'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final SettingsController settings = context.watch<SettingsController>();
    final ThemeData theme = Theme.of(context);
    return PopScope<Object?>(
      canPop: _allowPop,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (!didPop) {
          _closeEditor();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            tooltip: 'بازگشت به مدارها',
            onPressed: _closeEditor,
            icon: const Icon(Icons.arrow_forward_rounded),
          ),
          titleSpacing: 0,
          title: AnimatedBuilder(
            animation: _editor,
            builder: (BuildContext context, Widget? child) {
              return InkWell(
                onTap: _renameProject,
                borderRadius: BorderRadius.circular(10),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 4,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Flexible(
                            child: Text(
                              _editor.name,
                              style: theme.textTheme.titleMedium,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Icon(
                            Icons.edit_rounded,
                            size: 13,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ],
                      ),
                      const SizedBox(height: 1),
                      _SaveStatusLabel(
                        status: _editor.saveStatus,
                        error: _editor.saveError,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          actions: <Widget>[
            IconButton(
              tooltip: 'خروجی JSON مدار',
              onPressed: _shareProject,
              icon: const Icon(Icons.ios_share_rounded),
            ),
            PopupMenuButton<String>(
              tooltip: 'گزینه‌های بیشتر',
              onSelected: (String value) {
                switch (value) {
                  case 'rename':
                    _renameProject();
                  case 'truth':
                    _openTruthTable();
                  case 'analysis':
                    _openAnalysis();
                  case 'info':
                    _showCircuitReport();
                  case 'delete':
                    _deleteProject();
                }
              },
              itemBuilder:
                  (BuildContext context) => const <PopupMenuEntry<String>>[
                    PopupMenuItem<String>(
                      value: 'rename',
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.drive_file_rename_outline_rounded),
                        title: Text('نام‌گذاری مدار'),
                      ),
                    ),
                    PopupMenuItem<String>(
                      value: 'truth',
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.table_rows_rounded),
                        title: Text('جدول حقیقت'),
                      ),
                    ),
                    PopupMenuItem<String>(
                      value: 'analysis',
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.query_stats_rounded),
                        title: Text('تحلیل و مقایسه مدار'),
                      ),
                    ),
                    PopupMenuItem<String>(
                      value: 'info',
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.fact_check_outlined),
                        title: Text('گزارش وضعیت مدار'),
                      ),
                    ),
                    PopupMenuDivider(),
                    PopupMenuItem<String>(
                      value: 'delete',
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.delete_outline_rounded),
                        title: Text('حذف مدار'),
                      ),
                    ),
                  ],
            ),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(56),
            child: _EditorToolbar(
              editor: _editor,
              canvasController: _canvasController,
              onAdd: _showComponentTray,
              onSettings: _showNodeSettings,
              onTruthTable: _openTruthTable,
              onReport: _showCircuitReport,
              onToggleGrid: () => setState(() => _showGrid = !_showGrid),
              showGrid: _showGrid,
              haptics: settings.hapticsEnabled,
            ),
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _showComponentTray,
          icon: const Icon(Icons.add_rounded),
          label: const Text('افزودن قطعه'),
        ),
        body: Column(
          children: <Widget>[
            if (widget.challenge != null)
              _ChallengeBanner(
                challenge: widget.challenge!,
                onCheck: _checkChallenge,
              ),
            Expanded(
              child: Stack(
                children: <Widget>[
                  Positioned.fill(
                    child: CircuitCanvas(
                      editor: _editor,
                      canvasController: _canvasController,
                      showGrid: _showGrid,
                    ),
                  ),
                  Positioned(
                    top: 10,
                    left: 12,
                    right: 12,
                    child: _FeedbackOverlay(editor: _editor),
                  ),
                ],
              ),
            ),
          ],
        ),
        bottomNavigationBar: _StatusDock(
          editor: _editor,
          onOpenReport: _showCircuitReport,
        ),
      ),
    );
  }
}

class _ChallengeBanner extends StatelessWidget {
  const _ChallengeBanner({required this.challenge, required this.onCheck});

  final LearningChallenge challenge;
  final VoidCallback onCheck;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.07),
        border: Border(
          bottom: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
      ),
      child: Row(
        children: <Widget>[
          Icon(Icons.flag_rounded, color: theme.colorScheme.primary, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  'چالش: ${challenge.title}',
                  style: theme.textTheme.titleSmall,
                ),
                const SizedBox(height: 2),
                Text(
                  challenge.brief,
                  style: theme.textTheme.bodySmall,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          FilledButton.tonalIcon(
            onPressed: onCheck,
            icon: const Icon(Icons.fact_check_rounded),
            label: const Text('بررسی پاسخ'),
          ),
        ],
      ),
    );
  }
}

class _SaveStatusLabel extends StatelessWidget {
  const _SaveStatusLabel({required this.status, this.error});

  final SaveStatus status;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final (IconData icon, String text, Color color) = switch (status) {
      SaveStatus.saved => (
        Icons.cloud_done_rounded,
        'ذخیره شد',
        LogicLabColors.of(context).success,
      ),
      SaveStatus.saving => (
        Icons.sync_rounded,
        'در حال ذخیره…',
        theme.colorScheme.primary,
      ),
      SaveStatus.unsaved => (
        Icons.edit_rounded,
        'ذخیره‌نشده',
        theme.colorScheme.onSurfaceVariant,
      ),
      SaveStatus.error => (
        Icons.error_outline_rounded,
        'خطا در ذخیره',
        theme.colorScheme.error,
      ),
    };
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 4),
        Text(
          text,
          style: theme.textTheme.labelSmall?.copyWith(
            color: color,
            fontSize: 10.5,
          ),
        ),
      ],
    );
  }
}

class _EditorToolbar extends StatelessWidget {
  const _EditorToolbar({
    required this.editor,
    required this.canvasController,
    required this.onAdd,
    required this.onSettings,
    required this.onTruthTable,
    required this.onReport,
    required this.onToggleGrid,
    required this.showGrid,
    required this.haptics,
  });

  final CircuitEditorController editor;
  final CircuitCanvasController canvasController;
  final VoidCallback onAdd;
  final VoidCallback onSettings;
  final VoidCallback onTruthTable;
  final VoidCallback onReport;
  final VoidCallback onToggleGrid;
  final bool showGrid;
  final bool haptics;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        border: Border(
          top: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          children: <Widget>[
            _ToolChip(
              icon: Icons.add_rounded,
              label: 'قطعه',
              primary: true,
              onTap: () {
                AppHaptics.selection(haptics);
                onAdd();
              },
            ),
            const SizedBox(width: 6),
            _ToolChip(
              icon: Icons.undo_rounded,
              label: 'بازگشت',
              onTap:
                  editor.canUndo
                      ? () {
                        AppHaptics.selection(haptics);
                        editor.undo();
                      }
                      : null,
            ),
            _ToolChip(
              icon: Icons.redo_rounded,
              label: 'تکرار',
              onTap:
                  editor.canRedo
                      ? () {
                        AppHaptics.selection(haptics);
                        editor.redo();
                      }
                      : null,
            ),
            _ToolChip(
              icon: Icons.copy_all_rounded,
              label: 'تکثیر',
              onTap:
                  editor.selectedNode == null
                      ? null
                      : () {
                        AppHaptics.selection(haptics);
                        editor.duplicateSelected();
                      },
            ),
            _ToolChip(
              icon: Icons.delete_outline_rounded,
              label: 'حذف',
              onTap:
                  editor.hasSelection
                      ? () {
                        AppHaptics.selection(haptics);
                        editor.deleteSelected();
                      }
                      : null,
            ),
            _ToolChip(
              icon: Icons.tune_rounded,
              label: 'تنظیم',
              onTap: editor.selectedNode == null ? null : onSettings,
            ),
            _ToolChip(
              icon: Icons.table_rows_rounded,
              label: 'جدول حقیقت',
              onTap: onTruthTable,
            ),
            _ToolChip(
              icon: Icons.fact_check_outlined,
              label: 'وضعیت',
              onTap: onReport,
            ),
            const _ToolbarDivider(),
            _ToolChip(
              icon: Icons.zoom_out_rounded,
              label: 'کوچک‌نمایی',
              onTap: canvasController.zoomOut,
            ),
            _ToolChip(
              icon: Icons.center_focus_strong_rounded,
              label: 'نمای کامل',
              onTap: canvasController.resetView,
            ),
            _ToolChip(
              icon: Icons.zoom_in_rounded,
              label: 'بزرگ‌نمایی',
              onTap: canvasController.zoomIn,
            ),
            _ToolChip(
              icon:
                  editor.gridSnapEnabled
                      ? Icons.grid_on_rounded
                      : Icons.grid_off_rounded,
              label:
                  editor.gridSnapEnabled
                      ? 'چسبیدن به شبکه روشن'
                      : 'چسبیدن به شبکه خاموش',
              active: editor.gridSnapEnabled,
              onTap: () {
                AppHaptics.selection(haptics);
                editor.setGridSnapEnabled(!editor.gridSnapEnabled);
              },
            ),
            _ToolChip(
              icon: showGrid ? Icons.grid_4x4_rounded : Icons.grid_off_rounded,
              label: showGrid ? 'پنهان کردن شبکه' : 'نمایش شبکه',
              active: showGrid,
              onTap: () {
                AppHaptics.selection(haptics);
                onToggleGrid();
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ToolbarDivider extends StatelessWidget {
  const _ToolbarDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 26,
      margin: const EdgeInsets.symmetric(horizontal: 6),
      color: Theme.of(context).colorScheme.outlineVariant,
    );
  }
}

class _ToolChip extends StatelessWidget {
  const _ToolChip({
    required this.icon,
    required this.label,
    required this.onTap,
    this.primary = false,
    this.active = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool primary;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool enabled = onTap != null;
    final Color background =
        primary
            ? theme.colorScheme.primary
            : active
            ? theme.colorScheme.primary.withValues(alpha: 0.1)
            : theme.colorScheme.surfaceContainerLowest;
    final Color foreground =
        primary
            ? theme.colorScheme.onPrimary
            : active
            ? theme.colorScheme.primary
            : enabled
            ? theme.colorScheme.onSurface
            : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.45);
    return Padding(
      padding: const EdgeInsetsDirectional.only(start: 5),
      child: Tooltip(
        message: label,
        excludeFromSemantics: true,
        child: Semantics(
          button: true,
          enabled: enabled,
          label: label,
          child: Material(
            color: background,
            borderRadius: BorderRadius.circular(11),
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(11),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 11,
                  vertical: 9,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(icon, size: 17, color: foreground),
                    const SizedBox(width: 6),
                    Text(
                      label,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: foreground,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FeedbackOverlay extends StatelessWidget {
  const _FeedbackOverlay({required this.editor});

  final CircuitEditorController editor;

  @override
  Widget build(BuildContext context) {
    final EditorFeedback? feedback = editor.feedback;
    return IgnorePointer(
      ignoring: feedback == null,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        child:
            feedback == null
                ? const SizedBox.shrink()
                : Center(
                  key: ValueKey<String>(feedback.message),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: Material(
                      color: Colors.transparent,
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(12, 9, 8, 9),
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .surfaceContainerLowest
                              .withValues(alpha: 0.96),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _toneColor(
                              context,
                              feedback.tone,
                            ).withValues(alpha: 0.35),
                          ),
                          boxShadow: <BoxShadow>[
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.08),
                              blurRadius: 14,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Icon(
                              _toneIcon(feedback.tone),
                              size: 17,
                              color: _toneColor(context, feedback.tone),
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                feedback.message,
                                style: Theme.of(
                                  context,
                                ).textTheme.bodySmall?.copyWith(
                                  color:
                                      Theme.of(context).colorScheme.onSurface,
                                ),
                              ),
                            ),
                            IconButton(
                              tooltip: 'بستن پیام',
                              onPressed: editor.clearFeedback,
                              iconSize: 16,
                              visualDensity: VisualDensity.compact,
                              icon: const Icon(Icons.close_rounded),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
      ),
    );
  }

  Color _toneColor(BuildContext context, EditorFeedbackTone tone) {
    final LogicLabColors colors = LogicLabColors.of(context);
    return switch (tone) {
      EditorFeedbackTone.info => Theme.of(context).colorScheme.primary,
      EditorFeedbackTone.success => colors.success,
      EditorFeedbackTone.error => colors.danger,
    };
  }

  IconData _toneIcon(EditorFeedbackTone tone) => switch (tone) {
    EditorFeedbackTone.info => Icons.info_outline_rounded,
    EditorFeedbackTone.success => Icons.check_circle_outline_rounded,
    EditorFeedbackTone.error => Icons.error_outline_rounded,
  };
}

class _StatusDock extends StatelessWidget {
  const _StatusDock({required this.editor, required this.onOpenReport});

  final CircuitEditorController editor;
  final VoidCallback onOpenReport;

  @override
  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final LogicLabColors colors = LogicLabColors.of(context);

    return Material(
      color: theme.colorScheme.surfaceContainerLowest,
      child: SafeArea(
        top: false,
        child: Container(
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(color: theme.colorScheme.outlineVariant),
            ),
          ),
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
          child: AnimatedBuilder(
            animation: editor,
            builder: (BuildContext context, Widget? child) {
              final SimulationResult report = editor.report;
              final List<CircuitProblem> errors =
                  report.problems
                      .where((CircuitProblem p) => p.isError)
                      .toList();
              final bool valid = report.isValid;
              final Color statusColor =
                  valid ? colors.success : theme.colorScheme.error;
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(11),
                        ),
                        child: Icon(
                          valid
                              ? Icons.verified_rounded
                              : Icons.warning_amber_rounded,
                          size: 18,
                          color: statusColor,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Text(
                              valid
                                  ? 'مدار معتبر است'
                                  : 'مدار نیاز به اصلاح دارد',
                              style: theme.textTheme.titleSmall?.copyWith(
                                color: statusColor,
                              ),
                            ),
                            const SizedBox(height: 1),
                            Text(
                              valid
                                  ? 'خروجی‌ها با هر تغییر ورودی بلافاصله محاسبه می‌شوند.'
                                  : errors.isEmpty
                                  ? 'اتصال‌ها کامل نیستند.'
                                  : errors.first.message,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      if (valid) ...<Widget>[
                        const SizedBox(width: 8),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 170),
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: <Widget>[
                                for (final CircuitNode output
                                    in editor.graph.outputs)
                                  Padding(
                                    padding: const EdgeInsets.only(left: 6),
                                    child: SignalPill(
                                      value:
                                          report
                                              .signalOf(output.id)
                                              .booleanValue,
                                      label: output.label,
                                      compact: true,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ],
                      IconButton(
                        tooltip: 'جزئیات وضعیت',
                        onPressed: onOpenReport,
                        icon: const Icon(Icons.info_outline_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  _SimulationBar(editor: editor),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Run / pause / step / reset controls plus the signal legend.
class _SimulationBar extends StatelessWidget {
  const _SimulationBar({required this.editor});

  final CircuitEditorController editor;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final LogicLabColors colors = LogicLabColors.of(context);
    final bool sequential = editor.hasSequentialParts;
    return Row(
      children: <Widget>[
        _SimButton(
          icon:
              editor.isRunning ? Icons.pause_rounded : Icons.play_arrow_rounded,
          tooltip: editor.isRunning ? 'توقف کلاک خودکار' : 'اجرای کلاک خودکار',
          active: editor.isRunning,
          onTap: () => editor.setRunning(!editor.isRunning),
        ),
        _SimButton(
          icon: Icons.skip_next_rounded,
          tooltip: 'یک پالس کلاک',
          onTap: editor.stepClock,
        ),
        _SimButton(
          icon: Icons.restart_alt_rounded,
          tooltip: 'بازنشانی وضعیت ترتیبی',
          onTap: editor.resetSimulation,
        ),
        const SizedBox(width: 8),
        if (sequential)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: theme.colorScheme.tertiary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(
                  Icons.schedule_rounded,
                  size: 13,
                  color: theme.colorScheme.tertiary,
                ),
                const SizedBox(width: 4),
                Text(
                  'CLK=${editor.clockLevel ? '1' : '0'}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontFamily: 'JetBrainsMono',
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.tertiary,
                  ),
                ),
              ],
            ),
          ),
        const Spacer(),
        _LegendDot(color: colors.highSignal, label: '۱'),
        _LegendDot(color: colors.lowSignal, label: '۰'),
        _LegendDot(color: colors.unknownSignal, label: '؟'),
        _LegendDot(color: theme.colorScheme.outline, label: 'Z'),
      ],
    );
  }
}

class _SimButton extends StatelessWidget {
  const _SimButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.active = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Tooltip(
      message: tooltip,
      child: IconButton(
        onPressed: onTap,
        visualDensity: VisualDensity.compact,
        style: IconButton.styleFrom(
          backgroundColor:
              active
                  ? theme.colorScheme.primary.withValues(alpha: 0.14)
                  : theme.colorScheme.surfaceContainerLow,
          foregroundColor:
              active ? theme.colorScheme.primary : theme.colorScheme.onSurface,
          minimumSize: const Size(38, 34),
        ),
        icon: Icon(icon, size: 18),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(start: 7),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 3),
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(fontSize: 10),
          ),
        ],
      ),
    );
  }
}

class _ComponentTray extends StatelessWidget {
  const _ComponentTray();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final double maxHeight = MediaQuery.sizeOf(context).height * 0.78;
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: Padding(
        padding: const EdgeInsetsDirectional.only(
          start: 18,
          end: 18,
          bottom: 18,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text('افزودن قطعه', style: theme.textTheme.titleLarge),
              const SizedBox(height: 4),
              Text(
                'قطعه را انتخاب کنید؛ سپس آن را روی بوم جابه‌جا کنید.',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              const _TrayCatalogue(),
            ],
          ),
        ),
      ),
    );
  }
}

/// The searchable component catalogue, grouped by category.
class _TrayCatalogue extends StatefulWidget {
  const _TrayCatalogue();

  @override
  State<_TrayCatalogue> createState() => _TrayCatalogueState();
}

class _TrayCatalogueState extends State<_TrayCatalogue> {
  final TextEditingController _controller = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool _matches(ComponentType type) {
    if (_query.isEmpty) {
      return true;
    }
    final ComponentSpec spec = ComponentLibrary.specOf(type);
    final String query = _query.toLowerCase();
    return spec.title.toLowerCase().contains(query) ||
        type.technicalName.toLowerCase().contains(query) ||
        type.jsonName.toLowerCase().contains(query) ||
        spec.description.toLowerCase().contains(query);
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Map<String, List<ComponentType>> catalogue =
        ComponentLibrary.catalogue;
    int visible = 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        TextField(
          controller: _controller,
          onChanged: (String value) => setState(() => _query = value.trim()),
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: 'جست‌وجوی قطعه…',
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon:
                _query.isEmpty
                    ? null
                    : IconButton(
                      tooltip: 'پاک کردن',
                      onPressed: () {
                        _controller.clear();
                        setState(() => _query = '');
                      },
                      icon: const Icon(Icons.close_rounded),
                    ),
            isDense: true,
          ),
        ),
        const SizedBox(height: 14),
        for (final MapEntry<String, List<ComponentType>> entry
            in catalogue.entries) ...<Widget>[
          Builder(
            builder: (BuildContext context) {
              final List<ComponentType> matches =
                  entry.value.where(_matches).toList();
              if (matches.isEmpty) {
                return const SizedBox.shrink();
              }
              visible += matches.length;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  // The group renders its own heading, so no second title is
                  // added here.
                  _TrayGroup(
                    title: entry.key,
                    children: matches
                        .map(
                          (ComponentType type) => _TrayItem(
                            type: type,
                            title: ComponentLibrary.specOf(type).title,
                            description:
                                ComponentLibrary.specOf(type).description,
                            onTap: () => Navigator.pop(context, type),
                          ),
                        )
                        .toList(growable: false),
                  ),
                  const SizedBox(height: 14),
                ],
              );
            },
          ),
        ],
        if (visible == 0)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Center(
              child: Text(
                'قطعه‌ای با این نام پیدا نشد.',
                style: theme.textTheme.bodySmall,
              ),
            ),
          ),
      ],
    );
  }
}

class _TrayGroup extends StatelessWidget {
  const _TrayGroup({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          title,
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final int columns = constraints.maxWidth > 560 ? 4 : 2;
            final double width =
                (constraints.maxWidth - (columns - 1) * 10) / columns;
            return Wrap(
              spacing: 10,
              runSpacing: 10,
              children: children
                  .map((Widget child) => SizedBox(width: width, child: child))
                  .toList(growable: false),
            );
          },
        ),
      ],
    );
  }
}

class _TrayItem extends StatelessWidget {
  const _TrayItem({
    required this.type,
    required this.title,
    required this.description,
    required this.onTap,
  });

  final ComponentType type;
  final String title;
  final String description;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ComponentSpec spec = ComponentLibrary.specOf(type);
    return SurfaceCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      semanticLabel: '$title، $description',
      child: Row(
        children: <Widget>[
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: theme.colorScheme.outlineVariant),
            ),
            child: _trayGlyph(context, spec),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: theme.textTheme.titleSmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 1),
                Text(
                  description,
                  style: theme.textTheme.bodySmall,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
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
    );
  }

  Widget _trayGlyph(BuildContext context, ComponentSpec spec) {
    final ThemeData theme = Theme.of(context);
    switch (spec.kind) {
      case ComponentKind.gate:
        return GateSymbol(type: type, size: 30, strokeWidth: 1.6);
      case ComponentKind.input:
        return const Icon(Icons.login_rounded, size: 20);
      case ComponentKind.output:
        return const Icon(Icons.logout_rounded, size: 20);
      case ComponentKind.clock:
        return const Icon(Icons.schedule_rounded, size: 20);
      case ComponentKind.sequential:
        return Icon(
          Icons.memory_rounded,
          size: 20,
          color: theme.colorScheme.tertiary,
        );
      case ComponentKind.module:
        return Icon(
          Icons.widgets_outlined,
          size: 20,
          color: theme.colorScheme.primary,
        );
      case ComponentKind.unsupported:
        return const Icon(Icons.help_outline_rounded, size: 20);
    }
  }
}

class _NodeSettingsSheet extends StatefulWidget {
  const _NodeSettingsSheet({
    required this.editor,
    required this.node,
    required this.onDelete,
    required this.onDuplicate,
  });

  final CircuitEditorController editor;
  final CircuitNode node;
  final VoidCallback onDelete;
  final VoidCallback onDuplicate;

  @override
  State<_NodeSettingsSheet> createState() => _NodeSettingsSheetState();
}

class _NodeSettingsSheetState extends State<_NodeSettingsSheet> {
  late final TextEditingController _labelController;
  late int _inputCount;
  late bool _inputValue;

  @override
  void initState() {
    super.initState();
    _labelController = TextEditingController(text: widget.node.label);
    _inputCount = widget.node.inputCount;
    _inputValue = widget.node.inputValue;
  }

  @override
  void dispose() {
    _labelController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final CircuitNode node = widget.node;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        20 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(13),
                    border: Border.all(color: theme.colorScheme.outlineVariant),
                  ),
                  child:
                      node.type.isInput || node.type.isOutput
                          ? Icon(
                            node.type.isInput
                                ? Icons.login_rounded
                                : Icons.logout_rounded,
                            color: theme.colorScheme.primary,
                          )
                          : GateSymbol(
                            type: node.type,
                            size: 32,
                            strokeWidth: 1.6,
                          ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text('تنظیمات قطعه', style: theme.textTheme.titleLarge),
                      Text(
                        node.type.persianName,
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _labelController,
              maxLength: 24,
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(
                labelText: 'برچسب قطعه',
                helperText: 'برچسب در بوم و جدول حقیقت نمایش داده می‌شود.',
              ),
            ),
            if (node.type.isBinaryGate) ...<Widget>[
              const SizedBox(height: 6),
              Text('تعداد ورودی‌ها', style: theme.textTheme.titleSmall),
              const SizedBox(height: 8),
              SegmentedButton<int>(
                segments: const <ButtonSegment<int>>[
                  ButtonSegment<int>(value: 2, label: Text('۲')),
                  ButtonSegment<int>(value: 3, label: Text('۳')),
                  ButtonSegment<int>(value: 4, label: Text('۴')),
                ],
                selected: <int>{_inputCount},
                onSelectionChanged: (Set<int> value) {
                  setState(() => _inputCount = value.first);
                },
              ),
            ],
            if (node.type.isInput) ...<Widget>[
              const SizedBox(height: 6),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('مقدار اولیه'),
                subtitle: Text(_inputValue ? 'سطح بالا (۱)' : 'سطح پایین (۰)'),
                value: _inputValue,
                onChanged: (bool value) => setState(() => _inputValue = value),
              ),
            ],
            const SizedBox(height: 14),
            Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: widget.onDuplicate,
                    icon: const Icon(Icons.copy_all_rounded),
                    label: const Text('تکثیر'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: widget.onDelete,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: theme.colorScheme.error,
                    ),
                    icon: const Icon(Icons.delete_outline_rounded),
                    label: const Text('حذف'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  widget.editor.updateNodeProperties(
                    node.id,
                    label: _labelController.text,
                    inputCount: _inputCount,
                    inputValue: _inputValue,
                  );
                  Navigator.pop(context);
                },
                child: const Text('اعمال تنظیمات'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Helpers to open the editor from anywhere in the app.
class EditorLauncher {
  const EditorLauncher._();

  static Future<void> open(
    BuildContext context,
    CircuitProject project, {
    LearningChallenge? challenge,
  }) async {
    final ProjectsController controller = context.read<ProjectsController>();
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder:
            (BuildContext context) => CircuitEditorScreen(
              project: project,
              projectsController: controller,
              challenge: challenge,
            ),
      ),
    );
  }

  static Future<CircuitProject?> createAndOpen(
    BuildContext context, {
    ComponentType? quickGate,
    CircuitGraph? graph,
    String? name,
  }) async {
    final ProjectsController controller = context.read<ProjectsController>();
    try {
      final CircuitProject project = await controller.createNew(
        graph: graph,
        name: name,
        quickGate: quickGate,
      );
      if (!context.mounted) {
        return project;
      }
      await open(context, project);
      return project;
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(content: Text('ساخت مدار انجام نشد: $error')),
          );
      }
      return null;
    }
  }
}
