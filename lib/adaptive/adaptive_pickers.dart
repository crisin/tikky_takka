import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../l10n/strings.dart';
import '../theme/tokens.dart';
import 'platform.dart';

/// Shows a Cupertino picker in a bottom popup with "Abbrechen" / "Fertig".
Future<T?> _showCupertinoPickerPopup<T>(
  BuildContext context, {
  required Widget Function(BuildContext context) pickerBuilder,
  required T Function() currentValue,
  String? title,
  double height = 216,
}) {
  return showCupertinoModalPopup<T>(
    context: context,
    builder: (context) {
      final t = context.tikky;
      return Container(
        decoration: BoxDecoration(
          color: t.colors.surface,
          border: Border(top: t.hairline),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  CupertinoButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(
                      Strings.cancel,
                      style: t.text.body.copyWith(color: t.colors.textMuted),
                    ),
                  ),
                  Expanded(
                    child: title == null
                        ? const SizedBox.shrink()
                        : Text(
                            title,
                            style: t.text.label,
                            textAlign: TextAlign.center,
                            overflow: TextOverflow.ellipsis,
                          ),
                  ),
                  CupertinoButton(
                    onPressed: () => Navigator.of(context).pop(currentValue()),
                    child: Text(Strings.done, style: t.text.button),
                  ),
                ],
              ),
              SizedBox(height: height, child: pickerBuilder(context)),
            ],
          ),
        ),
      );
    },
  );
}

/// Picks a duration: [CupertinoTimerPicker] on iOS / macOS, a Material
/// dialog with hour / minute / second wheels elsewhere. Returns `null` when
/// cancelled.
///
/// With [showSeconds] false only hours and minutes are offered.
Future<Duration?> showAdaptiveDurationPicker(
  BuildContext context, {
  required Duration initial,
  String title = Strings.pickDuration,
  bool showSeconds = true,
}) {
  final start = initial.isNegative ? Duration.zero : initial;
  if (isCupertino(context)) {
    // The Cupertino timer picker is limited to 23:59:59.
    const max = Duration(hours: 23, minutes: 59, seconds: 59);
    var value = start > max ? max : start;
    return _showCupertinoPickerPopup<Duration>(
      context,
      title: title,
      currentValue: () => value,
      pickerBuilder: (context) => CupertinoTimerPicker(
        mode: showSeconds
            ? CupertinoTimerPickerMode.hms
            : CupertinoTimerPickerMode.hm,
        initialTimerDuration: value,
        onTimerDurationChanged: (d) => value = d,
      ),
    );
  }
  return showDialog<Duration>(
    context: context,
    builder: (context) => _DurationWheelDialog(
      initial: start,
      title: title,
      showSeconds: showSeconds,
    ),
  );
}

class _DurationWheelDialog extends StatefulWidget {
  const _DurationWheelDialog({
    required this.initial,
    required this.title,
    required this.showSeconds,
  });

  final Duration initial;
  final String title;
  final bool showSeconds;

  @override
  State<_DurationWheelDialog> createState() => _DurationWheelDialogState();
}

class _DurationWheelDialogState extends State<_DurationWheelDialog> {
  static const int _maxHours = 99;

  late int _hours = widget.initial.inHours.clamp(0, _maxHours);
  late int _minutes = widget.initial.inMinutes % 60;
  late int _seconds = widget.showSeconds ? widget.initial.inSeconds % 60 : 0;

  late final _hourController = FixedExtentScrollController(initialItem: _hours);
  late final _minuteController = FixedExtentScrollController(
    initialItem: _minutes,
  );
  late final _secondController = FixedExtentScrollController(
    initialItem: _seconds,
  );

  @override
  void dispose() {
    _hourController.dispose();
    _minuteController.dispose();
    _secondController.dispose();
    super.dispose();
  }

  Duration get _value =>
      Duration(hours: _hours, minutes: _minutes, seconds: _seconds);

