import 'package:flutter/material.dart';

import '../../../core/theme/logic_lab_theme.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/gate_symbol.dart';
import '../../boolean_tools/presentation/boolean_workspace_screen.dart';
import '../../editor/domain/circuit_models.dart';
import '../../editor/domain/component_spec.dart';
import '../../editor/domain/circuit_templates.dart';
import '../../editor/domain/circuit_validator.dart';
import '../../editor/presentation/circuit_editor_screen.dart';
import '../../editor/presentation/circuit_preview.dart';

class LabScreen extends StatefulWidget {
  const LabScreen({super.key});

  @override
  State<LabScreen> createState() => _LabScreenState();
}

class _LabScreenState extends State<LabScreen> {
  ComponentType _gate = ComponentType.andGate;
  bool _a = false;
  bool _b = false;

  CircuitGraph _buildBench() {
    final CircuitNode a = CircuitNode(
      id: 'bench-a',
      type: ComponentType.inputPin,
      position: const CanvasPoint(80, 140),
      label: 'A',
      inputValue: _a,
    );
    final CircuitNode b = CircuitNode(
      id: 'bench-b',
      type: ComponentType.inputPin,
      position: const CanvasPoint(80, 300),
      label: 'B',
      inputValue: _b,
    );
    final int inputCount = _gate == ComponentType.notGate ? 1 : 2;
    final CircuitNode gate = CircuitNode(
      id: 'bench-gate',
      type: _gate,
      position: const CanvasPoint(340, 220),
      label: _gate.technicalName,
      inputCount: inputCount,
    );
    final CircuitNode out = CircuitNode(
      id: 'bench-out',
      type: ComponentType.outputPin,
      position: const CanvasPoint(600, 220),
      label: 'Y',
    );
    return CircuitGraph(
      nodes: <CircuitNode>[a, b, gate, out],
      wires: <CircuitWire>[
        CircuitWire(
          id: 'bench-w1',
          fromNodeId: a.id,
          toNodeId: gate.id,
          toInputIndex: 0,
        ),
        if (inputCount == 2)
          CircuitWire(
            id: 'bench-w2',
            fromNodeId: b.id,
            toNodeId: gate.id,
            toInputIndex: 1,
          ),
        CircuitWire(
          id: 'bench-w3',
          fromNodeId: gate.id,
          toNodeId: out.id,
          toInputIndex: 0,
        ),
      ],
    );
  }

