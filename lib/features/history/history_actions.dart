import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../adaptive/adaptive.dart';
import '../../core/core.dart';
import '../../l10n/strings.dart';
import 'history_strings.dart';

/// What the history screen shows below the filter bar.
enum HistoryView { sessions, daily, weekly }

/// The selected history view. Kept while the app runs.
class HistoryViewController extends Notifier<HistoryView> {
  @override
  HistoryView build() => HistoryView.sessions;

  void show(HistoryView view) => state = view;
}

final historyViewProvider =
    NotifierProvider<HistoryViewController, HistoryView>(
      HistoryViewController.new,
    );

/// Edits to history data, shared by the list and the detail page. Following
/// the app's rule there are no confirmation dialogs: things happen at once
/// and a "Rückgängig" snackbar offers the way back.
abstract final class HistoryActions {
  /// Deletes a session with its events and offers undo. Returns `true` when
  /// something was deleted.
  ///
  /// [messengerContext] must stay mounted after the deletion (pass the
  /// context of the page that remains visible).
  static Future<bool> deleteSession(
    BuildContext messengerContext,
    WidgetRef ref,
    String sessionId,
  ) async {
    final repo = ref.read(historyRepositoryProvider);
    unawaited(ref.read(hapticsProvider).heavy());
    final deleted = await repo.deleteSession(sessionId);
    if (deleted == null) return false;
    if (messengerContext.mounted) {
      showUndoSnackBar(
        messengerContext,
        message: Strings.sessionDeleted,
        onUndo: () => unawaited(repo.restoreSession(deleted)),
      );
    }
    return true;
  }

  /// Asks for the note of a session and saves it (an empty text clears
  /// it). Returns `true` when the note was saved.
  static Future<bool> editSessionNote(
    BuildContext context,
    WidgetRef ref,
    Session session,
  ) async {
    final repo = ref.read(historyRepositoryProvider);
    final text = await showAdaptiveTextPrompt(
      context,
      title: Strings.editNote,
      initialValue: session.note,
      hint: Strings.note,
      allowEmpty: true,
    );
    if (text == null) return false;
    await repo.updateSessionNote(session.id, text);
    return true;
  }

  /// Deletes a single event (never start / stop) and offers undo.
  static Future<bool> deleteEvent(
    BuildContext context,
    WidgetRef ref,
    TrackEvent event,
  ) async {
    final repo = ref.read(historyRepositoryProvider);
    unawaited(ref.read(hapticsProvider).heavy());
    final deleted = await repo.deleteEvent(event.id);
    if (deleted == null) return false;
    if (context.mounted) {
      showUndoSnackBar(
        context,
        message: Strings.eventDeleted,
        onUndo: () => unawaited(repo.restoreEvent(deleted)),
      );
    }
    return true;
  }

  /// Asks for the note of a single event and saves it.
  static Future<bool> editEventNote(
    BuildContext context,
    WidgetRef ref,
    TrackEvent event,
  ) async {
    final repo = ref.read(historyRepositoryProvider);
    final text = await showAdaptiveTextPrompt(
      context,
      title: HistoryStrings.eventNote,
      initialValue: event.note,
      hint: Strings.note,
      allowEmpty: true,
    );
    if (text == null) return false;
    return repo.updateEvent(
      event.copyWith(note: () => text.isEmpty ? null : text),
    );
  }

  /// Whether [event] can be deleted or annotated on its own. Start and
  /// stop define the session and are fixed.
  static bool isEditable(TrackEvent event) =>
      event.type != EventType.start && event.type != EventType.stop;
}
