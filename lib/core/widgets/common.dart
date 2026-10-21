import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/logic_lab_theme.dart';

class SurfaceCard extends StatelessWidget {
  const SurfaceCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.onTap,
    this.onLongPress,
    this.color,
    this.borderColor,
    this.radius = LogicLabTheme.cardRadius,
    this.semanticLabel,
    this.clipBehavior = Clip.antiAlias,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final Color? color;
  final Color? borderColor;
  final double radius;
  final String? semanticLabel;
  final Clip clipBehavior;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool interactive = onTap != null || onLongPress != null;
    final Widget content = Padding(padding: padding, child: child);
    final Widget material = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(radius),
        child: content,
      ),
    );

    return Semantics(
      label: semanticLabel,
      button: interactive,
      container: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: color ?? theme.colorScheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(
            color: borderColor ?? theme.colorScheme.outlineVariant,
          ),
          boxShadow: <BoxShadow>[
            if (theme.brightness == Brightness.light)
              BoxShadow(
                color: const Color(0xFF15233C).withValues(alpha: 0.035),
                blurRadius: 20,
                offset: const Offset(0, 6),
              )
            else
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.16),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(radius),
          clipBehavior: clipBehavior,
          child: interactive ? material : content,
        ),
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    this.padding = const EdgeInsets.only(bottom: 12),
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(title, style: theme.textTheme.titleLarge),
                if (subtitle != null) ...<Widget>[
                  const SizedBox(height: 3),
                  Text(subtitle!, style: theme.textTheme.bodySmall),
                ],
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 38, this.showName = false});

  final double size;
  final bool showName;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final Widget mark = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: scheme.primary,
        borderRadius: BorderRadius.circular(size * 0.3),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: scheme.primary.withValues(alpha: 0.18),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: CustomPaint(painter: _GateGlyphPainter(color: scheme.onPrimary)),
    );
    if (!showName) {
      return Semantics(label: 'Logic Lab', image: true, child: mark);
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        mark,
        const SizedBox(width: 10),
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Logic Lab',
              textDirection: TextDirection.ltr,
              style: LogicLabTheme.technical(
                Theme.of(context).textTheme.titleMedium,
              ).copyWith(fontWeight: FontWeight.w700, color: scheme.onSurface),
            ),
            Text(
              'آزمایشگاه منطق',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(height: 1.25),
            ),
          ],
        ),
      ],
    );
  }
}

class _GateGlyphPainter extends CustomPainter {
  const _GateGlyphPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint stroke =
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(1.4, size.width * 0.055)
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round;
    final double left = size.width * 0.2;
    final double right = size.width * 0.7;
    final double top = size.height * 0.3;
    final double bottom = size.height * 0.7;
    final double mid = size.height * 0.5;
    final Path gate =
        Path()
          ..moveTo(left, top)
          ..lineTo(size.width * 0.48, top)
          ..quadraticBezierTo(right, top, right, mid)
          ..quadraticBezierTo(right, bottom, size.width * 0.48, bottom)
          ..lineTo(left, bottom)
          ..close();
    canvas.drawPath(gate, stroke);
    canvas.drawLine(Offset(size.width * 0.08, mid), Offset(left, mid), stroke);
    final double outStart = right;
    final double outEnd = size.width * 0.84;
    canvas.drawLine(Offset(outStart, mid), Offset(outEnd, mid), stroke);
    canvas.drawCircle(
      Offset(outEnd, mid),
      size.width * 0.045,
      Paint()..color = color,
    );
    canvas.drawLine(
      Offset(size.width * 0.08, top + (mid - top) * 0.2),
      Offset(left, top + (mid - top) * 0.2),
      stroke,
    );
  }

  @override
  bool shouldRepaint(covariant _GateGlyphPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
    this.compact = false,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return SurfaceCard(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: compact ? 20 : 30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: compact ? 48 : 58,
              height: compact ? 48 : 58,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(icon, color: theme.colorScheme.primary, size: 27),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 5),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 390),
              child: Text(
                message,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall,
              ),
            ),
            if (action != null) ...<Widget>[
              const SizedBox(height: 16),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

class TechnicalText extends StatelessWidget {
  const TechnicalText(
    this.text, {
    super.key,
    this.style,
    this.color,
    this.maxLines,
    this.overflow,
    this.textAlign,
  });

  final String text;
  final TextStyle? style;
  final Color? color;
  final int? maxLines;
  final TextOverflow? overflow;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    final TextStyle base =
        style ?? Theme.of(context).textTheme.bodyMedium ?? const TextStyle();
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Text(
        text,
        style: LogicLabTheme.technical(base).copyWith(color: color),
        maxLines: maxLines,
        overflow: overflow,
        textAlign: textAlign,
      ),
    );
  }
}

