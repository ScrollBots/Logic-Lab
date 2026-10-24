import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'dart:convert';

import '../../../core/localization/persian_format.dart';
import '../../../core/app_info.dart';
import '../../../core/services/file_exchange.dart';
import '../../../core/theme/logic_lab_theme.dart';
import '../../../core/widgets/common.dart';
import '../../learn/application/learning_controller.dart';
import '../../learn/data/learning_progress_repository.dart';
import '../../learn/domain/learning_state.dart';
import '../../projects/application/projects_controller.dart';
import '../../projects/domain/circuit_project.dart';
import '../../updates/presentation/update_settings_content.dart';
import '../application/settings_controller.dart';
import '../data/backup_codec.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final SettingsController settings = context.watch<SettingsController>();
    final ThemeData theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ResponsiveCenter(
          maxWidth: 860,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
          child: ListView(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.only(top: 10, bottom: 16),
                child: Row(
                  children: <Widget>[
                    IconTile(icon: Icons.tune_rounded),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text('تنظیمات', style: theme.textTheme.headlineSmall),
                          Text(
                            'ظاهر، رفتار و داده‌های برنامه',
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              _SettingsSection(
                title: 'ظاهر',
                icon: Icons.palette_outlined,
                children: <Widget>[
                  _ThemeModeSelector(settings: settings),
                  const SizedBox(height: 18),
                  Text(
                    'پالت رنگ',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'رنگ اصلی برنامه از این پالت‌ها انتخاب می‌شود.',
                    style: TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                  const SizedBox(height: 12),
                  _PaletteGrid(settings: settings),
                  const SizedBox(height: 16),
                  _CustomAccentRow(settings: settings),
                ],
              ),
              const SizedBox(height: 14),
              _SettingsSection(
                title: 'رفتار و دسترس‌پذیری',
                icon: Icons.accessibility_new_rounded,
                children: <Widget>[
                  _SwitchRow(
                    title: 'لرزش بازخورد',
                    subtitle:
                        'لرزش کوتاه هنگام تعامل با دکمه‌ها و کلیدهای مدار.',
                    value: settings.hapticsEnabled,
                    onChanged: settings.setHapticsEnabled,
                  ),
                  const Divider(height: 24),
                  _SwitchRow(
                    title: 'انیمیشن‌ها',
                    subtitle:
                        'با خاموش کردن، جابه‌جایی‌ها و تغییرهای بصری فوری انجام می‌شوند.',
                    value: settings.animationsEnabled,
                    onChanged: settings.setAnimationsEnabled,
                  ),
                  const Divider(height: 24),
                  _SignalColorRow(settings: settings),
                ],
              ),
              const SizedBox(height: 14),
              const _SettingsSection(
                title: 'داده‌ها',
                icon: Icons.storage_rounded,
                children: <Widget>[_DataTools()],
              ),
              const SizedBox(height: 14),
              const _SettingsSection(
                key: Key('updates-section'),
                title: 'به‌روزرسانی',
                icon: Icons.system_update_alt_rounded,
                children: <Widget>[UpdateSettingsContent()],
              ),
              const SizedBox(height: 14),
              const _SettingsSection(
                key: Key('about-section'),
                title: 'درباره برنامه',
                icon: Icons.info_outline_rounded,
                children: <Widget>[_AboutTile()],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({
    super.key,
    required this.title,
    required this.icon,
    required this.children,
  });

  final String title;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(icon, size: 19, color: theme.colorScheme.primary),
              const SizedBox(width: 9),
              Text(title, style: theme.textTheme.titleMedium),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }
}

class _ThemeModeSelector extends StatelessWidget {
  const _ThemeModeSelector({required this.settings});

  final SettingsController settings;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('حالت نمایش', style: theme.textTheme.titleSmall),
        const SizedBox(height: 10),
        SegmentedButton<ThemeMode>(
          segments: const <ButtonSegment<ThemeMode>>[
            ButtonSegment<ThemeMode>(
              value: ThemeMode.system,
              label: Text('سیستم'),
              icon: Icon(Icons.brightness_auto_rounded),
            ),
            ButtonSegment<ThemeMode>(
              value: ThemeMode.light,
              label: Text('روشن'),
              icon: Icon(Icons.light_mode_rounded),
            ),
            ButtonSegment<ThemeMode>(
              value: ThemeMode.dark,
              label: Text('تیره'),
              icon: Icon(Icons.dark_mode_rounded),
            ),
          ],
          selected: <ThemeMode>{settings.themeMode},
          onSelectionChanged: (Set<ThemeMode> value) {
            settings.setThemeMode(value.first);
            AppHaptics.selection(settings.hapticsEnabled);
          },
        ),
      ],
    );
  }
}

class _PaletteGrid extends StatelessWidget {
  const _PaletteGrid({required this.settings});

  final SettingsController settings;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final int columns = constraints.maxWidth > 520 ? 2 : 1;
        final double width =
            (constraints.maxWidth - (columns - 1) * 10) / columns;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: AppPalette.values
              .map(
                (AppPalette palette) => SizedBox(
                  width: width,
                  child: _PaletteTile(
                    palette: palette,
                    selected:
                        settings.value.paletteId == palette.id &&
                        settings.value.customAccent == null,
                    onTap: () {
                      settings.setPalette(palette.id);
                      AppHaptics.selection(settings.hapticsEnabled);
                    },
                  ),
                ),
              )
              .toList(growable: false),
        );
      },
    );
  }
}

