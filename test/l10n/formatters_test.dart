import 'package:flutter_test/flutter_test.dart';
import 'package:tikky_takka/core/domain/domain.dart';
import 'package:tikky_takka/core/engine/engine.dart';
import 'package:tikky_takka/l10n/formatters.dart';
import 'package:tikky_takka/l10n/strings.dart';

import '../support/events.dart';

void main() {
  test('clock rounds down', () {
    expect(Fmt.clock(0), '00:00');
    expect(Fmt.clock(999), '00:00');
    expect(Fmt.clock(61 * sec), '01:01');
    expect(Fmt.clock(hour + 2 * min + 3 * sec), '1:02:03');
    expect(Fmt.clock(5 * sec, alwaysHours: true), '0:00:05');
    expect(Fmt.clock(12 * sec + 345, tenths: true), '00:12.3');
    expect(Fmt.clock(-500), '00:00');
    expect(Fmt.clock(100 * hour), '100:00:00');
  });

  test('remaining rounds up to full seconds', () {
    expect(Fmt.remaining(10 * min), '10:00');
    expect(Fmt.remaining(10 * min - 1), '10:00');
    expect(Fmt.remaining(1), '00:01');
    expect(Fmt.remaining(0), '00:00');
    expect(Fmt.remaining(-5), '00:00');
    expect(Fmt.remaining(1500, tenths: true), '00:01.5');
  });

  test('hms is always hh:mm:ss', () {
    expect(Fmt.hms(0), '00:00:00');
    expect(Fmt.hms(hour + 2 * min + 3 * sec + 999), '01:02:03');
    expect(Fmt.hms(30 * hour), '30:00:00');
  });

  test('compact and coarse durations', () {
    expect(Fmt.compact(5 * sec), '5 s');
    expect(Fmt.compact(2 * min + 5 * sec), '2 min 5 s');
    expect(Fmt.compact(42 * min + 5 * sec), '42 min');
    expect(Fmt.compact(hour), '1 h');
    expect(Fmt.compact(hour + 42 * min), '1 h 42 min');
    expect(Fmt.compact(51 * hour), '2 T 3 h');
    expect(Fmt.coarse(59 * sec), '0 min');
    expect(Fmt.coarse(hour + 42 * min + 59 * sec), '1 h 42 min');
    expect(Fmt.ago(30 * sec), Strings.justNow);
    expect(Fmt.ago(102 * min), 'vor 1 h 42 min');
    expect(
      Strings.protocolPersonSince('Alex', Fmt.coarse(102 * min)),
      'Alex · vor 1 h 42 min',
    );
  });

  test('times and dates use local time', () {
    final evening = DateTime(2026, 11, 11, 21, 5, 9).millisecondsSinceEpoch;
    final midnight = DateTime(2026, 11, 11, 0, 7).millisecondsSinceEpoch;
    expect(Fmt.time(evening), '21:05');
    expect(Fmt.time(evening, seconds: true), '21:05:09');
    expect(Fmt.time(evening, use24h: false), '9:05 PM');
    expect(Fmt.time(midnight, use24h: false), '12:07 AM');
    expect(Fmt.date(evening), '11.11.2026');
    expect(Fmt.dateTime(evening), '11.11.2026, 21:05');
    expect(Fmt.isoLocal(evening), '2026-11-11T21:05:09');
    expect(Fmt.fileStamp(evening), '2026-11-11_2105');
  });

  test('export timestamps carry the UTC offset of the instant', () {
    final evening = DateTime(2026, 11, 11, 21, 5, 9);
    final iso = Fmt.isoLocalWithOffset(evening.millisecondsSinceEpoch);
    expect(iso, matches(RegExp(r'^2026-11-11T21:05:09[+-]\d\d:\d\d$')));
    // Parses back to exactly the same instant, whatever the test zone is.
    expect(
      DateTime.parse(iso).millisecondsSinceEpoch,
      evening.millisecondsSinceEpoch,
    );
    expect(iso, endsWith(Fmt.isoOffset(evening.timeZoneOffset)));

    expect(Fmt.isoOffset(Duration.zero), '+00:00');
    expect(Fmt.isoOffset(const Duration(hours: 1)), '+01:00');
    expect(Fmt.isoOffset(const Duration(hours: 5, minutes: 45)), '+05:45');
    expect(Fmt.isoOffset(const Duration(hours: -3, minutes: -30)), '-03:30');
    expect(Fmt.isoOffset(const Duration(hours: -11)), '-11:00');
  });

  test('day headers', () {
    final now = DateTime(2026, 11, 11, 12).millisecondsSinceEpoch;
    expect(Fmt.dayHeader(const LocalDay(2026, 11, 11), todayMs: now), 'Heute');
    expect(
      Fmt.dayHeader(const LocalDay(2026, 11, 10), todayMs: now),
      'Gestern',
    );
    expect(
      Fmt.dayHeader(const LocalDay(2026, 11, 9), todayMs: now),
      'Mo., 9. Nov. 2026',
    );
    expect(Fmt.dayLong(const LocalDay(2026, 3, 1)), 'So., 1. März 2026');
  });

  test('strings cover every mode and event type', () {
    for (final mode in TrackMode.values) {
      expect(Strings.modeName(mode), isNotEmpty);
      expect(Strings.modeDescription(mode), isNotEmpty);
    }
    for (final type in EventType.values) {
      expect(Strings.eventTypeName(type), isNotEmpty);
    }
    expect(Strings.modeName(TrackMode.counter), 'Zähler');
    expect(Strings.fontName('mono'), Strings.fontMono);
    expect(Strings.fontName('whatever'), Strings.fontSystem);
  });
}