class SignalPill extends StatelessWidget {
  const SignalPill({
    super.key,
    required this.value,
    this.label,
    this.compact = false,
  });

  /// True = HIGH, false = LOW, null = invalid / unresolved.
  final bool? value;
  final String? label;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final LogicLabColors colors = LogicLabColors.of(context);
    final Color color =
        value == null
            ? colors.unknownSignal
            : value!
            ? colors.highSignal
            : colors.lowSignal;
    final String state =
        value == null
            ? '؟'
            : value!
            ? '1'
            : '0';
    final String semantics =
        value == null
            ? 'نامشخص'
            : value!
            ? 'بالا'
            : 'پایین';
    return Semantics(
      label: label == null ? semantics : '$label، $semantics',
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 7 : 9,
          vertical: compact ? 3 : 4,
        ),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(7),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (label != null) ...<Widget>[
              Text(
                label!,
                style: Theme.of(
                  context,
                ).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(width: 5),
            ],
            TechnicalText(
              state,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w700,
                fontSize: compact ? 11 : 12,
              ),
              color: color,
            ),
          ],
        ),
      ),
    );
  }
}

class InfoBanner extends StatelessWidget {
  const InfoBanner({
    super.key,
    required this.message,
    this.icon = Icons.info_outline_rounded,
    this.tone = InfoBannerTone.neutral,
    this.action,
  });

  final String message;
  final IconData icon;
  final InfoBannerTone tone;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final LogicLabColors logicColors = LogicLabColors.of(context);
    final Color color = switch (tone) {
      InfoBannerTone.neutral => Theme.of(context).colorScheme.primary,
      InfoBannerTone.success => logicColors.success,
      InfoBannerTone.warning => logicColors.warning,
      InfoBannerTone.danger => logicColors.danger,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
                height: 1.65,
              ),
            ),
          ),
          if (action != null) ...<Widget>[const SizedBox(width: 8), action!],
        ],
      ),
    );
  }
}

enum InfoBannerTone { neutral, success, warning, danger }

class ResponsiveCenter extends StatelessWidget {
  const ResponsiveCenter({
    super.key,
    required this.child,
    this.maxWidth = 1120,
    this.padding = EdgeInsets.zero,
  });

  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: Padding(
        padding: padding,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: child,
        ),
      ),
    );
  }
}

class IconTile extends StatelessWidget {
  const IconTile({
    super.key,
    required this.icon,
    this.color,
    this.size = 42,
    this.radius = 13,
    this.iconSize = 21,
  });

  final IconData icon;
  final Color? color;
  final double size;
  final double radius;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final Color tint = color ?? Theme.of(context).colorScheme.primary;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: tint.withValues(alpha: 0.14)),
      ),
      child: Icon(icon, color: tint, size: iconSize),
    );
  }
}

class LabelValueRow extends StatelessWidget {
  const LabelValueRow({
    super.key,
    required this.label,
    required this.value,
    this.icon,
  });

  final String label;
  final String value;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: <Widget>[
          if (icon != null) ...<Widget>[
            Icon(icon, size: 17, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(width: 8),
          ],
          Text(label, style: theme.textTheme.bodySmall),
          const Spacer(),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.left,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