  Future<void> _openTemplate(CircuitTemplate template) async {
    await EditorLauncher.createAndOpen(
      context,
      graph: template.builder(),
      name: template.title,
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final CircuitGraph bench = _buildBench();
    final SimulationResult report = CircuitValidator.simulate(bench);
    final bool? output = report.signalOf('bench-out').booleanValue;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ResponsiveCenter(
          maxWidth: 1120,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
          child: ListView(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.only(top: 10, bottom: 14),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            'آزمایشگاه',
                            style: theme.textTheme.headlineSmall,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'رفتار گیت‌ها را زنده ببینید یا با یک الگوی آماده شروع کنید.',
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    IconTile(icon: Icons.science_outlined),
                  ],
                ),
              ),
              _benchCard(context, bench, report, output),
              const SizedBox(height: 16),
              SectionHeader(
                title: 'الگوهای آماده',
                subtitle: 'مدارهای واقعی که می‌توانید فوراً ویرایش کنید.',
              ),
              LayoutBuilder(
                builder: (BuildContext context, BoxConstraints constraints) {
                  final int columns = constraints.maxWidth > 760 ? 2 : 1;
                  final double width =
                      (constraints.maxWidth - (columns - 1) * 12) / columns;
                  return Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: CircuitTemplates.all
                        .map(
                          (CircuitTemplate template) => SizedBox(
                            width: width,
                            child: _TemplateCard(
                              template: template,
                              onOpen: () => _openTemplate(template),
                            ),
                          ),
                        )
                        .toList(growable: false),
                  );
                },
              ),
              const SizedBox(height: 16),
              SurfaceCard(
                onTap:
                    () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder:
                            (BuildContext context) =>
                                const BooleanWorkspaceScreen(),
                      ),
                    ),
                child: Row(
                  children: <Widget>[
                    IconTile(icon: Icons.functions_rounded),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            'میز کار عبارت بولی',
                            style: theme.textTheme.titleMedium,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'تجزیه عبارت، جدول حقیقت، ساده‌سازی و ساخت مدار.',
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_left_rounded),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _benchCard(
    BuildContext context,
    CircuitGraph bench,
    SimulationResult report,
    bool? output,
  ) {
    final ThemeData theme = Theme.of(context);
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SectionHeader(
            title: 'میز آزمایش گیت',
            subtitle:
                'خروجی این میز با همان شبیه‌ساز واقعی برنامه محاسبه می‌شود.',
            trailing: SignalPill(value: output, label: 'Y'),
          ),
          SizedBox(
            height: 96,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: <Widget>[
                  for (final ComponentType type in ComponentLibrary.basicGates)
                    Padding(
                      padding: const EdgeInsetsDirectional.only(end: 8),
                      child: _GateChoice(
                        type: type,
                        selected: type == _gate,
                        onTap: () => setState(() => _gate = type),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final bool wide = constraints.maxWidth > 560;
              final Widget preview = Container(
                height: 190,
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: theme.colorScheme.outlineVariant),
                ),
                child: CircuitPreview(graph: bench),
              );
              final Widget controls = Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  _InputToggle(
                    label: 'A',
                    value: _a,
                    onChanged: (bool value) => setState(() => _a = value),
                  ),
                  const SizedBox(height: 8),
                  _InputToggle(
                    label: 'B',
                    value: _b,
                    enabled: _gate != ComponentType.notGate,
                    onChanged: (bool value) => setState(() => _b = value),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'خروجی = ${report.isValid ? (output == true ? '۱' : '۰') : '؟'}',
                    style: theme.textTheme.titleSmall,
                    textDirection: TextDirection.ltr,
                  ),
                ],
              );
              if (wide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(flex: 3, child: preview),
                    const SizedBox(width: 12),
                    Expanded(flex: 2, child: controls),
                  ],
                );
              }
              return Column(
                children: <Widget>[
                  preview,
                  const SizedBox(height: 12),
                  controls,
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _GateChoice extends StatelessWidget {
  const _GateChoice({
    required this.type,
    required this.selected,
    required this.onTap,
  });

  final ComponentType type;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Semantics(
      button: true,
      selected: selected,
      label: 'دروازه ${type.persianName}',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 74,
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color:
                selected
                    ? theme.colorScheme.primary.withValues(alpha: 0.1)
                    : theme.colorScheme.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color:
                  selected
                      ? theme.colorScheme.primary
                      : theme.colorScheme.outlineVariant,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Column(
            children: <Widget>[
              GateSymbol(
                type: type,
                size: 32,
                strokeWidth: 1.6,
                color:
                    selected
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 6),
              TechnicalText(
                type.technicalName,
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color:
                      selected
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InputToggle extends StatelessWidget {
  const _InputToggle({
    required this.label,
    required this.value,
    required this.onChanged,
    this.enabled = true,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final LogicLabColors colors = LogicLabColors.of(context);
    return Semantics(
      label: 'ورودی $label',
      toggled: value,
      button: true,
      enabled: enabled,
      child: Material(
        color:
            enabled
                ? theme.colorScheme.surfaceContainerLow
                : theme.colorScheme.surfaceContainerLow.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: enabled ? () => onChanged(!value) : null,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color:
                    value
                        ? colors.highSignal.withValues(alpha: 0.4)
                        : theme.colorScheme.outlineVariant,
              ),
            ),
            child: Row(
              children: <Widget>[
                TechnicalText(
                  label,
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  enabled
                      ? (value ? 'سطح بالا (۱)' : 'سطح پایین (۰)')
                      : 'برای این گیت بی‌اثر است',
                  style: theme.textTheme.bodySmall,
                ),
                const Spacer(),
                TechnicalText(
                  value ? '1' : '0',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: value ? colors.highSignal : colors.lowSignal,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TemplateCard extends StatelessWidget {
  const _TemplateCard({required this.template, required this.onOpen});

  final CircuitTemplate template;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return SurfaceCard(
      onTap: onOpen,
      semanticLabel: 'باز کردن الگوی ${template.title}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(template.title, style: theme.textTheme.titleMedium),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(template.level, style: theme.textTheme.labelSmall),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(template.description, style: theme.textTheme.bodySmall),
          const SizedBox(height: 10),
          SizedBox(
            height: 96,
            child: Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: theme.colorScheme.outlineVariant),
              ),
              child: CircuitPreview(graph: template.builder()),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: <Widget>[
              Text(
                'باز کردن در ویرایشگر',
                style: theme.textTheme.labelMedium?.copyWith(
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
