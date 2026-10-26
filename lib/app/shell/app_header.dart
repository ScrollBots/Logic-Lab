import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/localization/persian_format.dart';

/// Height of the fixed application header, used by the shell to offset the
/// page stack below it.
const double kAppHeaderHeight = 72;

/// Fixed header at the top of the shell.
class AppHeader extends StatelessWidget {
  const AppHeader({super.key, required this.onSettings});

  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double width = constraints.maxWidth;
        // The identity is constrained to half the available width so it can
        // never overlap the side widgets, which keep their natural size.
        final double identityWidth = (width * 0.5).clamp(0, 200);

        return Container(
          key: const Key('app-header'),
          height: kAppHeaderHeight,
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
          child: Stack(
            children: <Widget>[
              Align(
                alignment: Alignment.centerRight,
                child: _SettingsButton(onPressed: onSettings),
              ),
              Align(alignment: Alignment.centerLeft, child: const AppClock()),
              Align(
                alignment: Alignment.center,
                child: SizedBox(
                  width: identityWidth,
                  child: const _AppIdentity(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SettingsButton extends StatelessWidget {
  const _SettingsButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return IconButton(
      key: const Key('app-header-settings'),
      tooltip: 'تنظیمات',
      icon: Icon(
        Icons.settings_outlined,
        size: 22,
        color: theme.colorScheme.onSurfaceVariant,
      ),
      constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
      onPressed: onPressed,
    );
  }
}

class _AppIdentity extends StatelessWidget {
  const _AppIdentity();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Column(
      key: const Key('app-header-identity'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        Text(
          'Logic Lab',
          textDirection: TextDirection.ltr,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: theme.colorScheme.onSurface,
            letterSpacing: 0,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          'آزمایشگاه منطق',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class AppClock extends StatefulWidget {
  const AppClock({super.key});

  @override
  State<AppClock> createState() => _AppClockState();
}

class _AppClockState extends State<AppClock> {
  DateTime _now = PersianFormat.tehranNow();
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) {
        setState(() => _now = PersianFormat.tehranNow());
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      key: const Key('app-header-clock'),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
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
            size: 14,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 4),
          Text(
            PersianFormat.clock(_now),
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
