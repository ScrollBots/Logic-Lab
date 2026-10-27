import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/localization/persian_format.dart';
import '../../../core/services/file_exchange.dart';
import '../../../core/theme/logic_lab_theme.dart';
import '../../../core/widgets/common.dart';
import '../../editor/domain/circuit_models.dart';
import '../../editor/presentation/circuit_editor_screen.dart';
import '../../projects/application/projects_controller.dart';
import '../../projects/domain/circuit_project.dart';
import '../domain/boolean_expression.dart';
import '../domain/expression_circuit_converter.dart';
import '../domain/expression_equivalence.dart';

class BooleanWorkspaceScreen extends StatefulWidget {
  const BooleanWorkspaceScreen({super.key});

  @override
  State<BooleanWorkspaceScreen> createState() => _BooleanWorkspaceScreenState();
}

class _BooleanWorkspaceScreenState extends State<BooleanWorkspaceScreen> {
  final TextEditingController _controller = TextEditingController();
  final TextEditingController _compareController = TextEditingController();

  BoolExpr? _expression;
  BooleanParseException? _parseError;
  SimplificationResult? _simplification;
  ExpressionTruthTable? _truthTable;
  ExpressionComparisonResult? _comparison;
  String? _compareError;
  int _tab = 0;

  @override
  void dispose() {
    _controller.dispose();
    _compareController.dispose();
    super.dispose();
  }

  void _parse() {
    final String source = _controller.text.trim();
    if (source.isEmpty) {
      setState(() {
        _expression = null;
        _parseError = null;
        _simplification = null;
        _truthTable = null;
      });
      return;
    }
    try {
      final BoolExpr expression = BooleanExpressionParser.parse(source);
      setState(() {
        _expression = expression;
        _parseError = null;
        _simplification = BooleanSimplifier.simplify(expression);
        _truthTable = ExpressionTruthTable.generate(expression);
      });
    } on BooleanParseException catch (error) {
      setState(() {
        _expression = null;
        _parseError = error;
        _simplification = null;
        _truthTable = null;
      });
    }
  }

  void _compare() {
    try {
      final BoolExpr left = BooleanExpressionParser.parse(
        _controller.text.trim(),
      );
      final BoolExpr right = BooleanExpressionParser.parse(
        _compareController.text.trim(),
      );
      setState(() {
        _comparison = BooleanExpressionTools.compare(left, right);
        _compareError = null;
      });
    } on BooleanParseException catch (error) {
      setState(() {
        _comparison = null;
        _compareError = error.message;
      });
    }
  }

