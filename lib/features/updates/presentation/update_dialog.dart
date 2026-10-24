import 'package:flutter/material.dart';

import '../../../core/localization/persian_format.dart';
import '../../../core/widgets/common.dart';
import '../domain/app_release.dart';
import '../domain/semantic_version.dart';

/// What the user chose in the update prompt.
enum UpdateChoice { later, download }

/// Shows the "a new version is available" prompt.
///
/// The prompt offers exactly two actions: postpone, or download. Dismissing
/// it by tapping outside counts as "not now" and is deliberately not
/// remembered, so the question is asked again on the next launch.
Future<UpdateChoice?> showUpdateDialog(
  BuildContext context, {
  required AppRelease release,
  required SemanticVersion currentVersion,
}) {
  return showDialog<UpdateChoice>(
    context: context,
    builder:
        (BuildContext context) =>
            UpdateDialog(release: release, currentVersion: currentVersion),
  );
}

class UpdateDialog extends StatelessWidget {
  const UpdateDialog({
    super.key,
    required this.release,
    required this.currentVersion,
  });

  final AppRelease release;
  final SemanticVersion currentVersion;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String notes = _plainNotes(release.notes);
    return AlertDialog(
      key: const Key('update-dialog'),
      icon: Icon(
        Icons.system_update_alt_rounded,
        size: 30,
        color: theme.colorScheme.primary,
      ),
      title: const Text('نسخهٔ جدید در دسترس است'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'نسخهٔ تازه‌تری از برنامه منتشر شده است. '
              'برای دریافت آن، فایل نصب را دانلود کنید.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 14),
            Row(
              children: <Widget>[
                Expanded(
                  child: _VersionTile(
                    caption: 'نصب‌شده',
                    version: currentVersion.toString(),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  // A plain left arrow: in an RTL sentence the newer version
                  // sits to the left of the installed one.
                  child: Icon(
                    Icons.arrow_back_rounded,
                    textDirection: TextDirection.ltr,
                    size: 18,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                Expanded(
                  child: _VersionTile(
                    key: const Key('update-latest-version'),
                    caption: 'تازه',
                    version: release.version.toString(),
                    highlight: true,
                  ),
                ),
              ],
            ),
            if (release.assetSize != null &&
                release.assetSize! > 0) ...<Widget>[
              const SizedBox(height: 10),
              Text(
                'حجم فایل نصب: ${PersianFormat.digits((release.assetSize! / (1024 * 1024)).toStringAsFixed(1))} مگابایت',
                style: theme.textTheme.bodySmall,
              ),
            ],
            if (notes.isNotEmpty) ...<Widget>[
              const SizedBox(height: 14),
              Text('تغییرات این نسخه', style: theme.textTheme.titleSmall),
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                constraints: const BoxConstraints(maxHeight: 150),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: theme.colorScheme.outlineVariant),
                ),
                child: SingleChildScrollView(
                  child: Text(notes, style: theme.textTheme.bodySmall),
                ),
              ),
            ],
            const SizedBox(height: 14),
            Text(
              'فایل نصب از صفحهٔ انتشار GitHub در مرورگر باز می‌شود و نصب فقط با '
              'تأیید خودتان انجام می‌شود. اطلاعات فعلی برنامه حفظ می‌شود.',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          key: const Key('update-later'),
          onPressed: () => Navigator.of(context).pop(UpdateChoice.later),
          child: const Text('بعداً'),
        ),
        FilledButton.icon(
          key: const Key('update-download'),
          onPressed: () => Navigator.of(context).pop(UpdateChoice.download),
          icon: const Icon(Icons.download_rounded),
          label: const Text('دانلود'),
        ),
      ],
    );
  }

  /// Turns the Markdown release notes into a short plain-text preview.
  ///
  /// The notes are written for GitHub, so headers, bullets and links would
  /// otherwise appear as punctuation. Only the first few lines are kept: the
  /// dialog is a prompt, not a changelog reader.
  static String _plainNotes(String body) {
    if (body.trim().isEmpty) {
      return '';
    }
    final List<String> lines = <String>[];
    for (final String raw in body.split('\n')) {
      final String line =
          raw
              .replaceAllMapped(
                RegExp(r'\[([^\]]+)\]\([^)]+\)'),
                (Match match) => match.group(1) ?? '',
              )
              .replaceAll(RegExp(r'^[#>*\-–•\s]+'), '')
              .replaceAll(RegExp(r'[*_`]'), '')
              .trim();
      if (line.isEmpty) {
        continue;
      }
      lines.add(line);
      if (lines.length == 6) {
        break;
      }
    }
    String text = lines.join('\n');
    if (text.length > 420) {
      text = '${text.substring(0, 420).trimRight()}…';
    }
    return text;
  }
}

class _VersionTile extends StatelessWidget {
  const _VersionTile({
    super.key,
    required this.caption,
    required this.version,
    this.highlight = false,
  });

  final String caption;
  final String version;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color:
            highlight
                ? theme.colorScheme.primary.withValues(alpha: 0.09)
                : theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(
          color:
              highlight
                  ? theme.colorScheme.primary.withValues(alpha: 0.5)
                  : theme.colorScheme.outlineVariant,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(caption, style: theme.textTheme.bodySmall),
          const SizedBox(height: 3),
          TechnicalText(
            version,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: highlight ? theme.colorScheme.primary : null,
            ),
          ),
        ],
      ),
    );
  }
}
