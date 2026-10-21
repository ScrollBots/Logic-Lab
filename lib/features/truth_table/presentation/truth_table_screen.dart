import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../../core/localization/persian_format.dart';
import '../../../../core/services/file_exchange.dart';
import '../../../../core/theme/logic_lab_theme.dart';
import '../../../../core/widgets/common.dart';
import '../../../features/settings/application/settings_controller.dart';
import '../../editor/domain/circuit_models.dart';
import '../domain/truth_table.dart';

class TruthTableScreen extends StatefulWidget {
  const TruthTableScreen({
    super.key,
    required this.projectName,
    required this.graph,
  });

  final String projectName;
  final CircuitGraph graph;

  @override
  State<TruthTableScreen> createState() => _TruthTableScreenState();
}

class _TruthTableScreenState extends State<TruthTableScreen> {
  static const TruthTableGenerator _generator = TruthTableGenerator();
  TruthTableResult? _table;
  TruthTableGenerationException? _error;
  TruthTableLimits _limits = const TruthTableLimits();
  final ScrollController _verticalScroll = ScrollController();
  final ScrollController _horizontalScroll = ScrollController();
  final TextEditingController _filterController = TextEditingController();
  String _filter = '';

  @override
  void initState() {
    super.initState();
    _generate();
  }

  @override
  void dispose() {
    _verticalScroll.dispose();
    _horizontalScroll.dispose();
    _filterController.dispose();
    super.dispose();
  }

  /// Keeps only the rows whose input bits match the typed pattern. A `?` in
  /// the pattern matches any value.
  List<TruthTableRow> _visibleRows(TruthTableResult table) {
    final String pattern = _filter.trim();
    if (pattern.isEmpty) {
      return table.rows;
    }
    final List<String> bits = pattern.split('');
    return table.rows
        .where((TruthTableRow row) {
          for (int i = 0; i < table.inputNodes.length && i < bits.length; i++) {
            final String expected = bits[i];
            if (expected == '?' || expected == 'x' || expected == 'X') {
              continue;
            }
            final String actual =
                row.inputs[table.inputNodes[i].id] == true ? '1' : '0';
            if (expected != actual) {
              return false;
            }
          }
          return true;
        })
        .toList(growable: false);
  }

  void _generate() {
    try {
      _table = _generator.generate(widget.graph, limits: _limits);
      _error = null;
    } on TruthTableGenerationException catch (error) {
      _table = null;
      _error = error;
    }
  }

  Future<void> _showLimits() async {
    final int? selection = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (BuildContext context) {
        final ThemeData theme = Theme.of(context);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('محدودیت محاسبه جدول', style: theme.textTheme.titleLarge),
                const SizedBox(height: 6),
                Text(
                  'برای جلوگیری از کندی، تعداد ردیف‌ها محدود است. محدودیت را آگاهانه تغییر دهید.',
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 14),
                for (final int rows in <int>[64, 256, 1024])
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: SurfaceCard(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      borderColor:
                          rows == _limits.maxRows
                              ? theme.colorScheme.primary
                              : null,
                      onTap: () => Navigator.pop(context, rows),
                      child: Row(
                        children: <Widget>[
                          Icon(
                            rows == _limits.maxRows
                                ? Icons.radio_button_checked_rounded
                                : Icons.radio_button_off_rounded,
                            color:
                                rows == _limits.maxRows
                                    ? theme.colorScheme.primary
                                    : theme.colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  '${PersianFormat.digits(rows)} ردیف'
                                  ' — حداکثر ${PersianFormat.digits(_inputsForRows(rows))} ورودی',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  rows == 256
                                      ? 'پیش‌فرض متعادل'
                                      : rows == 64
                                      ? 'سریع‌ترین'
                                      : 'برای مدارهای بزرگ‌تر',
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
            ),
          ),
        );
      },
    );
    if (selection != null && selection != _limits.maxRows) {
      setState(() {
        _limits = TruthTableLimits(
          maxInputs: _inputsForRows(selection),
          maxRows: selection,
        );
        _generate();
      });
    }
  }

  int _inputsForRows(int rows) {
    int bits = 0;
    while ((1 << bits) < rows && bits < 12) {
      bits++;
    }
    return bits.clamp(1, 10);
  }

  Future<void> _copyCsv() async {
    final TruthTableResult? table = _table;
    if (table == null) {
      return;
    }
    await Clipboard.setData(ClipboardData(text: table.toCsv()));
    if (!mounted) {
      return;
    }
    AppHaptics.selection(context.read<SettingsController>().hapticsEnabled);
    _toast('CSV در حافظه کپی شد.');
  }

