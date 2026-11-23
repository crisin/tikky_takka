import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../adaptive/adaptive.dart';
import '../../theme/theme.dart';

/// What the undo bar above the lanes offers right now.
@immutable
final class LaneUndo {
  const LaneUndo({
    required this.id,
    required this.message,
    required this.onUndo,
    this.detail,
  });

  /// Changes with every new offer, so the bar starts its time again.
  final int id;

  /// "Vögel gestoppt"
  final String message;

  /// "10 Tipps gesichert"
  final String? detail;
  final Future<void> Function() onUndo;
}

/// The one "Rückgängig" of the lanes. A new offer replaces the previous
/// one; the bar clears it when its time is up.
class LaneUndoController extends Notifier<LaneUndo?> {
  int _next = 0;

  @override
  LaneUndo? build() => null;

  void offer({
    required String message,
    required Future<void> Function() onUndo,
    String? detail,
  }) {
    state = LaneUndo(
      id: ++_next,
      message: message,
      detail: detail,
      onUndo: onUndo,
    );
  }

  /// Clears the offer [id] (a newer one stays).
  void clear(int id) {
    if (state?.id == id) state = null;
  }
}

final laneUndoProvider = NotifierProvider<LaneUndoController, LaneUndo?>(
  LaneUndoController.new,
);

/// Keys of the undo bar above the lanes.
abstract final class LaneUndoKeys {
  static const bar = ValueKey('lane-undo-bar');
}

/// The undo bar above the lanes: present while an offer runs, with a bar
/// at its lower edge that shows the time left.
class LaneUndoBar extends ConsumerWidget {
  const LaneUndoBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final undo = ref.watch(laneUndoProvider);
    if (undo == null) return const SizedBox.shrink();
    return _TimedUndoBar(key: ValueKey('lane-undo-${undo.id}'), undo: undo);
  }
}

class _TimedUndoBar extends ConsumerStatefulWidget {
  const _TimedUndoBar({required this.undo, super.key});

  final LaneUndo undo;

  @override
  ConsumerState<_TimedUndoBar> createState() => _TimedUndoBarState();
}

class _TimedUndoBarState extends ConsumerState<_TimedUndoBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _time;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    _time = AnimationController(vsync: this, value: 1)
      ..addStatusListener((status) {
        if (status == AnimationStatus.dismissed) _clear();
      });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _time.duration = context.tikky.motion.inlineUndoWindow;
    _time.reverse(from: 1);
  }

  @override
  void dispose() {
    _time.dispose();
    super.dispose();
  }

  void _clear() => ref.read(laneUndoProvider.notifier).clear(widget.undo.id);

  Future<void> _undo() async {
    _clear();
    await widget.undo.onUndo();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tikky;
    return Padding(
      padding: EdgeInsets.only(bottom: t.space.sm),
      child: AnimatedBuilder(
        animation: _time,
        builder: (context, _) => InlineUndoBar(
          key: LaneUndoKeys.bar,
          message: widget.undo.message,
          detail: widget.undo.detail,
          remaining: _time.value,
          height: t.sizes.undoBarHeight,
          onUndo: _undo,
        ),
      ),
    );
  }
}
