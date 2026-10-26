import 'package:flutter/material.dart';

/// The four top level destinations of the application.
///
/// The enum order *is* the canonical logical order and the index of a
/// destination is the single source of truth for every mapping in the app:
/// the visible capsule, the accent rail, the page stack and the accessibility
/// state all use [AppDestination.index].
///
/// Settings is no longer a navigation destination: it is opened from the
/// Settings button in the header, so the bottom bar always shows exactly the
/// four working sections of the app.
///
/// The order is intentionally **not** reversed for RTL: the navigation bar is a
/// [Row] inside an RTL container, so the logical first item (خانه) is already
/// rendered at the right hand side. All positioning therefore uses the logical
/// `start` offset instead of a physical `left` offset.
enum AppDestination {
  home('خانه', Icons.home_outlined, Icons.home_rounded),
  circuits('مدارها', Icons.account_tree_outlined, Icons.account_tree_rounded),
  laboratory('آزمایشگاه', Icons.science_outlined, Icons.science_rounded),
  learning('آموزش', Icons.school_outlined, Icons.school_rounded);

  const AppDestination(this.label, this.icon, this.activeIcon);

  /// Persian label shown under the icon.
  final String label;

  final IconData icon;
  final IconData activeIcon;

  /// Canonical logical index of this destination.
  int get navIndex => AppDestination.values.indexOf(this);

  /// Key of the navigation item, used by the regression tests.
  Key get itemKey => Key('app-nav-item-$name');

  /// Key of the moving highlight that marks the active destination.
  static const Key highlightKey = Key('app-nav-highlight');

  /// Key of the sliding accent indicator of the capsule navigation.
  static const Key accentKey = Key('app-nav-accent');
}

/// Canonical description of the navigation bar.
class AppNavigation {
  const AppNavigation._();

  static List<AppDestination> get destinations => AppDestination.values;

  static AppDestination at(int index) => AppDestination.values[index];

  /// Resolves a destination to its canonical index.
  static int indexOf(AppDestination destination) => destination.navIndex;
}
