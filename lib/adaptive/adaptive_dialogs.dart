import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../l10n/strings.dart';
import '../theme/tokens.dart';
import 'platform.dart';

Widget _dialogAction(
  BuildContext context, {
  required String label,
  required VoidCallback onPressed,
  bool isDefault = false,
  bool destructive = false,
}) {
  if (isCupertino(context)) {
    return CupertinoDialogAction(
      onPressed: onPressed,
      isDefaultAction: isDefault,
      isDestructiveAction: destructive,
      child: Text(label),
    );
  }
  final t = context.tikky;
  return TextButton(
    onPressed: onPressed,
    style: destructive
        ? TextButton.styleFrom(foregroundColor: t.colors.danger)
        : null,
    child: Text(label),
  );
}

/// A yes / no question as the platform's native alert. Returns `true` when
/// confirmed, `false` when cancelled or dismissed.
///
/// Use sparingly: the app prefers "do it, then offer Rückgängig" (see
/// [showUndoSnackBar]) over confirmation dialogs, and protocol tracks never
/// ask for confirmation.
Future<bool> showAdaptiveConfirm(
  BuildContext context, {
  required String title,
  String? message,
  String confirmLabel = Strings.ok,
  String cancelLabel = Strings.cancel,
  bool destructive = false,
}) async {
  final result = await showAdaptiveDialog<bool>(
    context: context,
    barrierDismissible: true,
    builder: (context) => AlertDialog.adaptive(
      title: Text(title),
      content: message == null ? null : Text(message),
      actions: [
        _dialogAction(
          context,
          label: cancelLabel,
          onPressed: () => Navigator.of(context).pop(false),
        ),
        _dialogAction(
          context,
          label: confirmLabel,
          isDefault: !destructive,
          destructive: destructive,
          onPressed: () => Navigator.of(context).pop(true),
        ),
      ],
    ),
  );
  return result ?? false;
}

/// An informational native alert with a single button.
Future<void> showAdaptiveAlert(
  BuildContext context, {
  required String title,
  String? message,
  String okLabel = Strings.ok,
}) {
  return showAdaptiveDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (context) => AlertDialog.adaptive(
      title: Text(title),
      content: message == null ? null : Text(message),
      actions: [
        _dialogAction(
          context,
          label: okLabel,
          isDefault: true,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    ),
  );
}

/// One entry of [showAdaptiveActionSheet].
@immutable
class AdaptiveSheetAction<T> {
  const AdaptiveSheetAction({
    required this.value,
    required this.label,
    this.icon,
    this.destructive = false,
    this.selected = false,
  });

  final T value;
  final String label;

  /// Shown on Material; Cupertino action sheets are text only.
  final IconData? icon;
  final bool destructive;

  /// Marks the current choice (check mark / default action).
  final bool selected;
}

/// A list of choices: [CupertinoActionSheet] on iOS / macOS, a modal bottom
/// sheet with list tiles elsewhere. Returns the chosen value, or `null`
/// when dismissed.
Future<T?> showAdaptiveActionSheet<T>(
  BuildContext context, {
  required List<AdaptiveSheetAction<T>> actions,
  String? title,
  String? message,
  String cancelLabel = Strings.cancel,
}) {
  if (isCupertino(context)) {
    return showCupertinoModalPopup<T>(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: title == null ? null : Text(title),
        message: message == null ? null : Text(message),
        actions: [
          for (final a in actions)
            CupertinoActionSheetAction(
              onPressed: () => Navigator.of(context).pop(a.value),
              isDestructiveAction: a.destructive,
              isDefaultAction: a.selected,
              child: Text(a.label),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(cancelLabel),
        ),
      ),
    );
  }
  return showModalBottomSheet<T>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    builder: (context) {
      final t = context.tikky;
      return SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (title != null)
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    t.space.page,
                    0,
                    t.space.page,
                    t.space.sm,
                  ),
                  child: Text(title, style: t.text.headline),
                ),
              if (message != null)
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    t.space.page,
                    0,
                    t.space.page,
                    t.space.sm,
                  ),
                  child: Text(message, style: t.text.bodyMuted),
                ),
              for (final a in actions)
                ListTile(
                  leading: a.icon == null
                      ? null
                      : Icon(
                          a.icon,
                          color: a.destructive ? t.colors.danger : null,
                        ),
                  title: Text(
                    a.label,
                    style: a.destructive
                        ? t.text.body.copyWith(color: t.colors.danger)
                        : null,
                  ),
                  trailing: a.selected
                      ? Icon(AdaptiveIcons.check(context))
                      : null,
                  onTap: () => Navigator.of(context).pop(a.value),
                ),
              SizedBox(height: t.space.sm),
            ],
          ),
        ),
      );
    },
  );
}

