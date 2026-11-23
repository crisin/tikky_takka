import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../adaptive/adaptive.dart';
import '../../theme/theme.dart';
import 'settings_strings.dart';
import 'widgets/setting_rows.dart';
import 'widgets/theme_preview.dart';
import 'widgets/ui_pref_field.dart';

/// The preference fields that change how lanes look. Also the fields a set
/// may override (plus [UiPrefsKeys.keepScreenOn]).
const List<String> laneAppearanceKeys = [
  UiPrefsKeys.layout,
  UiPrefsKeys.density,
  UiPrefsKeys.showTenths,
  UiPrefsKeys.showProgressBar,
  UiPrefsKeys.showSubLine,
  UiPrefsKeys.showEntryCounts,
  UiPrefsKeys.leftHanded,
];

/// The preference fields that scale lane elements.
const List<String> laneSizeKeys = [
  UiPrefsKeys.digitScale,
  UiPrefsKeys.buttonScale,
];

/// "Anzeige der Spuren": the app-wide lane preferences with a live preview.
/// Every change is saved and applied at once.
class DisplaySettingsScreen extends ConsumerWidget {
  const DisplaySettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(uiPrefsProvider);
    final theme = ref.watch(appThemeProvider);
    final notifier = ref.read(uiPrefsProvider.notifier);

    Widget field(String key) => UiPrefField(
      key: ValueKey('pref.$key'),
      fieldKey: key,
      prefs: prefs,
      onChanged: notifier.set,
    );

    return AdaptivePageScaffold(
      title: const Text(SettingsStrings.displaySettings),
      body: PreviewLayout(
        theme: theme,
        prefs: prefs,
        child: SettingsBody(
          children: [
            AdaptiveSection(
              header: SettingsStrings.sectionLanes,
              children: [for (final key in laneAppearanceKeys) field(key)],
            ),
            AdaptiveSection(
              header: SettingsStrings.sectionSizes,
              children: [for (final key in laneSizeKeys) field(key)],
            ),
          ],
        ),
      ),
    );
  }
}
