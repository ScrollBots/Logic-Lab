import 'package:flutter/material.dart';

import '../../../core/theme/logic_lab_theme.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/gate_symbol.dart';
import '../domain/learning_content.dart';

/// Interactive reference for the seven standard gates. Every card runs the
/// real truth table of the gate and lets the learner play with both inputs.
class GateReferenceScreen extends StatelessWidget {
  const GateReferenceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('مرجع گیت‌ها')),
      body: SafeArea(
        bottom: false,
        child: ResponsiveCenter(
          maxWidth: 1120,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
          child: ListView(
            children: <Widget>[
              const SectionHeader(
                title: 'رفتار گیت‌ها',
                subtitle:
                    'هر کارت شامل نماد استاندارد، عبارت بولی و جدول حقیقت واقعی همان گیت است. '
                    'با کلیدهای A و B خروجی را زنده آزمایش کنید.',
              ),
              LayoutBuilder(
                builder: (BuildContext context, BoxConstraints constraints) {
                  final int columns = constraints.maxWidth > 480 ? 2 : 1;
                  final double width =
                      (constraints.maxWidth - (columns - 1) * 12) / columns;
                  return Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: kGateDefinitions
                        .map(
                          (GateDefinition gate) => SizedBox(
                            width: width,
                            child: GateCard(gate: gate),
                          ),
                        )
                        .toList(growable: false),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class GateCard extends StatefulWidget {
  const GateCard({super.key, required this.gate});

  final GateDefinition gate;

  @override
  State<GateCard> createState() => _GateCardState();
}

class _GateCardState extends State<GateCard> {
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
                onChanged: (bool value) => setState(() => _a = value),
              ),
              const SizedBox(width: 6),
              _MiniSwitch(
                label: 'B',
                value: _b,
                onChanged: (bool value) => setState(() => _b = value),
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