  void _insertToken(String token) {
    final TextEditingValue value = _controller.value;
    final int start = value.selection.start < 0
        ? value.text.length
        : value.selection.start;
    final int end = value.selection.end < 0
        ? value.text.length
        : value.selection.end;
    final String next = value.text.replaceRange(start, end, token);
    _controller.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: start + token.length),
    );
    _parse();
  }

  Future<void> _buildCircuit() async {
    final BoolExpr? expression = _expression;
    if (expression == null) {
      return;
    }
    try {
      final CircuitGraph graph = ExpressionCircuitConverter.toCircuit(
        expression,
      );
      if (!mounted) {
        return;
      }
      final bool? created = await showDialog<bool>(
        context: context,
        builder: (BuildContext context) => AlertDialog(
          title: const Text('ساخت مدار'),
          content: const Text(
            'یک مدار واقعی از این عبارت ساخته شود و در ویرایشگر باز شود؟ '
            'مدار از دروازه‌های AND، OR، NOT و XOR و سیم‌های واقعی تشکیل می‌شود.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('انصراف'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('ساخت و باز کردن'),
            ),
          ],
        ),
      );
      if (created != true || !mounted) {
        return;
      }
      await EditorLauncher.createAndOpen(
        context,
        graph: graph,
        name: expression.toExpressionString(),
      );
    } on ExpressionConversionException catch (error) {
      if (mounted) {
        _toast(error.message);
      }
    }
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _copyExpression() async {
    final String text = _controller.text.trim();
    if (text.isEmpty) {
      return;
    }
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) {
      _toast('عبارت در حافظه کپی شد.');
    }
  }

  Future<void> _shareExpression() async {
    final String text = _controller.text.trim();
    if (text.isEmpty) {
      return;
    }
    try {
      await FileExchange.shareTextFile(
        fileName: 'boolean-expression.txt',
        content: text,
        mimeType: 'text/plain',
        subject: 'عبارت بولی — Logic Lab',
      );
    } catch (error) {
      if (mounted) {
        _toast('خروجی گرفتن انجام نشد: $error');
      }
    }
  }

  Future<void> _compareWithCircuit() async {
    final BoolExpr? expression = _expression;
    if (expression == null) {
      return;
    }
    final ProjectsController projects = context.read<ProjectsController>();
    final List<CircuitProject> candidates = projects.projects;
    if (candidates.isEmpty) {
      _toast('هنوز مداری برای مقایسه وجود ندارد.');
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
                'انتخاب مدار برای بررسی هم‌ارزی',
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
                        child: Text(
                          project.name,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
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
    final ExpressionEquivalenceResult result = ExpressionEquivalence.compare(
      expression,
      selected.graph,
    );
    if (!mounted) {
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        icon: Icon(
          result.equivalent
              ? Icons.verified_rounded
              : Icons.compare_arrows_rounded,
          color: result.equivalent
              ? LogicLabColors.of(context).success
              : Theme.of(context).colorScheme.primary,
        ),
        title: Text(result.equivalent ? 'هم‌ارز هستند' : 'هم‌ارز نیستند'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(result.message),
            for (final String mismatch in result.mismatches.take(6))
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: TechnicalText(
                  mismatch,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ابزار عبارت بولی'),
        actions: <Widget>[
          IconButton(
            tooltip: 'ساخت مدار از عبارت',
            onPressed: _expression == null ? null : _buildCircuit,
            icon: const Icon(Icons.account_tree_rounded),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: ResponsiveCenter(
          maxWidth: 1100,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              // While the analysis tab only shows its empty state there is no
              // inner scroll view, so the page itself scrolls. Otherwise the
              // result area keeps its own scrolling and the page stays fixed.
              final bool pageScrolls = _tab == 0 && _expression == null;
              if (pageScrolls) {
                return SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      _editorCard(context),
                      const SizedBox(height: 12),
                      _tabs(context),
                      const SizedBox(height: 12),
                      _analysisTab(context),
                    ],
                  ),
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  _editorCard(context),
                  const SizedBox(height: 12),
                  _tabs(context),
                  const SizedBox(height: 12),
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      child: _tab == 0
                          ? _analysisTab(context)
                          : _compareTab(context),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  /// Compact style for the icon buttons of the header, so they stay on one
  /// line next to the title on narrow screens.
  static final ButtonStyle _compactIconStyle = IconButton.styleFrom(
    minimumSize: const Size(40, 40),
    padding: EdgeInsets.zero,
    visualDensity: VisualDensity.compact,
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
  );

  /// The sample below the title. The label stays right-to-left while the
  /// expression itself is written left-to-right, so neither one is garbled.
  Widget _sampleLine(ThemeData theme) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text('نمونه:', style: theme.textTheme.bodySmall),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            '(A & B) | !C',
            style: theme.textTheme.bodySmall?.copyWith(
              fontFamily: 'JetBrainsMono',
            ),
            textDirection: TextDirection.ltr,
            textAlign: TextAlign.left,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            softWrap: false,
          ),
        ),
      ],
    );
  }

  Widget _editorCard(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    // On narrow screens the heading and the actions get their own rows, so
    // the title and the sample are never squeezed by the buttons.
    final bool compact = MediaQuery.sizeOf(context).width < 620;

    final Widget heading = Row(
      children: <Widget>[
        IconTile(icon: Icons.functions_rounded, size: 38),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'عبارت بولی',
                style: theme.textTheme.titleMedium,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              _sampleLine(theme),
            ],
          ),
        ),
      ],
    );

    final Widget actions = Wrap(
      spacing: 4,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: <Widget>[
        FilledButton.icon(
          onPressed: _parse,
          icon: const Icon(Icons.play_arrow_rounded),
          label: const Text('محاسبه'),
        ),
        IconButton(
          tooltip: 'کپی عبارت',
          onPressed: _copyExpression,
          style: _compactIconStyle,
          icon: const Icon(Icons.copy_rounded),
        ),
        IconButton(
          tooltip: 'خروجی گرفتن از عبارت',
          onPressed: _shareExpression,
          style: _compactIconStyle,
          icon: const Icon(Icons.ios_share_rounded),
        ),
        IconButton(
          tooltip: 'بررسی هم‌ارزی با یک مدار',
          onPressed: _expression == null ? null : _compareWithCircuit,
          style: _compactIconStyle,
          icon: const Icon(Icons.compare_arrows_rounded),
        ),
      ],
    );

    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (compact) ...<Widget>[
            heading,
            const SizedBox(height: 10),
            Align(alignment: AlignmentDirectional.centerStart, child: actions),
          ] else
            Row(
              children: <Widget>[
                Expanded(child: heading),
                const SizedBox(width: 8),
                actions,
              ],
            ),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            onSubmitted: (_) => _parse(),
            onChanged: (_) => setState(() {}),
            textDirection: TextDirection.ltr,
            textAlign: TextAlign.left,
            style: LogicLabTheme.technical(theme.textTheme.bodyLarge),
            decoration: InputDecoration(
              hintText: 'A & B | !C',
              hintStyle: LogicLabTheme.technical(theme.textTheme.bodyMedium)
                  .copyWith(color: theme.colorScheme.onSurfaceVariant),
              errorText: _parseError?.message,
              suffixIcon: IconButton(
                tooltip: 'پاک کردن',
                onPressed: () {
                  _controller.clear();
                  _parse();
                },
                icon: const Icon(Icons.clear_rounded),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              _TokenButton(
                label: '&',
                tooltip: 'و منطقی (AND)',
                onTap: () => _insertToken(' & '),
              ),
              _TokenButton(
                label: '|',
                tooltip: 'یا منطقی (OR)',
                onTap: () => _insertToken(' | '),
              ),
              _TokenButton(
                label: '^',
                tooltip: 'یای انحصاری (XOR)',
                onTap: () => _insertToken(' ^ '),
              ),
              _TokenButton(
                label: '!',
                tooltip: 'نفی (NOT)',
                onTap: () => _insertToken('!'),
              ),
              _TokenButton(
                label: '( )',
                tooltip: 'پرانتز',
                onTap: () => _insertToken('( )'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'نحوه پشتیبانی‌شده: متغیرهای تک‌حرفی مانند A و B، عملگرهای & | ! ^ و پرانتز. '
            'کلمات AND، OR، NOT و XOR نیز پذیرفته می‌شوند.',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _tabs(BuildContext context) {
    // On narrow screens the long labels wrap onto a second line and the tab
    // bar becomes unnecessarily tall, so short labels are used instead.
    final bool compact = MediaQuery.sizeOf(context).width < 620;
    return SegmentedButton<int>(
      segments: <ButtonSegment<int>>[
        ButtonSegment<int>(
          value: 0,
          label: Text(compact ? 'تحلیل' : 'تحلیل و جدول حقیقت'),
          icon: const Icon(Icons.insights_rounded),
        ),
        ButtonSegment<int>(
          value: 1,
          label: Text(compact ? 'مقایسه' : 'مقایسه دو عبارت'),
          icon: const Icon(Icons.compare_arrows_rounded),
        ),
      ],
      selected: <int>{_tab},
      onSelectionChanged: (Set<int> value) =>
          setState(() => _tab = value.first),
    );
  }

  Widget _analysisTab(BuildContext context) {
    if (_expression == null) {
      return EmptyState(
        icon: Icons.functions_rounded,
        title: 'یک عبارت وارد کنید',
        message: 'با وارد کردن یک عبارت، جدول حقیقت، نتیجه ارزیابی و شکل ساده‌شده محاسبه می‌شود.',
        action: FilledButton.icon(
          onPressed: () => _insertToken('(A & B) | !C'),
          icon: const Icon(Icons.auto_awesome_rounded),
          label: const Text('نمونه بساز'),
        ),
      );
    }
    return ListView(
      key: const ValueKey<String>('analysis'),
      children: <Widget>[
        _evaluationCard(context),
        const SizedBox(height: 12),
        _simplificationCard(context),
        const SizedBox(height: 12),
        _truthTableCard(context),
      ],
    );
  }

  Widget _evaluationCard(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ExpressionTruthTable? table = _truthTable;
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SectionHeader(
            title: 'ارزیابی عبارت',
            subtitle: 'نتیجه بر پایه همه ترکیب‌های متغیرها محاسبه شده است.',
          ),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              for (final String variable
                  in table?.variables ?? const <String>[])
                _variableChip(context, variable),
              if (table != null && table.variables.isEmpty)
                Text('بدون متغیر', style: theme.textTheme.bodySmall),
            ],
          ),
          const SizedBox(height: 12),
          if (table != null && table.rows.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: theme.colorScheme.outlineVariant),
              ),
              child: Row(
                children: <Widget>[
                  const Text('A'),
                  const SizedBox(width: 10),
                  Text(
                    'در ${PersianFormat.digits(table.rows.where((ExpressionTruthRow row) => row.output).length)}'
                    ' از ${PersianFormat.digits(table.rows.length)} ترکیب نتیجه ۱ است.',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _variableChip(BuildContext context, String variable) {
    final ThemeData theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          TechnicalText(
            variable,
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 6),
          Text('متغیر', style: theme.textTheme.labelSmall),
        ],
      ),
    );
  }

  Widget _simplificationCard(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final SimplificationResult? result = _simplification;
    if (result == null) {
      return const SizedBox.shrink();
    }
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SectionHeader(
            title: 'ساده‌سازی',
            subtitle: result.method,
            trailing: result.exact
                ? Icon(
                    Icons.verified_rounded,
                    color: LogicLabColors.of(context).success,
                    size: 20,
                  )
                : null,
          ),
          if (result.simplifiedText != null) ...<Widget>[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: theme.colorScheme.outlineVariant),
              ),
              child: TechnicalText(
                result.simplifiedText!,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                _statChip(
                  context,
                  'تعداد جمله‌ها',
                  PersianFormat.digits(result.termCount),
                ),
                _statChip(
                  context,
                  'تعداد لیتِرال',
                  PersianFormat.digits(result.literalCount),
                ),
                _statChip(context, 'دقیق؟', result.exact ? 'بله' : 'خیر'),
              ],
            ),
            const SizedBox(height: 10),
          ],
          InfoBanner(
            tone: result.exact
                ? InfoBannerTone.success
                : InfoBannerTone.warning,
            icon: result.exact
                ? Icons.check_circle_outline_rounded
                : Icons.info_outline_rounded,
            message: result.message,
          ),
        ],
      ),
    );
  }

  Widget _statChip(BuildContext context, String label, String value) {
    final ThemeData theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Text('$label: $value', style: theme.textTheme.labelSmall),
    );
  }

  Widget _truthTableCard(BuildContext context) {
    final ExpressionTruthTable? table = _truthTable;
    if (table == null) {
      return const SizedBox.shrink();
    }
    final ThemeData theme = Theme.of(context);
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SectionHeader(
            title: 'جدول حقیقت عبارت',
            subtitle:
                '${PersianFormat.digits(table.rows.length)} ترکیب از روی متغیرهای واقعی محاسبه شده است.',
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 320),
              child: Column(
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      const SizedBox(
                        width: 48,
                        child: Center(
                          child: Text(
                            '#',
                            style: TextStyle(fontFamily: 'JetBrainsMono'),
                          ),
                        ),
                      ),
                      for (final String variable in table.variables)
                        SizedBox(
                          width: 62,
                          child: Center(
                            child: TechnicalText(
                              variable,
                              style: theme.textTheme.labelMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      const SizedBox(
                        width: 74,
                        child: Center(child: Text('Y')),
                      ),
                    ],
                  ),
                  const Divider(height: 1),
                  for (int index = 0; index < table.rows.length; index++)
                    Container(
                      decoration: BoxDecoration(
                        color: index.isEven
                            ? Colors.transparent
                            : theme.colorScheme.surfaceContainerLow.withValues(
                                alpha: 0.5,
                              ),
                      ),
                      child: Row(
                        children: <Widget>[
                          SizedBox(
                            width: 48,
                            child: Center(
                              child: Text(
                                PersianFormat.digits(index + 1),
                                style: theme.textTheme.labelSmall,
                              ),
                            ),
                          ),
                          for (final String variable in table.variables)
                            SizedBox(
                              width: 62,
                              child: Center(
                                child: TechnicalText(
                                  table.rows[index].inputs[variable] == true
                                      ? '1'
                                      : '0',
                                  style: theme.textTheme.labelMedium,
                                ),
                              ),
                            ),
                          SizedBox(
                            width: 74,
                            child: Center(
                              child: SignalPill(
                                value: table.rows[index].output,
                                compact: true,
                              ),
                            ),
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
    );
  }

  Widget _compareTab(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return ListView(
      key: const ValueKey<String>('compare'),
      children: <Widget>[
        SurfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              SectionHeader(
                title: 'مقایسه دو عبارت',
                subtitle: 'دو عبارت با محاسبه جدول حقیقت روی همه ترکیب‌های متغیرهای مشترک مقایسه می‌شوند.',
              ),
              TextField(
                controller: _compareController,
                textDirection: TextDirection.ltr,
                textAlign: TextAlign.left,
                style: LogicLabTheme.technical(theme.textTheme.bodyLarge),
                decoration: const InputDecoration(
                  labelText: 'عبارت دوم',
                  hintText: 'A | B',
                ),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _compare,
                icon: const Icon(Icons.compare_arrows_rounded),
                label: const Text('مقایسه کن'),
              ),
              if (_compareError != null) ...<Widget>[
                const SizedBox(height: 12),
                InfoBanner(
                  tone: InfoBannerTone.danger,
                  message: _compareError!,
                ),
              ],
              if (_comparison != null) ...<Widget>[
                const SizedBox(height: 12),
                InfoBanner(
                  tone: _comparison!.equivalent
                      ? InfoBannerTone.success
                      : InfoBannerTone.warning,
                  icon: _comparison!.equivalent
                      ? Icons.check_circle_outline_rounded
                      : Icons.warning_amber_rounded,
                  message: _comparison!.summary,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _TokenButton extends StatelessWidget {
  const _TokenButton({
    required this.label,
    required this.tooltip,
    required this.onTap,
  });

  final String label;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Tooltip(
      message: tooltip,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(40, 36),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child: TechnicalText(
          label,
          style:
              theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ) ??
              theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
      ),
    );
  }
}
