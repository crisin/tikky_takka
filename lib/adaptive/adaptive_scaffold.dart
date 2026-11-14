import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import 'platform.dart';

/// One top-level destination of the app.
@immutable
class AdaptiveDestination {
  const AdaptiveDestination({
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

/// The app's top-level navigation:
///
/// * phone, Material: [NavigationBar] at the bottom;
/// * phone, Cupertino: [CupertinoTabBar] at the bottom;
/// * wide (>= 720 px), any platform: [NavigationRail] at the leading edge.
///
/// [body] is the page for [selectedIndex] (the shell keeps pages alive with
/// an `IndexedStack`). Pages bring their own [AdaptivePageScaffold].
class AdaptiveNavScaffold extends StatelessWidget {
  const AdaptiveNavScaffold({
    required this.destinations,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.body,
    super.key,
  });

  final List<AdaptiveDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final Widget body;

  @override
  Widget build(BuildContext context) {
    final t = context.tikky;
    if (isWide(context)) {
      return Scaffold(
        body: Row(
          children: [
            SafeArea(
              right: false,
              child: NavigationRail(
                selectedIndex: selectedIndex,
                onDestinationSelected: onDestinationSelected,
                labelType: NavigationRailLabelType.all,
                destinations: [
                  for (final d in destinations)
                    NavigationRailDestination(
                      icon: Icon(d.icon),
                      selectedIcon: Icon(d.selectedIcon),
                      label: Text(d.label),
                    ),
                ],
              ),
            ),
            VerticalDivider(
              width: t.sizes.hairline,
              thickness: t.sizes.hairline,
              color: t.colors.border,
            ),
            Expanded(child: body),
          ],
        ),
      );
    }

    final Widget bar;
    if (isCupertino(context)) {
      bar = CupertinoTabBar(
        currentIndex: selectedIndex,
        onTap: onDestinationSelected,
        backgroundColor: t.colors.surface,
        activeColor: t.colors.text,
        inactiveColor: t.colors.textMuted,
        border: Border(top: t.hairline),
        items: [
          for (final d in destinations)
            BottomNavigationBarItem(
              icon: Icon(d.icon),
              activeIcon: Icon(d.selectedIcon),
              label: d.label,
            ),
        ],
      );
    } else {
      bar = DecoratedBox(
        decoration: BoxDecoration(border: Border(top: t.hairline)),
        child: NavigationBar(
          selectedIndex: selectedIndex,
          onDestinationSelected: onDestinationSelected,
          destinations: [
            for (final d in destinations)
              NavigationDestination(
                icon: Icon(d.icon),
                selectedIcon: Icon(d.selectedIcon),
                label: d.label,
                tooltip: d.label,
              ),
          ],
        ),
      );
    }
    return Scaffold(body: body, bottomNavigationBar: bar);
  }
}

/// App bar that is an [AppBar] on Material platforms and a
/// [CupertinoNavigationBar] on iOS / macOS.
///
/// [title] may be any widget (e.g. the set switcher button). [actions] are
/// typically `AdaptiveIconButton`s.
class AdaptiveAppBar extends StatelessWidget implements PreferredSizeWidget {
  const AdaptiveAppBar({
    this.title,
    this.leading,
    this.actions = const [],
    this.automaticallyImplyLeading = true,
    super.key,
  });

  final Widget? title;
  final Widget? leading;
  final List<Widget> actions;
  final bool automaticallyImplyLeading;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final t = context.tikky;
    if (isCupertino(context)) {
      return CupertinoNavigationBar(
        // Several bars live side by side in the shell's IndexedStack; hero
        // transitions between them would clash.
        transitionBetweenRoutes: false,
        automaticallyImplyLeading: automaticallyImplyLeading,
        automaticBackgroundVisibility: false,
        backgroundColor: t.colors.background,
        border: Border(bottom: t.hairline),
        leading: leading,
        middle: title == null
            ? null
            : DefaultTextStyle.merge(style: t.text.headline, child: title!),
        trailing: actions.isEmpty
            ? null
            : Row(mainAxisSize: MainAxisSize.min, children: actions),
      );
    }
    return AppBar(
      title: title,
      leading: leading,
      actions: actions.isEmpty
          ? null
          : [...actions, SizedBox(width: t.space.xs)],
      automaticallyImplyLeading: automaticallyImplyLeading,
    );
  }
}

/// A page with an [AdaptiveAppBar]. The body is kept inside the safe area
/// (the top is handled by the bar).
class AdaptivePageScaffold extends StatelessWidget {
  const AdaptivePageScaffold({
    required this.body,
    this.title,
    this.leading,
    this.actions = const [],
    this.floatingActionButton,
    this.automaticallyImplyLeading = true,
    this.resizeToAvoidBottomInset = true,
    super.key,
  });

  final Widget body;
  final Widget? title;
  final Widget? leading;
  final List<Widget> actions;
  final Widget? floatingActionButton;
  final bool automaticallyImplyLeading;
  final bool resizeToAvoidBottomInset;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
      appBar: AdaptiveAppBar(
        title: title,
        leading: leading,
        actions: actions,
        automaticallyImplyLeading: automaticallyImplyLeading,
      ),
      floatingActionButton: floatingActionButton,
      body: SafeArea(top: false, child: body),
    );
  }
}

/// A friendly empty state: icon, title, optional text and action.
class AdaptiveEmptyState extends StatelessWidget {
  const AdaptiveEmptyState({
    required this.icon,
    required this.title,
    this.message,
    this.action,
    super.key,
  });

  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final t = context.tikky;
    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.all(t.space.xl),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: t.sizes.sheetMaxWidth),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: t.sizes.iconXl, color: t.colors.textMuted),
              SizedBox(height: t.space.lg),
              Text(
                title,
                style: t.text.headline,
                textAlign: TextAlign.center,
              ),
              if (message != null) ...[
                SizedBox(height: t.space.sm),
                Text(
                  message!,
                  style: t.text.bodyMuted,
                  textAlign: TextAlign.center,
                ),
              ],
              if (action != null) ...[SizedBox(height: t.space.xl), action!],
            ],
          ),
        ),
      ),
    );
  }
}
