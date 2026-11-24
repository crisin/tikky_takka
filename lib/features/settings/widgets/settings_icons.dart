import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../adaptive/adaptive.dart';

/// Icons of the settings feature that the shared `AdaptiveIcons` does not
/// cover. Material glyphs on Android / Windows, SF-style glyphs on Apple
/// platforms.
abstract final class SettingsIcons {
  static IconData _pick(
    BuildContext c,
    IconData material,
    IconData cupertino,
  ) => isCupertino(c) ? cupertino : material;

  static IconData display(BuildContext c) =>
      _pick(c, Icons.tune_rounded, CupertinoIcons.slider_horizontal_3);
  static IconData sets(BuildContext c) =>
      _pick(c, Icons.layers_outlined, CupertinoIcons.square_stack_3d_up);
  static IconData substances(BuildContext c) =>
      _pick(c, Icons.category_outlined, CupertinoIcons.square_grid_2x2);
  static IconData notifications(BuildContext c) =>
      _pick(c, Icons.notifications_outlined, CupertinoIcons.bell);
  static IconData info(BuildContext c) =>
      _pick(c, Icons.info_outline_rounded, CupertinoIcons.info);
  static IconData diagnostics(BuildContext c) =>
      _pick(c, Icons.bug_report_outlined, CupertinoIcons.ant);
  static IconData developer(BuildContext c) =>
      _pick(c, Icons.terminal_rounded, CupertinoIcons.hammer);
  static IconData refresh(BuildContext c) =>
      _pick(c, Icons.refresh_rounded, CupertinoIcons.refresh);
  static IconData alarmTest(BuildContext c) =>
      _pick(c, Icons.alarm_add_outlined, CupertinoIcons.alarm);
  static IconData copy(BuildContext c) =>
      _pick(c, Icons.copy_rounded, CupertinoIcons.doc_on_doc);
  static IconData licenses(BuildContext c) =>
      _pick(c, Icons.description_outlined, CupertinoIcons.doc_text);
  static IconData warning(BuildContext c) => _pick(
    c,
    Icons.warning_amber_rounded,
    CupertinoIcons.exclamationmark_triangle,
  );
  static IconData restore(BuildContext c) => _pick(
    c,
    Icons.settings_backup_restore_rounded,
    CupertinoIcons.arrow_uturn_left,
  );
  static IconData moveEarlier(BuildContext c) =>
      _pick(c, Icons.arrow_back_rounded, CupertinoIcons.arrow_left);
  static IconData moveLater(BuildContext c) =>
      _pick(c, Icons.arrow_forward_rounded, CupertinoIcons.arrow_right);
  static IconData expandLess(BuildContext c) =>
      _pick(c, Icons.expand_less_rounded, CupertinoIcons.chevron_up);
  static IconData brightness(BuildContext c) => _pick(
    c,
    Icons.brightness_6_outlined,
    CupertinoIcons.circle_lefthalf_fill,
  );
  static IconData font(BuildContext c) =>
      _pick(c, Icons.text_fields_rounded, CupertinoIcons.textformat);
}
