import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// Platform and form-factor decisions for the adaptive layer.
///
/// "Native feel" in Flutter means: Material 3 on Android / Windows / Linux,
/// Cupertino on iOS / macOS. The platform is read from the theme, so tests
/// can switch it with `ThemeData(platform: ...)` or
/// `debugDefaultTargetPlatformOverride`.

/// iOS or macOS: use Cupertino widgets.
bool isCupertino(BuildContext context) {
  final platform = Theme.of(context).platform;
  return platform == TargetPlatform.iOS || platform == TargetPlatform.macOS;
}

/// Windows, macOS or Linux: pointer and keyboard first.
bool isDesktop(BuildContext context) {
  final platform = Theme.of(context).platform;
  return platform == TargetPlatform.windows ||
      platform == TargetPlatform.macOS ||
      platform == TargetPlatform.linux;
}

/// Wide layout (>= 720 logical pixels): navigation rail and multi-column
/// track grid.
bool isWide(BuildContext context) =>
    MediaQuery.sizeOf(context).width >= TikkyTokens.wideBreakpoint;

/// Icons that differ between Material and Cupertino. Use these for common
/// actions so each platform shows its familiar glyphs.
abstract final class AdaptiveIcons {
  static IconData _pick(BuildContext c, IconData material, IconData cupertino) =>
      isCupertino(c) ? cupertino : material;

  // Navigation destinations.
  static IconData tracks(BuildContext c) =>
      _pick(c, Icons.timer_outlined, CupertinoIcons.timer);
  static IconData tracksSelected(BuildContext c) =>
      _pick(c, Icons.timer, CupertinoIcons.timer_fill);
  static IconData history(BuildContext c) =>
      _pick(c, Icons.history_outlined, CupertinoIcons.clock);
  static IconData historySelected(BuildContext c) =>
      _pick(c, Icons.history, CupertinoIcons.clock_fill);
  static IconData settings(BuildContext c) =>
      _pick(c, Icons.settings_outlined, CupertinoIcons.gear);
  static IconData settingsSelected(BuildContext c) =>
      _pick(c, Icons.settings, CupertinoIcons.gear_solid);

  // Lane actions.
  static IconData play(BuildContext c) =>
      _pick(c, Icons.play_arrow_rounded, CupertinoIcons.play_fill);
  static IconData pause(BuildContext c) =>
      _pick(c, Icons.pause_rounded, CupertinoIcons.pause_fill);
  static IconData stop(BuildContext c) =>
      _pick(c, Icons.stop_rounded, CupertinoIcons.stop_fill);
  static IconData lap(BuildContext c) =>
      _pick(c, Icons.flag_outlined, CupertinoIcons.flag);
  static IconData reset(BuildContext c) =>
      _pick(c, Icons.restart_alt_rounded, CupertinoIcons.arrow_counterclockwise);
  static IconData undo(BuildContext c) =>
      _pick(c, Icons.undo_rounded, CupertinoIcons.arrow_uturn_left);
  static IconData plusOne(BuildContext c) =>
      _pick(c, Icons.exposure_plus_1_rounded, CupertinoIcons.plus);
  static IconData check(BuildContext c) =>
      _pick(c, Icons.check_rounded, CupertinoIcons.check_mark);
  static IconData alarm(BuildContext c) =>
      _pick(c, Icons.notifications_active_outlined, CupertinoIcons.bell);
  static IconData dragHandle(BuildContext c) =>
      _pick(c, Icons.drag_indicator_rounded, CupertinoIcons.line_horizontal_3);

  // Common actions.
  static IconData add(BuildContext c) =>
      _pick(c, Icons.add_rounded, CupertinoIcons.add);
  static IconData more(BuildContext c) =>
      _pick(c, Icons.more_vert_rounded, CupertinoIcons.ellipsis_circle);
  static IconData edit(BuildContext c) =>
      _pick(c, Icons.edit_outlined, CupertinoIcons.pencil);
  static IconData delete(BuildContext c) =>
      _pick(c, Icons.delete_outline_rounded, CupertinoIcons.delete);
  static IconData close(BuildContext c) =>
      _pick(c, Icons.close_rounded, CupertinoIcons.xmark);
  static IconData share(BuildContext c) =>
      _pick(c, Icons.share_outlined, CupertinoIcons.share);
  static IconData filter(BuildContext c) => _pick(
    c,
    Icons.filter_list_rounded,
    CupertinoIcons.line_horizontal_3_decrease,
  );
  static IconData chevronRight(BuildContext c) =>
      _pick(c, Icons.chevron_right_rounded, CupertinoIcons.chevron_right);
  static IconData chevronDown(BuildContext c) =>
      _pick(c, Icons.expand_more_rounded, CupertinoIcons.chevron_down);
  static IconData copy(BuildContext c) =>
      _pick(c, Icons.copy_rounded, CupertinoIcons.doc_on_doc);
  static IconData person(BuildContext c) =>
      _pick(c, Icons.person_outline_rounded, CupertinoIcons.person);
  static IconData palette(BuildContext c) =>
      _pick(c, Icons.palette_outlined, CupertinoIcons.paintbrush);
  static IconData lock(BuildContext c) =>
      _pick(c, Icons.lock_outline_rounded, CupertinoIcons.lock);
  static IconData calendar(BuildContext c) =>
      _pick(c, Icons.calendar_today_outlined, CupertinoIcons.calendar);
  static IconData import(BuildContext c) =>
      _pick(c, Icons.file_download_outlined, CupertinoIcons.square_arrow_down);
  static IconData export(BuildContext c) =>
      _pick(c, Icons.file_upload_outlined, CupertinoIcons.square_arrow_up);
  static IconData note(BuildContext c) =>
      _pick(c, Icons.sticky_note_2_outlined, CupertinoIcons.text_bubble);
  static IconData archive(BuildContext c) =>
      _pick(c, Icons.archive_outlined, CupertinoIcons.archivebox);
}
