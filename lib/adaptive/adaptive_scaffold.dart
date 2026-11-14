import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import 'adaptive_controls.dart';
import 'platform.dart';

//// One top-level destination of the app.
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

/// A button next to the navigation: the round "+" beside the pill, or an
/// entry below the destinations of the rail ("Einstellungen").
@immutable
class AdaptiveNavAction {
  const AdaptiveNavAction({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.key,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final Key? key;
}

/// The app's navigation ("Pult"):
///
/// * phone: the [NavPill] at the bottom - one word per destination, the
///   selected one inverted - and the round [action] beside it, both within
///   thumb reach;
/// * wide (>= 720 px): a [NavigationRail] at the leading edge with the
///   [action] above the destinations and [railActions] below them.
///
/// The look is the same on every platform. [body] is the page for
/// [selectedIndex].
class AdaptiveNavScaffold extends StatelessWidget {
  const AdaptiveNavScaffold({
    required this.destinations,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.body,
    this.action,
    this.railActions = const [],
    super.key,
  });

  final List<AdaptiveDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final Widget body;
  final AdaptiveNavAction? action;

  /// Further entries of the rail (wide layouts only).
  final List<AdaptiveNavAction> railActions;

  @override
  Widget build(BuildContext context) {
    final t = context.tikky;
    final action = this.action;
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
                leading: action == null
                    ? null
                    : Padding(
                        padding: EdgeInsets.only(bottom: t.space.sm),
                        child: NavRoundButton(action: action),
                      ),
                trailing: railActions.isEmpty
                    ? null
                    : Expanded(
                        child: Align(
                          alignment: Alignment.bottomCenter,
                          child: Padding(
                            padding: EdgeInsets.only(bottom: t.space.lg),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                for (final a in railActions)
                                  AdaptiveIconButton(
                                    key: a.key,
                                    icon: a.icon,
                                    semanticLabel: a.label,
                                    onPressed: a.onPressed,
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
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

    final bar = SafeArea(
      top: false,
      minimum: EdgeInsets.only(bottom: t.space.lg),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          t.space.pageLanes,
          t.space.sm,
          t.space.pageLanes,
          t.space.sm,
        ),
        child: Row(
          children: [
            Expanded(
              child: NavPill(
                labels: [for (final d in destinations) d.label],
                selectedIndex: selectedIndex,
                onSelected: onDestinationSelected,
              ),
            ),
            if (action != null) ...[
              SizedBox(width: t.space.sm),
              NavRoundButton(action: action),
            ],
          ],
        ),
      ),
    );
    return Scaffold(body: body, bottomNavigationBar: bar);
  }
}

/// The pill at the bottom of a phone: one word per entry, the selected one
/// inverted. Every entry is at least a tap target high.
class NavPill extends StatelessWidget {
  const NavPill({
    required this.labels,
    required this.selectedIndex,
    required this.onSelected,
    super.key,
  });

  /// Key of the entry [index] (for tests).
  static Key entryKey(int index) => ValueKey('nav-pill-$index');

  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final t = context.tikky;
    return Semantics(
      container: true,
      child: Container(
        height: t.sizes.navPill,
        // Thin, so every entry stays a full tap target.
        padding: EdgeInsets.all(t.space.xxs),
        decoration: BoxDecoration(
          color: t.colors.surface,
          borderRadius: t.radii.pillAll,
          border: t.sizes.hairline > 0
              ? Border.all(color: t.colors.border, width: t.sizes.hairline)
              : null,
        ),
        child: Row(
          children: [
            for (var i = 0; i < labels.length; i++)
              Expanded(
                child: _PillEntry(
                  key: entryKey(i),
                  label: labels[i],
                  selected: i == selectedIndex,
                  onTap: () => onSelected(i),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PillEntry extends StatelessWidget {
  const _PillEntry({
    required this.label,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tikky;
    return Semantics(
      button: true,
      selected: selected,
      inMutuallyExclusiveGroup: true,
      child: Material(
        color: selected ? t.colors.primary : Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: t.radii.pillAll),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          splashFactory: isCupertino(context) ? NoSplash.splashFactory : null,
          onTap: onTap,
          child: Center(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: t.space.xs),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  maxLines: 1,
                  style: t.text.navLabel.copyWith(
                    color: selected ? t.colors.onPrimary : t.colors.text,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The round, inverted button beside the pill ("Neue Spur").
class NavRoundButton extends StatelessWidget {
  const NavRoundButton({required this.action, super.key});

  final AdaptiveNavAction action;

  @override
  Widget build(BuildContext context) {
    final t = context.tikky;
    return Semantics(
      button: true,
      label: action.label,
      excludeSemantics: true,
      onTap: action.onPressed,
      child: Tooltip(
        message: action.label,
        excludeFromSemantics: true,
        child: Material(
          key: action.key,
          color: t.colors.primary,
          shape: RoundedRectangleBorder(borderRadius: t.radii.pillAll),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            splashFactory: isCupertino(context) ? NoSplash.splashFactory : null,
            onTap: action.onPressed,
            child: SizedBox.square(
              dimension: t.sizes.navPill,
              child: Icon(
                action.icon,
                size: t.sizes.iconLg,
                color: t.colors.onPrimary,
              ),
            ),
          ),
        ),
      ),
    );
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
///
/// With [largeTitle] a top-level page gets the large title of the iOS
/// system apps on iOS / macOS: big under the bar, shrinking into it while
/// the body scrolls (the body's vertical list must use the primary scroll
/// controller, i.e. no controller of its own). Other platforms keep the
/// regular bar.
///
/// [belowTitle] (filters, a segmented switch) sits above the body. With the
/// large title it scrolls away together with the title, like the search
/// field of the iOS system apps; content would otherwise end up under the
/// collapsed bar.
class AdaptivePageScaffold extends StatelessWidget {
  const AdaptivePageScaffold({
    required this.body,
    this.title,
    this.leading,
    this.actions = const [],
    this.floatingActionButton,
    this.automaticallyImplyLeading = true,
    this.resizeToAvoidBottomInset = true,
    this.largeTitle = false,
    this.belowTitle,
    super.key,
  });

  final Widget body;
  final Widget? title;
  final Widget? leading;
  final List<Widget> actions;
  final Widget? floatingActionButton;
  final bool automaticallyImplyLeading;
  final bool resizeToAvoidBottomInset;
  final bool largeTitle;
  final Widget? belowTitle;

  /// The large-title bar (for tests).
  static const largeTitleKey = ValueKey('adaptive-large-title');

  @override
  Widget build(BuildContext context) {
    final title = this.title;
    if (largeTitle && title != null && isCupertino(context)) {
      final t = context.tikky;
      return Scaffold(
        resizeToAvoidBottomInset: resizeToAvoidBottomInset,
        floatingActionButton: floatingActionButton,
        body: NestedScrollView(
          headerSliverBuilder: (context, _) => [
            CupertinoSliverNavigationBar(
              key: AdaptivePageScaffold.largeTitleKey,
              // Several bars live side by side in the shell's IndexedStack;
              // hero transitions between them would clash.
              transitionBetweenRoutes: false,
              automaticallyImplyLeading: automaticallyImplyLeading,
              // Like the system apps: bar background and hairline only once
              // the content scrolls under the bar.
              automaticBackgroundVisibility: true,
              stretch: true,
              backgroundColor: t.colors.background,
              border: Border(bottom: t.hairline),
              leading: leading,
              largeTitle: DefaultTextStyle.merge(
                style: TextStyle(color: t.colors.text),
                child: title,
              ),
              trailing: actions.isEmpty
                  ? null
                  : Row(mainAxisSize: MainAxisSize.min, children: actions),
            ),
            if (belowTitle case final below?) SliverToBoxAdapter(child: below),
          ],
          body: SafeArea(top: false, child: body),
        ),
      );
    }
    return Scaffold(
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
      appBar: AdaptiveAppBar(
        title: title,
        leading: leading,
        actions: actions,
        automaticallyImplyLeading: automaticallyImplyLeading,
      ),
      floatingActionButton: floatingActionButton,
      body: SafeArea(
        top: false,
        child: belowTitle == null
            ? body
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  belowTitle!,
                  Expanded(child: body),
                ],
              ),
      ),
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
              Text(title, style: t.text.headline, textAlign: TextAlign.center),
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
