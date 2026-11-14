import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/repo/providers.dart';
import 'theme_controllers.dart';

/// Applies the theme and UI preference overrides of a set to [child].
///
/// The tracks screen wraps its whole content in this, so `context.tikky`
/// below it already reflects the active set's overrides. With [setId] null
/// the active set is used.
class SetThemeScope extends ConsumerWidget {
  const SetThemeScope({required this.child, this.setId, super.key});

  final Widget child;

  /// The set whose overrides apply; `null` = the active set.
  final String? setId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = setId ?? ref.watch(activeSetProvider)?.id;
    return Theme(data: ref.watch(themeDataForSetProvider(id)), child: child);
  }
}