class _PaletteTile extends StatelessWidget {
  const _PaletteTile({
    required this.palette,
    required this.selected,
    required this.onTap,
  });

  final AppPalette palette;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Semantics(
      button: true,
      selected: selected,
      label: 'پالت ${palette.name}',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color:
                selected
                    ? palette.seed.withValues(alpha: 0.08)
                    : theme.colorScheme.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? palette.seed : theme.colorScheme.outlineVariant,
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Row(
            children: <Widget>[
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: palette.seed,
                  borderRadius: BorderRadius.circular(9),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(palette.name, style: theme.textTheme.bodyMedium),
                    Text(
                      palette.description,
                      style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
                    ),
                  ],
                ),
              ),
              if (selected)
                Icon(Icons.check_circle_rounded, color: palette.seed, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

class _CustomAccentRow extends StatelessWidget {
  const _CustomAccentRow({required this.settings});

  final SettingsController settings;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color? custom = settings.value.customAccent;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('رنگ اصلی سفارشی', style: theme.textTheme.titleSmall),
        const SizedBox(height: 4),
        Text(
          'رنگ دلخواه خود را انتخاب کنید تا جایگزین رنگ پالت شود.',
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 10),
        Row(
          children: <Widget>[
            OutlinedButton.icon(
              onPressed: () => _pickColor(context, settings),
              icon: Icon(
                Icons.color_lens_outlined,
                color: custom ?? theme.colorScheme.primary,
              ),
              label: Text(custom == null ? 'انتخاب رنگ' : 'تغییر رنگ'),
            ),
            if (custom != null) ...<Widget>[
              const SizedBox(width: 10),
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: custom,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: theme.colorScheme.outlineVariant),
                ),
              ),
              const SizedBox(width: 10),
              TextButton(
                onPressed: () => settings.clearCustomAccent(),
                child: const Text('بازگشت به پالت'),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Future<void> _pickColor(
    BuildContext context,
    SettingsController settings,
  ) async {
    Color selected = settings.value.customAccent ?? settings.value.palette.seed;
    final Color? result = await showDialog<Color>(
      context: context,
      builder: (BuildContext context) => _ColorPickerDialog(initial: selected),
    );
    if (result != null) {
      settings.setCustomAccent(result);
    }
  }
}

class _ColorPickerDialog extends StatefulWidget {
  const _ColorPickerDialog({required this.initial});

  final Color initial;

  @override
  State<_ColorPickerDialog> createState() => _ColorPickerDialogState();
}

class _ColorPickerDialogState extends State<_ColorPickerDialog> {
  late HSLColor _color = HSLColor.fromColor(widget.initial);

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return AlertDialog(
      title: const Text('رنگ اصلی برنامه'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            height: 72,
            decoration: BoxDecoration(
              color: _color.toColor(),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: theme.colorScheme.outlineVariant),
            ),
            alignment: Alignment.center,
            child: Text(
              'Logic Lab',
              style: theme.textTheme.titleMedium?.copyWith(
                color:
                    _color.toColor().computeLuminance() > 0.5
                        ? Colors.black87
                        : Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 16),
          _slider(
            label: 'رنگ',
            value: _color.hue,
            max: 360,
            gradient: LinearGradient(
              colors: <Color>[
                for (double h = 0; h <= 360; h += 30)
                  HSLColor.fromAHSL(1, h, 0.85, 0.5).toColor(),
              ],
            ),
            onChanged: (double value) {
              setState(() => _color = _color.withHue(value));
            },
          ),
          _slider(
            label: 'اشباع',
            value: _color.saturation,
            max: 1,
            onChanged: (double value) {
              setState(() => _color = _color.withSaturation(value));
            },
          ),
          _slider(
            label: 'روشنایی',
            value: _color.lightness,
            max: 1,
            onChanged: (double value) {
              setState(() => _color = _color.withLightness(value));
            },
          ),
        ],
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('انصراف'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _color.toColor()),
          child: const Text('اعمال'),
        ),
      ],
    );
  }

