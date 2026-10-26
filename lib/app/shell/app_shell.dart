import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../features/home/presentation/home_screen.dart';
import '../../features/lab/presentation/lab_screen.dart';
import '../../features/learn/presentation/learn_screen.dart';
import '../../features/projects/presentation/projects_screen.dart';
import '../../features/settings/application/settings_controller.dart';
import '../../features/settings/presentation/settings_screen.dart';
import 'app_header.dart';
import 'app_navigation.dart';

/// Application shell with the floating capsule navigation.
///
/// The transition between sections is a coordinated "morph": the accent rail
/// at the top of the page slides to the selected section while the page content
/// fades and settles with a small scale, and the capsule highlight glides to
/// the new item. All pages stay alive inside an [IndexedStack], so scroll
/// positions and expensive widgets (such as the circuit canvas) are never
/// rebuilt or lost.
///
/// The mapping between a destination, its index, its icon and the active
/// indicator lives in [AppDestination]. The highlight is positioned with the
/// logical `start` offset, which keeps it aligned with the item in both RTL
/// and LTR without reversing the destination order.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell>
    with SingleTickerProviderStateMixin {
  static const Duration _transitionDuration = Duration(milliseconds: 320);

  AppDestination _destination = AppDestination.home;
  late final AnimationController _transition;

  @override
  void initState() {
    super.initState();
    _transition = AnimationController(
      vsync: this,
      duration: _transitionDuration,
      value: 1,
    );
  }

  @override
  void dispose() {
    _transition.dispose();
    super.dispose();
  }

  void _select(int index) {
    final AppDestination destination = AppNavigation.at(index);
    if (destination == _destination) {
      return;
    }
    setState(() => _destination = destination);
    // Restarting from zero keeps the motion deterministic when the user taps
    // several destinations in a row: no stale animation can win the race.
    _transition.forward(from: 0);
  }

  void _selectDestination(AppDestination destination) {
    _select(destination.navIndex);
  }

  @override
  Widget build(BuildContext context) {
    final SettingsController settings = context.watch<SettingsController>();
    final bool animate = settings.animationsEnabled;
    final Duration duration = animate ? _transitionDuration : Duration.zero;

    return Scaffold(
      body: Stack(
        key: const Key('app-shell-body'),
        children: <Widget>[
          // The fixed header stays on top during the page morph; it is never
          // scaled or translated, so there is no duplicate header and no
          // flicker between sections.
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: AppHeader(
              onSettings: () {
                AppHaptics.selection(settings.hapticsEnabled);
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (BuildContext context) => const SettingsScreen(),
                  ),
                );
              },
            ),
          ),
          // Pages morph underneath the header.
          Positioned(
            top: kAppHeaderHeight,
            left: 0,
            right: 0,
            bottom: 0,
            child: AnimatedBuilder(
              animation: _transition,
              builder: (BuildContext context, Widget? child) {
                final double t = Curves.easeOutCubic.transform(
                  _transition.value,
                );
                final double opacity = (0.72 + 0.28 * t).clamp(0.0, 1.0);
                final double scale = (0.985 + 0.015 * t).clamp(0.0, 1.0);
                final double offset = 14 * (1 - t);
                return Transform.translate(
                  offset: Offset(0, offset),
                  child: Transform.scale(
                    scale: scale,
                    child: Opacity(opacity: opacity, child: child),
                  ),
                );
              },
              child: IndexedStack(
                index: _destination.navIndex,
                children: <Widget>[
                  HomeScreen(
                    onOpenProjects:
                        () => _selectDestination(AppDestination.circuits),
                    onOpenLearn:
                        () => _selectDestination(AppDestination.learning),
                  ),
                  ProjectsScreen(
                    onOpenProjectsTab:
                        () => _selectDestination(AppDestination.circuits),
                  ),
                  const LabScreen(),
                  const LearnScreen(),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _CapsuleNavigationBar(
        destination: _destination,
        motionDuration: duration,
        onSelected: _select,
      ),
    );
  }
}

class _CapsuleNavigationBar extends StatelessWidget {
  const _CapsuleNavigationBar({
    required this.destination,
    required this.onSelected,
    required this.motionDuration,
  });

  final AppDestination destination;
  final ValueChanged<int> onSelected;
  final Duration motionDuration;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final SettingsController settings = context.watch<SettingsController>();
    final double width = MediaQuery.sizeOf(context).width;
    final List<AppDestination> destinations = AppNavigation.destinations;

    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(14, 0, 14, 12),
      child: Align(
        alignment: Alignment.bottomCenter,
        // Keeps the bar compact so it never expands into the page area.
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Container(
            key: const Key('app-nav-capsule'),
            height: 64,
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(31),
              border: Border.all(color: theme.colorScheme.outlineVariant),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color:
                      theme.brightness == Brightness.dark
                          ? Colors.black.withValues(alpha: 0.4)
                          : const Color(0xFF1B2A44).withValues(alpha: 0.1),
                  blurRadius: 22,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                // The segment width must match the width the [Row] gives to
                // every [Expanded] item, otherwise the highlight drifts away
                // from the item it belongs to.
                final double segment =
                    constraints.maxWidth / destinations.length;
                return Stack(
                  children: <Widget>[
                    // The morphing highlight glides behind the active item.
                    // It uses the logical `start` offset so it always sits
                    // under the item that belongs to the selected
                    // destination, in RTL as well as in LTR.
                    AnimatedPositionedDirectional(
                      key: AppDestination.highlightKey,
                      duration: motionDuration,
                      curve: Curves.easeOutCubic,
                      start: segment * destination.navIndex,
                      top: 0,
                      bottom: 0,
                      width: segment,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withValues(
                              alpha: 0.12,
                            ),
                            borderRadius: BorderRadius.circular(26),
                          ),
                        ),
                      ),
                    ),
                    // The sliding accent indicator belongs to the capsule
                    // navigation itself. It used to be painted as a strip
                    // across the top of the page, which looked like a stray
                    // header above the page title and detached from the
                    // content while the page was morphing.
                    AnimatedPositionedDirectional(
                      key: AppDestination.accentKey,
                      duration: motionDuration,
                      curve: Curves.easeOutCubic,
                      start: segment * destination.navIndex,
                      bottom: 7,
                      width: segment,
                      child: Center(
                        child: Container(
                          width: 18,
                          height: 3,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                    ),
                    Row(
                      children: <Widget>[
                        for (final AppDestination item in destinations)
                          Expanded(
                            child: _CapsuleItem(
                              destination: item,
                              selected: item == destination,
                              compact: width < 360,
                              motionDuration: motionDuration,
                              onTap: () {
                                AppHaptics.selection(settings.hapticsEnabled);
                                onSelected(item.navIndex);
                              },
                            ),
                          ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _CapsuleItem extends StatelessWidget {
  const _CapsuleItem({
    required this.destination,
    required this.selected,
    required this.onTap,
    required this.compact,
    required this.motionDuration,
  });

  final AppDestination destination;
  final bool selected;
  final VoidCallback onTap;
  final bool compact;
  final Duration motionDuration;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color activeColor = theme.colorScheme.primary;
    return Semantics(
      key: destination.itemKey,
      button: true,
      selected: selected,
      label: destination.label,
      child: ExcludeSemantics(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(26),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                AnimatedSwitcher(
                  duration: motionDuration,
                  transitionBuilder: (
                    Widget child,
                    Animation<double> animation,
                  ) {
                    return ScaleTransition(
                      scale: CurvedAnimation(
                        parent: animation,
                        curve: Curves.easeOutBack,
                      ),
                      child: FadeTransition(opacity: animation, child: child),
                    );
                  },
                  child: Icon(
                    selected ? destination.activeIcon : destination.icon,
                    key: ValueKey<bool>(selected),
                    size: 20,
                    color:
                        selected
                            ? activeColor
                            : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 1),
                AnimatedDefaultTextStyle(
                  duration: motionDuration,
                  curve: Curves.easeOutCubic,
                  style: theme.textTheme.labelSmall!.copyWith(
                    fontSize: compact ? 9.5 : 10.5,
                    height: 1.25,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color:
                        selected
                            ? activeColor
                            : theme.colorScheme.onSurfaceVariant,
                  ),
                  child: Text(
                    destination.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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
