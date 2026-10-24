import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/app_info.dart';
import '../../../core/localization/persian_format.dart';
import '../../../core/widgets/common.dart';
import '../../settings/application/settings_controller.dart';
import '../application/update_controller.dart';
import '../domain/app_release.dart';
import 'update_prompt.dart';

/// The "updates" block of the settings screen.
///
/// It carries the switch that controls the automatic check, the installed
/// version, the last check time and an explicit "check now" action, so the
/// single network request of the app is never a hidden one.
class UpdateSettingsContent extends StatelessWidget {
  const UpdateSettingsContent({super.key});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final SettingsController settings = context.watch<SettingsController>();
    final UpdateController updates = context.watch<UpdateController>();
    final AppRelease? available = updates.release;
    final String? skipped = updates.skippedVersion;

    return Column(
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
                    'بررسی خودکار به‌روزرسانی',
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'حداکثر یک‌بار در روز از GitHub پرسیده می‌شود نسخهٔ '
                    'تازه‌تری منتشر شده یا نه. فقط یک درخواست ساده فرستاده '
                    'می‌شود و هیچ اطلاعاتی از شما ارسال نمی‌شود.',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Switch(
              key: const Key('update-auto-switch'),
              value: settings.updatesEnabled,
              onChanged: settings.setUpdatesEnabled,
            ),
          ],
        ),
        const Divider(height: 26),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text('نسخهٔ نصب‌شده', style: theme.textTheme.bodySmall),
                  const SizedBox(height: 3),
                  TechnicalText(
                    AppInfo.versionDisplay,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _lastCheckLabel(updates),
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            OutlinedButton.icon(
              key: const Key('update-check-now'),
              onPressed:
                  updates.isChecking ? null : () => _checkNow(context, updates),
              icon:
                  updates.isChecking
                      ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                      : const Icon(Icons.refresh_rounded),
              label: Text(updates.isChecking ? 'در حال بررسی…' : 'بررسی الان'),
            ),
          ],
        ),
        if (available != null && updates.status == UpdateStatus.available) ...[
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: theme.colorScheme.primary.withValues(alpha: 0.35),
              ),
            ),
            child: Row(
              children: <Widget>[
                Icon(
                  Icons.system_update_alt_rounded,
                  size: 18,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'نسخهٔ ${available.version} در دسترس است.',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
                TextButton(
                  key: const Key('update-open-prompt'),
                  onPressed:
                      () => promptForUpdate(
                        context,
                        controller: updates,
                        release: available,
                      ),
                  child: const Text('جزئیات'),
                ),
              ],
            ),
          ),
        ],
        if (skipped != null && available == null) ...<Widget>[
          const SizedBox(height: 8),
          Text(
            'نسخهٔ $skipped به «بعداً» موکول شده است؛ با «بررسی الان» دوباره '
            'پیشنهاد می‌شود.',
            style: theme.textTheme.bodySmall,
          ),
        ],
        if (updates.status == UpdateStatus.failed &&
            updates.failureMessage != null) ...<Widget>[
          const SizedBox(height: 8),
          Text(
            updates.failureMessage!,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _checkNow(BuildContext context, UpdateController updates) async {
    final AppRelease? release = await updates.check(manual: true);
    if (!context.mounted) {
      return;
    }
    if (release == null) {
      final String message =
          updates.failureMessage ??
          'برنامه به‌روز است (نسخهٔ ${AppInfo.versionDisplay}).';
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message)));
      return;
    }
    await promptForUpdate(context, controller: updates, release: release);
  }

  static String _lastCheckLabel(UpdateController updates) {
    final DateTime? last = updates.lastCheckAt;
    if (last == null) {
      return 'هنوز بررسی نشده است.';
    }
    return 'آخرین بررسی: ${PersianFormat.relativeDate(last)}';
  }
}