  Widget _wheel({
    required FixedExtentScrollController controller,
    required int count,
    required String unit,
    required String semanticLabel,
    required ValueChanged<int> onChanged,
  }) {
    final t = context.tikky;
    final extent = t.sizes.minTapTarget;
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: extent * 3,
            child: Semantics(
              label: semanticLabel,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    height: extent,
                    decoration: BoxDecoration(
                      color: t.colors.surfaceAlt,
                      borderRadius: t.radii.smAll,
                    ),
                  ),
                  ListWheelScrollView.useDelegate(
                    controller: controller,
                    itemExtent: extent,
                    physics: const FixedExtentScrollPhysics(),
                    overAndUnderCenterOpacity: 0.35,
                    onSelectedItemChanged: (i) => setState(() => onChanged(i)),
                    childDelegate: ListWheelChildBuilderDelegate(
                      childCount: count,
                      builder: (context, index) => Center(
                        child: Text(
                          index.toString().padLeft(2, '0'),
                          style: t.text.digitsMedium,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: t.space.xs),
          Text(unit, style: t.text.caption),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tikky;
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: t.sizes.sheetMaxWidth / 2,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _wheel(
              controller: _hourController,
              count: _maxHours + 1,
              unit: Strings.unitHoursShort,
              semanticLabel: Strings.hours,
              onChanged: (v) => _hours = v,
            ),
            SizedBox(width: t.space.sm),
            _wheel(
              controller: _minuteController,
              count: 60,
              unit: Strings.unitMinutesShort,
              semanticLabel: Strings.minutes,
              onChanged: (v) => _minutes = v,
            ),
            if (widget.showSeconds) ...[
              SizedBox(width: t.space.sm),
              _wheel(
                controller: _secondController,
                count: 60,
                unit: Strings.unitSecondsShort,
                semanticLabel: Strings.seconds,
                onChanged: (v) => _seconds = v,
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text(Strings.cancel),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(_value),
          child: const Text(Strings.ok),
        ),
      ],
    );
  }
}

DateTime _clampDate(DateTime value, DateTime first, DateTime last) {
  if (value.isBefore(first)) return first;
  if (value.isAfter(last)) return last;
  return value;
}

/// Picks a calendar day: [CupertinoDatePicker] on iOS / macOS, the Material
/// date picker elsewhere. Returns local midnight of the chosen day, or
/// `null` when cancelled.
Future<DateTime?> showAdaptiveDatePicker(
  BuildContext context, {
  required DateTime initial,
  required DateTime first,
  required DateTime last,
  String title = Strings.pickDate,
}) async {
  final start = _clampDate(initial, first, last);
  if (isCupertino(context)) {
    var value = start;
    final picked = await _showCupertinoPickerPopup<DateTime>(
      context,
      title: title,
      currentValue: () => value,
      pickerBuilder: (context) => CupertinoDatePicker(
        mode: CupertinoDatePickerMode.date,
        initialDateTime: start,
        minimumDate: first,
        maximumDate: last,
        onDateTimeChanged: (d) => value = d,
      ),
    );
    return picked == null
        ? null
        : DateTime(picked.year, picked.month, picked.day);
  }
  return showDatePicker(
    context: context,
    initialDate: start,
    firstDate: first,
    lastDate: last,
    helpText: title,
    cancelText: Strings.cancel,
    confirmText: Strings.ok,
  );
}

/// Picks a date and time (e.g. to correct a protocol entry): one combined
/// [CupertinoDatePicker] on iOS / macOS, Material date then time pickers
/// elsewhere. Returns `null` when cancelled.
Future<DateTime?> showAdaptiveDateTimePicker(
  BuildContext context, {
  required DateTime initial,
  required DateTime first,
  required DateTime last,
  bool use24h = true,
  String title = Strings.pickTime,
}) async {
  final start = _clampDate(initial, first, last);
  if (isCupertino(context)) {
    var value = start;
    return _showCupertinoPickerPopup<DateTime>(
      context,
      title: title,
      currentValue: () => value,
      pickerBuilder: (context) => CupertinoDatePicker(
        mode: CupertinoDatePickerMode.dateAndTime,
        initialDateTime: start,
        minimumDate: first,
        maximumDate: last,
        use24hFormat: use24h,
        onDateTimeChanged: (d) => value = d,
      ),
    );
  }
  final date = await showDatePicker(
    context: context,
    initialDate: start,
    firstDate: first,
    lastDate: last,
    helpText: Strings.pickDate,
    cancelText: Strings.cancel,
    confirmText: Strings.ok,
  );
  if (date == null || !context.mounted) return null;
  final time = await showTimePicker(
    context: context,
    initialTime: TimeOfDay.fromDateTime(start),
    helpText: title,
    cancelText: Strings.cancel,
    confirmText: Strings.ok,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: use24h),
      child: child!,
    ),
  );
  if (time == null) return null;
  return DateTime(date.year, date.month, date.day, time.hour, time.minute);
}

/// Picks a range of days for the history filter: the Material date range
/// picker, or two stacked [CupertinoDatePicker]s on iOS / macOS. The result
/// holds local midnights of the first and last day (both inclusive);
/// `null` when cancelled.
Future<DateTimeRange?> showAdaptiveDateRangePicker(
  BuildContext context, {
  required DateTime first,
  required DateTime last,
  DateTimeRange? initial,
  String title = Strings.filterDateRange,
}) async {
  if (isCupertino(context)) {
    var from = _clampDate(initial?.start ?? last, first, last);
    var to = _clampDate(initial?.end ?? last, first, last);
    final t = context.tikky;
    final picked = await _showCupertinoPickerPopup<DateTimeRange>(
      context,
      title: title,
      height: 2 * 150 + 2 * t.sizes.minTapTarget,
      currentValue: () => from.isAfter(to)
          ? DateTimeRange(start: to, end: from)
          : DateTimeRange(start: from, end: to),
      pickerBuilder: (context) {
        Widget section(
          String label,
          DateTime start,
          ValueChanged<DateTime> onChanged,
        ) => Expanded(
          child: Column(
            children: [
              Text(label, style: t.text.caption),
              Expanded(
                child: CupertinoDatePicker(
                  mode: CupertinoDatePickerMode.date,
                  initialDateTime: start,
                  minimumDate: first,
                  maximumDate: last,
                  onDateTimeChanged: onChanged,
                ),
              ),
            ],
          ),
        );
        return Column(
          children: [
            section(Strings.filterFrom, from, (d) => from = d),
            section(Strings.filterTo, to, (d) => to = d),
          ],
        );
      },
    );
    if (picked == null) return null;
    return DateTimeRange(
      start: DateTime(picked.start.year, picked.start.month, picked.start.day),
      end: DateTime(picked.end.year, picked.end.month, picked.end.day),
    );
  }
  return showDateRangePicker(
    context: context,
    firstDate: first,
    lastDate: last,
    initialDateRange: initial,
    helpText: title,
    cancelText: Strings.cancel,
    confirmText: Strings.ok,
    saveText: Strings.ok,
  );
}