/// Asks for a single line of text in a native alert. Returns the trimmed
/// text, or `null` when cancelled. With [allowEmpty] false an empty input
/// cannot be confirmed.
Future<String?> showAdaptiveTextPrompt(
  BuildContext context, {
  required String title,
  String? initialValue,
  String? hint,
  String confirmLabel = Strings.save,
  String cancelLabel = Strings.cancel,
  int? maxLength,
  bool allowEmpty = false,
}) {
  return showAdaptiveDialog<String>(
    context: context,
    barrierDismissible: true,
    builder: (context) => _TextPromptDialog(
      title: title,
      initialValue: initialValue ?? '',
      hint: hint,
      confirmLabel: confirmLabel,
      cancelLabel: cancelLabel,
      maxLength: maxLength,
      allowEmpty: allowEmpty,
    ),
  );
}

class _TextPromptDialog extends StatefulWidget {
  const _TextPromptDialog({
    required this.title,
    required this.initialValue,
    required this.confirmLabel,
    required this.cancelLabel,
    required this.allowEmpty,
    this.hint,
    this.maxLength,
  });

  final String title;
  final String initialValue;
  final String? hint;
  final String confirmLabel;
  final String cancelLabel;
  final int? maxLength;
  final bool allowEmpty;

  @override
  State<_TextPromptDialog> createState() => _TextPromptDialogState();
}

class _TextPromptDialogState extends State<_TextPromptDialog> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initialValue)
        ..selection = TextSelection(
          baseOffset: 0,
          extentOffset: widget.initialValue.length,
        );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _controller.text.trim();
    if (text.isEmpty && !widget.allowEmpty) return;
    Navigator.of(context).pop(text);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tikky;
    final Widget field = isCupertino(context)
        ? Padding(
            padding: EdgeInsets.only(top: t.space.sm),
            child: CupertinoTextField(
              controller: _controller,
              autofocus: true,
              placeholder: widget.hint,
              maxLength: widget.maxLength,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submit(),
            ),
          )
        : TextField(
            controller: _controller,
            autofocus: true,
            maxLength: widget.maxLength,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(hintText: widget.hint),
            onSubmitted: (_) => _submit(),
          );
    return AlertDialog.adaptive(
      title: Text(widget.title),
      content: isCupertino(context)
          ? Material(type: MaterialType.transparency, child: field)
          : field,
      actions: [
        _dialogAction(
          context,
          label: widget.cancelLabel,
          onPressed: () => Navigator.of(context).pop(),
        ),
        _dialogAction(
          context,
          label: widget.confirmLabel,
          isDefault: true,
          onPressed: _submit,
        ),
      ],
    );
  }
}

/// Opens a modal bottom sheet for editors and quick entry (track editor,
/// protocol entry, filters, export).
///
/// The sheet is scroll-controlled, stays inside the safe area, moves above
/// the keyboard, has a drag handle and is width-limited on wide screens.
/// [builder] returns the sheet content; wrap long content in a scroll view.
Future<T?> showAdaptiveSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  bool isDismissible = true,
  bool enableDrag = true,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    isDismissible: isDismissible,
    enableDrag: enableDrag,
    builder: (context) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(top: false, child: builder(context)),
    ),
  );
}

/// The app's replacement for confirmation dialogs: tells what happened and
/// offers "Rückgängig" for a few seconds.
///
/// With [secondaryLabel] and [onSecondary] a second action is offered next
/// to it (e.g. "Details" after a one-tap protocol entry).
void showUndoSnackBar(
  BuildContext context, {
  required String message,
  required VoidCallback onUndo,
  String undoLabel = Strings.undo,
  String? secondaryLabel,
  VoidCallback? onSecondary,
}) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  final t = context.tikky;
  final Widget content;
  if (secondaryLabel == null || onSecondary == null) {
    content = Text(message);
  } else {
    final actionColor =
        Theme.of(context).snackBarTheme.actionTextColor ?? t.colors.background;
    content = Row(
      children: [
        Expanded(child: Text(message)),
        TextButton(
          style: TextButton.styleFrom(
            foregroundColor: actionColor,
            minimumSize: Size.square(t.sizes.minTapTarget),
          ),
          onPressed: () {
            messenger.hideCurrentSnackBar();
            onSecondary();
          },
          child: Text(secondaryLabel),
        ),
      ],
    );
  }
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: content,
        duration: t.motion.undoWindow,
        // A snackbar with an action would otherwise stay until dismissed
        // and cover what is below it.
        persist: false,
        action: SnackBarAction(label: undoLabel, onPressed: onUndo),
      ),
    );
}

/// A short, self-dismissing message.
void showInfoSnackBar(BuildContext context, String message) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}