  Widget _slider({
    required String label,
    required double value,
    required double max,
    required ValueChanged<double> onChanged,
    Gradient? gradient,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Text(label, style: Theme.of(context).textTheme.labelMedium),
            const Spacer(),
            Text(
              PersianFormat.digits((value * 100).round()),
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(
            context,
          ).copyWith(activeTrackColor: gradient == null ? null : Colors.white),
          child: Slider(
            value: value.clamp(0, max),
            max: max,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(title, style: theme.textTheme.bodyMedium),
              const SizedBox(height: 2),
              Text(subtitle, style: theme.textTheme.bodySmall),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Switch(value: value, onChanged: onChanged),
      ],
    );
  }
}

class _SignalColorRow extends StatelessWidget {
  const _SignalColorRow({required this.settings});

  final SettingsController settings;

  static const List<Color> _choices = <Color>[
    Color(0xFF1D9B72),
    Color(0xFF2F7D32),
    Color(0xFF1F5FCC),
    Color(0xFF7A3DB8),
    Color(0xFFB4450F),
    Color(0xFF6D7B8E),
  ];

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('رنگ سیگنال‌ها', style: theme.textTheme.titleSmall),
        const SizedBox(height: 4),
        Text(
          'رنگ سطح بالا (۱) و سطح پایین (۰) در بوم مدار.',
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        Row(
          children: <Widget>[
            Text('بالا', style: theme.textTheme.bodySmall),
            const SizedBox(width: 10),
            Expanded(
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _choices
                    .map(
                      (Color color) => _ColorDot(
                        color: color,
                        selected:
                            settings.value.highSignalValue == color.toARGB32(),
                        onTap: () => settings.setSignalColors(high: color),
                      ),
                    )
                    .toList(growable: false),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: <Widget>[
            Text('پایین', style: theme.textTheme.bodySmall),
            const SizedBox(width: 10),
            Expanded(
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _choices
                    .map(
                      (Color color) => _ColorDot(
                        color: color,
                        selected:
                            settings.value.lowSignalValue == color.toARGB32(),
                        onTap: () => settings.setSignalColors(low: color),
                      ),
                    )
                    .toList(growable: false),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ColorDot extends StatelessWidget {
  const _ColorDot({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: 'رنگ سیگنال',
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(
              color:
                  selected
                      ? Theme.of(context).colorScheme.onSurface
                      : Colors.transparent,
              width: 2.5,
            ),
          ),
          child:
              selected
                  ? const Icon(
                    Icons.check_rounded,
                    color: Colors.white,
                    size: 18,
                  )
                  : null,
        ),
      ),
    );
  }
}

class _DataTools extends StatefulWidget {
  const _DataTools();

  @override
  State<_DataTools> createState() => _DataToolsState();
}

class _DataToolsState extends State<_DataTools> {
  bool _busy = false;

  Future<void> _exportBackup() async {
    setState(() => _busy = true);
    try {
      final ProjectsController projects = context.read<ProjectsController>();
      final LearningController learning = context.read<LearningController>();
      final SettingsController settings = context.read<SettingsController>();
      await settings.flush();
      final Map<String, Object?> payload = <String, Object?>{
        'format': 'logic-lab-backup',
        'version': 1,
        'exportedAt': DateTime.now().toUtc().toIso8601String(),
        'projects': projects.projects
            .map((CircuitProject p) => p.toJson())
            .toList(growable: false),
        'learningProgress': learning.items.values
            .map(
              (LearningProgress item) => <String, Object?>{
                'itemId': item.itemId,
                'completed': item.completed,
                'bestScore': item.bestScore,
                'attempts': item.attempts,
                'updatedAt': item.updatedAt.toUtc().toIso8601String(),
              },
            )
            .toList(growable: false),
        'learningState': learning.exportState().toJson(),
        'settings': settings.value.toJson(),
      };
      await FileExchange.shareTextFile(
        fileName: 'logic-lab-backup.json',
        content: JsonEncoder.withIndent('  ').convert(payload),
        mimeType: 'application/json',
        subject: 'پشتیبان Logic Lab',
      );
    } catch (error) {
      if (mounted) {
        _toast('تهیه پشتیبان انجام نشد: $error');
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _restoreBackup() async {
    final PickedTextFile? file = await FileExchange.pickJsonFile();
    if (file == null || !mounted) {
      return;
    }
    final BackupPayload? backup = BackupCodec.decode(file.content);
    if (backup == null) {
      _toast('این فایل پشتیبان معتبر Logic Lab نیست.');
      return;
    }
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder:
          (BuildContext context) => AlertDialog(
            title: const Text('بازیابی پشتیبان'),
            content: Text(
              'این پشتیبان شامل ${PersianFormat.digits(backup.projects.length)} مدار است. '
              'با بازیابی، مدارهای فعلی جایگزین می‌شوند.',
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('انصراف'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('جایگزینی و بازیابی'),
              ),
            ],
          ),
    );
    if (confirmed != true || !mounted) {
      return;
    }
    setState(() => _busy = true);
    try {
      final ProjectsController projectsController =
          context.read<ProjectsController>();
      final LearningController learningController =
          context.read<LearningController>();
      final SettingsController settingsController =
          context.read<SettingsController>();
      await projectsController.replaceAll(backup.projects);
      await learningController.restoreAll(backup.progress);
      final LearningState? learningState = backup.learningState;
      if (learningState != null) {
        await learningController.restoreState(learningState);
      }
      final Map<String, Object?>? rawSettings = backup.settings;
      if (rawSettings != null) {
        try {
          settingsController.replaceSettings(AppSettings.fromJson(rawSettings));
        } catch (error) {
          debugPrint('Could not restore settings from backup: $error');
        }
      }
      if (mounted) {
        _toast('پشتیبان بازیابی شد.');
      }
    } catch (error) {
      if (mounted) {
        _toast('بازیابی انجام نشد: $error');
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _deleteAll() async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder:
          (BuildContext context) => AlertDialog(
            title: const Text('حذف همه داده‌ها'),
            content: const Text(
              'تمام مدارهای ذخیره‌شده، پیشرفت یادگیری و تنظیمات بازنشانی می‌شوند. '
              'این عمل قابل بازگشت نیست. پیش از ادامه، پشتیبان بگیرید.',
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
                child: const Text('حذف همه داده‌ها'),
              ),
            ],
          ),
    );
    if (confirmed != true || !mounted) {
      return;
    }
    setState(() => _busy = true);
    try {
      final ProjectsController projectsController =
          context.read<ProjectsController>();
      final LearningController learningController =
          context.read<LearningController>();
      await projectsController.deleteAllProjects();
      await learningController.resetAll();
      if (mounted) {
        _toast('همه داده‌ها حذف شد.');
      }
    } catch (error) {
      if (mounted) {
        _toast('حذف انجام نشد: $error');
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          'همه داده‌ها فقط روی همین دستگاه ذخیره می‌شود و هیچ اطلاعاتی به بیرون '
          'فرستاده نمی‌شود. برای اطمینان، می‌توانید پشتیبان JSON بگیرید.',
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 14),
        if (_busy) const LinearProgressIndicator(minHeight: 3),
        if (_busy) const SizedBox(height: 12),
        _ActionRow(
          icon: Icons.upload_rounded,
          title: 'تهیه پشتیبان کامل',
          subtitle: 'خروجی JSON شامل مدارها، پیشرفت و تنظیمات',
          onTap: _busy ? null : _exportBackup,
        ),
        const Divider(height: 24),
        _ActionRow(
          icon: Icons.restore_rounded,
          title: 'بازیابی از پشتیبان',
          subtitle: 'جایگزینی مدارهای فعلی با محتوای فایل پشتیبان',
          onTap: _busy ? null : _restoreBackup,
        ),
        const Divider(height: 24),
        _ActionRow(
          icon: Icons.delete_forever_rounded,
          title: 'حذف همه داده‌ها',
          subtitle:
              'پاک کردن مدارها، پیشرفت یادگیری و بازگشت به تنظیمات پیش‌فرض',
          destructive: true,
          onTap: _busy ? null : _deleteAll,
        ),
      ],
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.destructive = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color color =
        destructive ? theme.colorScheme.error : theme.colorScheme.primary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: <Widget>[
            IconTile(icon: icon, color: color, size: 40, radius: 12),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    title,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: destructive ? color : null,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(subtitle, style: theme.textTheme.bodySmall),
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
      ),
    );
  }
}

class _AboutTile extends StatelessWidget {
  const _AboutTile();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Column(
      children: <Widget>[
        Row(
          children: <Widget>[
            const BrandMark(size: 46),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    AppInfo.appName,
                    textDirection: TextDirection.ltr,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(AppInfo.appSubtitle, style: theme.textTheme.bodySmall),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: theme.colorScheme.outlineVariant),
          ),
          child: Row(
            children: <Widget>[
              Text('نسخه', style: theme.textTheme.bodySmall),
              const SizedBox(width: 8),
              // The semantic version keeps its dot separator and is never
              // localised into a different format. The internal build number
              // stays in the packaging metadata and is deliberately not shown
              // to the user.
              TechnicalText(
                key: const Key('about-version'),
                AppInfo.versionDisplay,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'این برنامه یک ابزار یادگیری مدارهای منطقی ترکیبی و ترتیبی است. '
          'همهٔ محاسبات روی دستگاه شما انجام می‌شود و هیچ دادهٔ شخصی جمع‌آوری '
          'یا ارسال نمی‌شود. تنها درخواست شبکه، بررسی وجود نسخهٔ تازه در '
          'GitHub است که می‌توانید در بخش «به‌روزرسانی» خاموشش کنید.',
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 6),
        // The footer mixes a Latin name, a Persian year and a separator. It is
        // rendered with an explicit LTR direction so the parts keep the order
        // they are written in, while the Persian phrase itself stays RTL.
        Directionality(
          textDirection: TextDirection.ltr,
          child: Text(
            key: const Key('about-footer'),
            AppInfo.copyright,
            textAlign: TextAlign.right,
            style: theme.textTheme.labelSmall,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: <Widget>[
            Expanded(
              child: OutlinedButton.icon(
                onPressed:
                    () => showLicensePage(
                      context: context,
                      applicationName: AppInfo.appName,
                      applicationVersion: AppInfo.versionDisplay,
                      applicationLegalese:
                          '${AppInfo.appSubtitle} — فونت وزیرمتن و JetBrains Mono با مجوز SIL Open Font License منتشر شده‌اند.',
                    ),
                icon: const Icon(Icons.description_outlined),
                label: const Text('مجوزها'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
