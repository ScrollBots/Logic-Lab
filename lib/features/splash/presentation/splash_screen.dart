import 'package:flutter/material.dart';

import '../../../core/app_info.dart';
import '../../../core/theme/logic_lab_theme.dart';
import '../../../core/widgets/common.dart';

/// Branded splash shown while the local database and preferences are opened.
///
/// It carries the bilingual identity of the app: "Logic Lab" as the primary
/// wordmark with the Persian subtitle directly underneath.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key, this.error});

  /// When set, the splash switches into an error state with a retry action.
  final String? error;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool hasError = error != null;
    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const BrandMark(size: 76),
              const SizedBox(height: 20),
              Text(
                AppInfo.appName,
                textDirection: TextDirection.ltr,
                style: LogicLabTheme.technical(theme.textTheme.headlineMedium)
                    .copyWith(fontWeight: FontWeight.w700, letterSpacing: 0.5),
              ),
              const SizedBox(height: 2),
              Text(
                AppInfo.appSubtitle,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 28),
              if (hasError)
                InfoBanner(tone: InfoBannerTone.danger, message: error!)
              else
                SizedBox(
                  width: 120,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      minHeight: 4,
                      backgroundColor: theme.colorScheme.primary.withValues(
                        alpha: 0.12,
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 18),
              Text(
                'نسخه ${AppInfo.versionDisplay}',
                textDirection: TextDirection.ltr,
                style: theme.textTheme.labelSmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
