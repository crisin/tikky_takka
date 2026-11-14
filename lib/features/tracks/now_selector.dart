import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/now_ticker.dart';

/// Follows the shared "now" ticker but only rebuilds when the value picked
/// by [selector] actually changes.
///
/// A lane uses two of these: one for the time text (digits, progress,
/// sub-line) and one for the controls (buttons, ringing frame). Without
/// tenths the digits therefore rebuild once per second although the ticker
/// fires ten times, and the buttons only when the state changes.
///
/// [T] needs value equality. With [enabled] false the widget does not
/// subscribe at all (idle and paused lanes cost nothing).
class NowSelector<T> extends ConsumerStatefulWidget {
  const NowSelector({
    required this.selector,
    required this.builder,
    this.enabled = true,
    super.key,
  });

  final T Function(int nowMs) selector;
  final Widget Function(BuildContext context, T value) builder;
  final bool enabled;

  @override
  ConsumerState<NowSelector<T>> createState() => _NowSelectorState<T>();
}

class _NowSelectorState<T> extends ConsumerState<NowSelector<T>> {
  NowTicker? _subscribedTo;
  late T _value;

  void _onTick() {
    final ticker = _subscribedTo;
    if (ticker == null || !mounted) return;
    final next = widget.selector(ticker.value);
    if (next != _value) {
      setState(() => _value = next);
    }
  }

  void _subscribe(NowTicker? ticker) {
    if (identical(ticker, _subscribedTo)) return;
    _subscribedTo?.removeListener(_onTick);
    _subscribedTo = ticker;
    ticker?.addListener(_onTick);
  }

  @override
  void dispose() {
    _subscribedTo?.removeListener(_onTick);
    _subscribedTo = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ticker = ref.watch(nowTickerProvider);
    _subscribe(widget.enabled ? ticker : null);
    // Always recompute: the selector closure may have changed with the
    // parent (new events, new preferences).
    _value = widget.selector(ticker.value);
    return widget.builder(context, _value);
  }
}