  Future<void> _shareCsv() async {
    final TruthTableResult? table = _table;
    if (table == null) {
      return;
    }
    try {
      await FileExchange.shareTextFile(
        fileName: '${_safeName(widget.projectName)}-truth-table.csv',
        content: table.toCsv(includeBom: true),
        mimeType: 'text/csv',
        subject: 'جدول حقیقت ${widget.projectName}',
      );
    } catch (error) {
      if (mounted) {
        _toast(error.toString());
      }
    }
  }

  String _safeName(String value) {
    final String cleaned =
        value.replaceAll(RegExp(r'[\\/:*?"<>|]'), '-').trim();
    return cleaned.isEmpty ? 'logic-lab' : cleaned;
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final TruthTableResult? table = _table;
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text('جدول حقیقت'),
            Text(
              widget.projectName,
              style: theme.textTheme.bodySmall,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        actions: <Widget>[
          IconButton(
            tooltip: 'محدودیت محاسبه',
            onPressed: _showLimits,
            icon: const Icon(Icons.tune_rounded),
          ),
          PopupMenuButton<String>(
            tooltip: 'خروجی CSV',
            enabled: table != null,
            onSelected: (String value) {
              if (value == 'copy') {
                _copyCsv();
              } else {
                _shareCsv();
              }
            },
            itemBuilder:
                (BuildContext context) => const <PopupMenuEntry<String>>[
                  PopupMenuItem<String>(
                    value: 'copy',
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.copy_rounded),
                      title: Text('کپی CSV'),
                    ),
                  ),
                  PopupMenuItem<String>(
                    value: 'share',
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.ios_share_rounded),
                      title: Text('اشتراک‌گذاری فایل CSV'),
                    ),
                  ),
                ],
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: ResponsiveCenter(
          maxWidth: 1180,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              _summary(context, table),
              const SizedBox(height: 12),
              if (_error != null)
                Expanded(
                  child: Center(
                    child: EmptyState(
                      icon: Icons.grid_off_rounded,
                      title: 'جدول ساخته نشد',
                      message: _error!.message,
                      action: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          OutlinedButton.icon(
                            onPressed: _showLimits,
                            icon: const Icon(Icons.tune_rounded),
                            label: const Text('تغییر محدودیت'),
                          ),
                          const SizedBox(width: 8),
                          FilledButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('بازگشت به مدار'),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else if (table != null && table.outputs.isEmpty)
                Expanded(
                  child: Center(
                    child: EmptyState(
                      icon: Icons.output_rounded,
                      title: 'خروجی تعریف نشده است',
                      message:
                          'برای ساخت جدول حقیقت، ابتدا یک قطعه خروجی به مدار اضافه و آن را به سیگنال متصل کنید.',
                      action: FilledButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('بازگشت به ویرایشگر'),
                      ),
                    ),
                  ),
                )
              else if (table != null) ...<Widget>[
                if (!table.allRowsValid)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: InfoBanner(
                      tone: InfoBannerTone.danger,
                      message:
                          'مدار در حال حاضر معتبر نیست. مقادیر قابل محاسبه نمایش داده می‌شوند و خروجی‌های نامشخص با «؟» مشخص شده‌اند.',
                      action: TextButton(
                        onPressed: () => _showProblems(table),
                        child: const Text('جزئیات'),
                      ),
                    ),
                  ),
                if (table.inputCount == 0)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: InfoBanner(
                      icon: Icons.info_outline_rounded,
                      message:
                          'این مدار ورودی مستقل ندارد؛ تنها یک وضعیت برای محاسبه وجود دارد.',
                    ),
                  ),
                Expanded(child: _tableCard(context, table)),
                const SizedBox(height: 10),
                Row(
                  children: <Widget>[
                    Icon(
                      Icons.swipe_rounded,
                      size: 16,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'برای مشاهده ستون‌های بیشتر، جدول را افقی بکشید. ردیف منطبق با ورودی‌های فعلی برجسته است.',
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _summary(BuildContext context, TruthTableResult? table) {
    final ThemeData theme = Theme.of(context);
    final int inputCount = table?.inputCount ?? widget.graph.inputs.length;
    final int outputCount = table?.outputCount ?? widget.graph.outputs.length;
    return SurfaceCard(
      padding: const EdgeInsets.all(14),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: <Widget>[
          _metric(
            context,
            Icons.login_rounded,
            'ورودی',
            PersianFormat.digits(inputCount),
          ),
          _metric(
            context,
            Icons.logout_rounded,
            'خروجی',
            PersianFormat.digits(outputCount),
          ),
          _metric(
            context,
            Icons.table_rows_rounded,
            'ردیف',
            table == null ? '—' : PersianFormat.digits(table.rows.length),
          ),
          _metric(
            context,
            Icons.memory_rounded,
            'گیت',
            PersianFormat.digits(
              widget.graph.nodes
                  .where((CircuitNode node) => node.type.isGate)
                  .length,
            ),
          ),
          if (table != null && table.allRowsValid)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: LogicLabColors.of(
                  context,
                ).success.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(
                    Icons.verified_rounded,
                    size: 16,
                    color: LogicLabColors.of(context).success,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    'همه ردیف‌ها معتبرند',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: LogicLabColors.of(context).success,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _metric(
    BuildContext context,
    IconData icon,
    String label,
    String value,
  ) {
    final ThemeData theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 15, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 5),
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

  Widget _tableCard(BuildContext context, TruthTableResult table) {
    final List<TruthTableRow> visibleRows = _visibleRows(table);
    final ThemeData theme = Theme.of(context);
    final LogicLabColors logicColors = LogicLabColors.of(context);
    final List<CircuitNode> inputs = table.inputNodes;
    final List<TruthTableOutput> outputs = table.outputs;
    final double rowNumberWidth = 52;
    final double cellWidth = 66;
    final double outputCellWidth = 76;
    final double tableWidth =
        rowNumberWidth +
        inputs.length * cellWidth +
        outputs.length * outputCellWidth +
        20;
    final int? current = table.currentInputRow;

    if (current != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_verticalScroll.hasClients) {
          return;
        }
        final double target = (current * 44.0 - 90).clamp(
          0.0,
          _verticalScroll.position.maxScrollExtent,
        );
        if ((_verticalScroll.offset - target).abs() > 1) {
          _verticalScroll.jumpTo(target);
        }
      });
    }

    return SurfaceCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: TextField(
                    controller: _filterController,
                    onChanged:
                        (String value) => setState(() => _filter = value),
                    textDirection: TextDirection.ltr,
                    textAlign: TextAlign.left,
                    style: LogicLabTheme.technical(theme.textTheme.bodyMedium),
                    decoration: InputDecoration(
                      isDense: true,
                      hintText:
                          inputs.isEmpty
                              ? 'بدون ورودی برای فیلتر'
                              : 'فیلتر ردیف‌ها، مثل ${inputs.length > 1 ? '101' : '1'} (؟ یعنی هر مقدار)',
                      prefixIcon: const Icon(
                        Icons.filter_alt_outlined,
                        size: 19,
                      ),
                      suffixIcon:
                          _filter.isEmpty
                              ? null
                              : IconButton(
                                tooltip: 'پاک کردن فیلتر',
                                onPressed: () {
                                  _filterController.clear();
                                  setState(() => _filter = '');
                                },
                                icon: const Icon(Icons.close_rounded, size: 18),
                              ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  '${PersianFormat.digits(visibleRows.length)} از ${PersianFormat.digits(table.rows.length)} ردیف',
                  style: theme.textTheme.labelSmall,
                ),
              ],
            ),
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                return Scrollbar(
                  controller: _horizontalScroll,
                  thumbVisibility: true,
                  child: SingleChildScrollView(
                    controller: _horizontalScroll,
                    scrollDirection: Axis.horizontal,
                    child: SizedBox(
                      width:
                          tableWidth < constraints.maxWidth
                              ? constraints.maxWidth
                              : tableWidth,
                      height: constraints.maxHeight,
                      child: Column(
                        children: <Widget>[
                          Container(
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surfaceContainer,
                              border: Border(
                                bottom: BorderSide(
                                  color: theme.colorScheme.outlineVariant,
                                ),
                              ),
                            ),
                            child: Row(
                              children: <Widget>[
                                const SizedBox(
                                  width: 52,
                                  height: 52,
                                  child: Center(
                                    child: Text(
                                      '#',
                                      style: TextStyle(
                                        fontFamily: 'JetBrainsMono',
                                      ),
                                    ),
                                  ),
                                ),
                                for (final CircuitNode node in inputs)
                                  _columnHeader(
                                    context,
                                    node.label,
                                    width: cellWidth,
                                    isOutput: false,
                                  ),
                                for (final TruthTableOutput output in outputs)
                                  _columnHeader(
                                    context,
                                    output.label,
                                    width: outputCellWidth,
                                    isOutput: true,
                                  ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: ListView.builder(
                              controller: _verticalScroll,
                              itemCount: visibleRows.length,
                              itemExtent: 44,
                              itemBuilder: (BuildContext context, int index) {
                                final TruthTableRow row = visibleRows[index];
                                final bool active = current == row.index;
                                final String outputSemantics = outputs
                                    .map((TruthTableOutput output) {
                                      final bool? value =
                                          row.outputs['${output.nodeId}#${output.port}'];
                                      final String state =
                                          value == null
                                              ? 'نامشخص'
                                              : value
                                              ? 'یک'
                                              : 'صفر';
                                      return '${output.label} $state';
                                    })
                                    .join('، ');
                                final String inputSemantics = inputs
                                    .map(
                                      (CircuitNode node) =>
                                          '${node.label} ${row.inputs[node.id] == true ? 'یک' : 'صفر'}',
                                    )
                                    .join('، ');
                                final String semantics = <String>[
                                  'ردیف ${PersianFormat.digits(row.index + 1)}',
                                  if (inputs.isNotEmpty) inputSemantics,
                                  if (outputs.isNotEmpty) outputSemantics,
                                ].join('، ');
                                return Semantics(
                                  label: semantics,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color:
                                          active
                                              ? theme.colorScheme.primary
                                                  .withValues(alpha: 0.075)
                                              : index.isEven
                                              ? Colors.transparent
                                              : theme
                                                  .colorScheme
                                                  .surfaceContainerLow
                                                  .withValues(alpha: 0.52),
                                      border: Border(
                                        right:
                                            active
                                                ? BorderSide(
                                                  color:
                                                      theme.colorScheme.primary,
                                                  width: 2.5,
                                                )
                                                : BorderSide.none,
                                      ),
                                    ),
                                    child: Row(
                                      children: <Widget>[
                                        SizedBox(
                                          width: rowNumberWidth,
                                          child: Center(
                                            child: Text(
                                              PersianFormat.digits(
                                                row.index + 1,
                                              ),
                                              style: theme.textTheme.labelSmall
                                                  ?.copyWith(
                                                    color:
                                                        theme
                                                            .colorScheme
                                                            .onSurfaceVariant,
                                                  ),
                                            ),
                                          ),
                                        ),
                                        for (final CircuitNode node in inputs)
                                          _bitCell(
                                            context,
                                            width: cellWidth,
                                            value: row.inputs[node.id] == true,
                                            active: active,
                                          ),
                                        for (final TruthTableOutput output
                                            in outputs)
                                          _bitCell(
                                            context,
                                            width: outputCellWidth,
                                            value:
                                                row.outputs['${output.nodeId}#${output.port}'],
                                            active: active,
                                            emphasis: true,
                                          ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: theme.colorScheme.outlineVariant),
              ),
            ),
            child: Row(
              children: <Widget>[
                _legendDot(logicColors.highSignal, '۱ — بالا'),
                const SizedBox(width: 12),
                _legendDot(logicColors.lowSignal, '۰ — پایین'),
                const SizedBox(width: 12),
                _legendDot(logicColors.unknownSignal, '؟ — نامشخص'),
                const Spacer(),
                Text(
                  '${PersianFormat.digits(table.rows.length)} ردیف',
                  style: theme.textTheme.labelSmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _columnHeader(
    BuildContext context,
    String label, {
    required double width,
    required bool isOutput,
  }) {
    final ThemeData theme = Theme.of(context);
    return Container(
      width: width,
      height: 52,
      decoration: BoxDecoration(
        border: Border(
          right: BorderSide(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.7),
          ),
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          TechnicalText(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            isOutput ? 'OUT' : 'IN',
            textDirection: TextDirection.ltr,
            style: theme.textTheme.labelSmall?.copyWith(
              fontSize: 8,
              color:
                  isOutput
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _bitCell(
    BuildContext context, {
    required double width,
    required bool? value,
    required bool active,
    bool emphasis = false,
  }) {
    final LogicLabColors colors = LogicLabColors.of(context);
    final Color color =
        value == null
            ? colors.unknownSignal
            : value
            ? colors.highSignal
            : colors.lowSignal;
    final Widget chip = Container(
      width: 28,
      height: 26,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color:
            value == null
                ? colors.unknownSignal.withValues(alpha: 0.08)
                : color.withValues(alpha: emphasis ? 0.14 : 0.07),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(
          color: color.withValues(alpha: emphasis ? 0.38 : 0.18),
        ),
      ),
      child: TechnicalText(
        value == null
            ? '?'
            : value
            ? '1'
            : '0',
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
    return Container(
      width: width,
      height: 44,
      alignment: Alignment.center,
      child: chip,
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(fontSize: 10),
        ),
      ],
    );
  }

  void _showProblems(TruthTableResult table) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (BuildContext context) {
        final List<CircuitProblem> errors =
            table.problems
                .where((CircuitProblem problem) => problem.isError)
                .toList();
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'مشکلات مدار',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 6),
                Text(
                  'این پیام‌ها از اعتبارسنجی واقعی مدار گرفته شده‌اند.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: errors.length,
                    itemBuilder: (BuildContext context, int index) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: InfoBanner(
                          tone: InfoBannerTone.danger,
                          icon: Icons.error_outline_rounded,
                          message: errors[index].message,
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
