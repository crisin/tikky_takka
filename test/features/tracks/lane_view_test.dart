import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tikky_takka/core/domain/domain.dart';
import 'package:tikky_takka/core/engine/engine.dart';
import 'package:tikky_takka/core/repo/models.dart';
import 'package:tikky_takka/features/tracks/color_picker.dart';
import 'package:tikky_takka/features/tracks/lane_actions.dart';
import 'package:tikky_takka/features/tracks/lane_view.dart';
import 'package:tikky_takka/features/tracks/ring_monitor.dart';
import 'package:tikky_takka/features/tracks/tracks_screen.dart';
import 'package:tikky_takka/l10n/strings.dart';
import 'package:tikky_takka/theme/theme.dart';

import '../../support/events.dart';

Track _track(TrackConfig config, {String id = 't1', String name = 'Spur'}) =>
    Track(id: id, setId: 'set', name: name, config: config);

OpenSession _open(Track track, EventLog log, {TrackConfig? config}) =>
    OpenSession(
      session: Session(
        id: log.sessionId,
        trackId: track.id,
        config: config ?? track.config,
        startedAt: log.events.first.at,
      ),
      events: log.events,
    );

List<LaneSecondaryKind> _enabled(LaneControls controls) => [
  if (controls.secondary case final s? when s.enabled) s.kind,
];

void main() {
  group('stopwatch lane', () {
    final track = _track(const StopwatchConfig());

    test('idle: zero, ready, start', () {
      final view = buildLaneView(track: track, open: null, nowMs: 0);
      expect(view.time.digits, '00:00');
      expect(view.time.subLine, Strings.statusIdle);
      expect(view.time.progress, isNull);
      expect(view.controls.primary, LanePrimary.start);
      expect(_enabled(view.controls), isEmpty);
      expect(view.controls.look, LaneLook.idle);
      expect(view.controls.canStop, isFalse);
      expect(view.ticking, isFalse);
    });

    test('running: elapsed time, pause, lap and stop enabled', () {
      final log = EventLog()..start(0);
      final view = buildLaneView(
        track: track,
        open: _open(track, log),
        nowMs: 2 * min + 3 * sec + 400,
      );
      expect(view.time.digits, '02:03');
      expect(view.time.subLine, Strings.statusRunning);
      expect(view.controls.primary, LanePrimary.pause);
      expect(_enabled(view.controls), [LaneSecondaryKind.lap]);
      expect(view.controls.look, LaneLook.running);
      expect(view.controls.canStop, isTrue);
      expect(view.ticking, isTrue);
    });

    test('tenths follow the preference', () {
      final log = EventLog()..start(0);
      final view = buildLaneView(
        track: track,
        open: _open(track, log),
        nowMs: 2 * min + 3 * sec + 400,
        prefs: const UiPrefs(showTenths: true),
      );
      expect(view.time.digits, '02:03.4');
    });

    test('paused: resume, no lap', () {
      final log = EventLog()
        ..start(0)
        ..pause(10 * sec);
      final view = buildLaneView(
        track: track,
        open: _open(track, log),
        nowMs: min,
      );
      expect(view.time.digits, '00:10');
      expect(view.time.subLine, Strings.statusPaused);
      expect(view.controls.primary, LanePrimary.resume);
      expect(_enabled(view.controls), [LaneSecondaryKind.stop]);
      expect(view.controls.look, LaneLook.paused);
      expect(view.ticking, isFalse);
    });

    test('laps show the current lap and the last one', () {
      final log = EventLog()
        ..start(0)
        ..lap(30 * sec);
      final view = buildLaneView(
        track: track,
        open: _open(track, log),
        nowMs: 42 * sec,
      );
      expect(view.time.subLine, contains(Strings.lapNumber(2)));
      expect(view.time.subLine, contains('00:12'));
      expect(view.time.subLine, contains(Strings.lastLap('00:30')));
    });

    test('a session of another mode is ignored', () {
      final log = EventLog()..start(0);
      final view = buildLaneView(
        track: track,
        open: _open(track, log, config: const CountdownConfig()),
        nowMs: 5 * sec,
      );
      expect(view.snapshot.isIdle, isTrue);
      expect(view.controls.primary, LanePrimary.start);
    });
  });

  group('countdown lane', () {
    final track = _track(const CountdownConfig(durationMs: 10 * min));

    test('idle shows the duration', () {
      final view = buildLaneView(track: track, open: null, nowMs: 0);
      expect(view.time.digits, '10:00');
      expect(view.time.progress, 0);
      expect(view.controls.primary, LanePrimary.start);
    });

    test('running counts down with progress', () {
      final log = EventLog()..start(0);
      final view = buildLaneView(
        track: track,
        open: _open(track, log),
        nowMs: 150 * sec,
      );
      expect(view.time.digits, '07:30');
      expect(view.time.progress, 0.25);
      expect(view.time.alert, isFalse);
      expect(view.controls.primary, LanePrimary.pause);
      expect(_enabled(view.controls), [LaneSecondaryKind.restart]);
    });

    test('finished: ringing, overtime, dismiss', () {
      final log = EventLog()..start(0);
      final view = buildLaneView(
        track: track,
        open: _open(track, log),
        nowMs: 10 * min + 12 * sec,
        blinkMs: 600,
      );
      expect(view.controls.ringing, isTrue);
      expect(view.controls.primary, LanePrimary.dismiss);
      expect(view.time.digits, '+00:12');
      expect(view.time.alert, isTrue);
      expect(view.time.progress, 1);
      expect(view.time.subLine, startsWith(Strings.statusRinging));
      expect(_enabled(view.controls), [LaneSecondaryKind.restart]);
      expect(view.controls.look, LaneLook.ringing);
      expect(view.ticking, isTrue);
    });

    test('the blink phase alternates with time', () {
      final log = EventLog()..start(0);
      final open = _open(track, log);
      final a = buildLaneView(
        track: track,
        open: open,
        nowMs: 10 * min + 600,
        blinkMs: 600,
      );
      final b = buildLaneView(
        track: track,
        open: open,
        nowMs: 10 * min + 1200,
        blinkMs: 600,
      );
      expect(a.time.blinkOn, isNot(b.time.blinkOn));
    });

    test('auto restart reports completed cycles', () {
      final auto = _track(
        const CountdownConfig(durationMs: min, autoRestart: true),
      );
      final log = EventLog()..start(0);
      final view = buildLaneView(
        track: auto,
        open: _open(auto, log),
        nowMs: 2 * min + 15 * sec,
      );
      expect(view.controls.ringing, isFalse);
      expect(view.time.digits, '00:45');
      expect(view.time.subLine, contains(Strings.cyclesDone(2)));
    });
  });

  group('interval lane', () {
    final track = _track(
      const IntervalConfig(workMs: 30 * sec, restMs: 10 * sec, rounds: 3),
    );

    test('idle shows the programme', () {
      final view = buildLaneView(track: track, open: null, nowMs: 0);
      expect(view.time.digits, '00:30');
      expect(view.time.subLine, '3 × 00:30 / 00:10');
    });

    test('running shows round, phase and remaining time', () {
      final log = EventLog()..start(0);
      final view = buildLaneView(
        track: track,
        open: _open(track, log),
        nowMs: 35 * sec,
      );
      expect(view.time.digits, '00:05');
      expect(view.time.subLine, contains(Strings.roundOf(1, 3)));
      expect(view.time.subLine, contains(Strings.phaseRest));
      // The fill follows the phase: 5 of 10 seconds of rest are gone.
      expect(view.time.progress, closeTo(0.5, 0.001));
      expect(view.time.segments, const LaneSegments(current: 1, total: 3));
      expect(_enabled(view.controls), [LaneSecondaryKind.restart]);
    });

    test('finished: ringing and done', () {
      final log = EventLog()..start(0);
      final view = buildLaneView(
        track: track,
        open: _open(track, log),
        nowMs: 111 * sec,
      );
      expect(view.controls.ringing, isTrue);
      expect(view.controls.primary, LanePrimary.dismiss);
      expect(view.time.subLine, Strings.phaseDone);
      expect(view.time.digits, '00:00');
      expect(view.time.segments, const LaneSegments(current: 4, total: 3));
    });
  });

  group('counter lane', () {
    test('idle: zero and a tap button', () {
      final track = _track(const CounterConfig());
      final view = buildLaneView(track: track, open: null, nowMs: 0);
      expect(view.time.digits, '0');
      expect(view.time.secondaryDigits, isNull);
      expect(view.controls.primary, LanePrimary.tick);
      expect(view.controls.hasLabels, isFalse);
      expect(_enabled(view.controls), isEmpty);
    });

    test('counting: count, lap time, total time, undo', () {
      final track = _track(const CounterConfig());
      final log = EventLog()
        ..start(0)
        ..tick(0)
        ..tick(20 * sec)
        ..tick(60 * sec);
      final view = buildLaneView(
        track: track,
        open: _open(track, log),
        nowMs: 75 * sec,
      );
      expect(view.time.digits, '3');
      expect(view.time.secondaryDigits, '00:15');
      expect(view.time.subLine, Strings.totalTime('01:15'));
      expect(_enabled(view.controls), [LaneSecondaryKind.undo]);
      expect(view.controls.canStop, isTrue);
      expect(view.ticking, isTrue);
    });

    test('quick labels replace the tap button and carry counts', () {
      final track = _track(const CounterConfig(labels: ['Hund', 'Reiher']));
      final log = EventLog()
        ..start(0)
        ..tick(0, label: 'Hund')
        ..tick(sec, label: 'Hund')
        ..tick(2 * sec, label: 'Reiher');
      final view = buildLaneView(
        track: track,
        open: _open(track, log),
        nowMs: 3 * sec,
      );
      expect(view.controls.primary, LanePrimary.none);
      expect(view.controls.labelCounts, {'Hund': 2, 'Reiher': 1});
      expect(view.controls.labelCounts.keys.toList(), ['Hund', 'Reiher']);
      expect(view.time.digits, '3');
    });
  });

  group('reminder lane', () {
    final track = _track(
      const ReminderConfig(intervalMs: 30 * min, nagEveryMs: min),
    );

    test('idle shows the interval', () {
      final view = buildLaneView(track: track, open: null, nowMs: 0);
      expect(view.time.digits, '30:00');
      expect(view.controls.primary, LanePrimary.start);
    });

    test('running: countdown to due, early ack possible', () {
      final log = EventLog()..start(0);
      final view = buildLaneView(
        track: track,
        open: _open(track, log),
        nowMs: 10 * min,
      );
      expect(view.time.digits, '20:00');
      expect(view.time.progress, closeTo(1 / 3, 0.001));
      expect(view.controls.primary, LanePrimary.pause);
      expect(_enabled(view.controls), [LaneSecondaryKind.ackEarly]);
    });

    test('due: ringing until acknowledged', () {
      final log = EventLog()..start(0);
      final view = buildLaneView(
        track: track,
        open: _open(track, log),
        nowMs: 32 * min,
      );
      expect(view.controls.ringing, isTrue);
      expect(view.controls.primary, LanePrimary.ack);
      expect(view.controls.status, Strings.statusDue);
      expect(view.controls.look, LaneLook.due);
      expect(view.controls.secondary, isNull);
      expect(view.time.digits, '+02:00');
      expect(view.time.alert, isTrue);
    });

    test('an ack restarts the interval and is counted', () {
      final log = EventLog()
        ..start(0)
        ..ack(32 * min);
      final view = buildLaneView(
        track: track,
        open: _open(track, log),
        nowMs: 33 * min,
      );
      expect(view.controls.ringing, isFalse);
      expect(view.time.digits, '29:00');
      expect(view.time.subLine, contains('1×'));
    });
  });

  test('LaneTime and LaneControls have value equality', () {
    final track = _track(const StopwatchConfig());
    final log = EventLog()..start(0);
    final open = _open(track, log);
    final a = buildLaneView(track: track, open: open, nowMs: 5 * sec + 100);
    final b = buildLaneView(track: track, open: open, nowMs: 5 * sec + 900);
    final c = buildLaneView(track: track, open: open, nowMs: 6 * sec);
    expect(a.time, b.time);
    expect(a.controls, b.controls);
    expect(a.time, isNot(c.time));
    expect(a.controls, c.controls);
  });

  test('LaneModel memoises per instant', () {
    final track = _track(const StopwatchConfig());
    final model = LaneModel(
      track: track,
      open: null,
      prefs: UiPrefs.defaults,
      blinkMs: 600,
    );
    expect(identical(model.at(1), model.at(1)), isTrue);
    expect(identical(model.at(1), model.at(2)), isFalse);
  });

  group('LaneActions.anyRunning', () {
    test('only running start/pause tracks count', () {
      final stopwatch = _track(const StopwatchConfig(), id: 'a');
      final counter = _track(const CounterConfig(), id: 'b');
      final running = EventLog(trackId: 'a')..start(0);
      final paused = EventLog(trackId: 'a')
        ..start(0)
        ..pause(sec);
      final counting = EventLog(trackId: 'b')
        ..start(0)
        ..tick(0);
      expect(
        LaneActions.anyRunning(
          [stopwatch, counter],
          {'b': _open(counter, counting)},
          5 * sec,
        ),
        isFalse,
      );
      expect(
        LaneActions.anyRunning(
          [stopwatch],
          {'a': _open(stopwatch, paused)},
          5 * sec,
        ),
        isFalse,
      );
      expect(
        LaneActions.anyRunning(
          [stopwatch],
          {'a': _open(stopwatch, running)},
          5 * sec,
        ),
        isTrue,
      );
    });
  });

  group('RingTracker', () {
    test('a countdown rings when it reaches zero and then repeats every '
        'few seconds until it is dismissed', () {
      final track = _track(const CountdownConfig(durationMs: min));
      final sessions = {track.id: _open(track, EventLog()..start(0))};
      final tracker = RingTracker();
      expect(tracker.update(sessions, 10 * sec), isEmpty);
      expect(tracker.update(sessions, 59 * sec), isEmpty);
      expect(tracker.update(sessions, 60 * sec), [track.id]);
      // Not on every tick ...
      expect(tracker.update(sessions, 61 * sec), isEmpty);
      expect(tracker.update(sessions, 64 * sec + 900), isEmpty);
      // ... but at the cadence, for as long as nobody reacts.
      expect(tracker.update(sessions, 60 * sec + ringRepeatEveryMs), [
        track.id,
      ]);
      expect(tracker.update(sessions, 66 * sec), isEmpty);
      expect(tracker.update(sessions, 60 * sec + 2 * ringRepeatEveryMs), [
        track.id,
      ]);
      expect(tracker.update(sessions, 10 * min), [track.id]);
      // Dismissed (session closed): silence.
      expect(tracker.update(const {}, 10 * min + ringRepeatEveryMs), isEmpty);
    });

    test('the cadence is one constant and can be switched off', () {
      expect(ringRepeatEveryMs, 5000);
      final track = _track(const CountdownConfig(durationMs: min));
      final sessions = {track.id: _open(track, EventLog()..start(0))};
      final once = RingTracker(repeatEveryMs: 0);
      expect(once.update(sessions, 59 * sec), isEmpty);
      expect(once.update(sessions, 60 * sec), [track.id]);
      expect(once.update(sessions, 5 * min), isEmpty);
    });

    test('what already rings when first seen is not a fresh ring: it joins '
        'the repeating cue', () {
      final track = _track(const CountdownConfig(durationMs: min));
      final sessions = {track.id: _open(track, EventLog()..start(0))};
      final tracker = RingTracker();
      // The OS notification rang at 1 min; no burst when the app sees it.
      expect(tracker.update(sessions, 5 * min), isEmpty);
      expect(tracker.update(sessions, 5 * min + sec), isEmpty);
      expect(tracker.update(sessions, 5 * min + ringRepeatEveryMs), [track.id]);
    });

    test('after a trip to the background (clear) what finished meanwhile '
        'is not "just finished"', () {
      final track = _track(const CountdownConfig(durationMs: min));
      final sessions = {track.id: _open(track, EventLog()..start(0))};
      final tracker = RingTracker();
      expect(tracker.update(sessions, 30 * sec), isEmpty);
      // Backgrounded at 30 s, finished (and notified) at 60 s, back at 90 s.
      tracker.clear();
      expect(tracker.update(sessions, 90 * sec), isEmpty);
      expect(tracker.update(sessions, 91 * sec), isEmpty);
      expect(tracker.update(sessions, 90 * sec + ringRepeatEveryMs), [
        track.id,
      ]);
      // Without the new baseline it would have been a fresh ring.
      final naive = RingTracker();
      expect(naive.update(sessions, 30 * sec), isEmpty);
      expect(naive.update(sessions, 90 * sec), [track.id]);
    });

    test('an auto-restarting countdown rings per cycle and never repeats', () {
      final track = _track(
        const CountdownConfig(durationMs: min, autoRestart: true),
      );
      final sessions = {track.id: _open(track, EventLog()..start(0))};
      final tracker = RingTracker();
      expect(tracker.update(sessions, 59 * sec), isEmpty);
      expect(tracker.update(sessions, 60 * sec), [track.id]);
      expect(tracker.update(sessions, 60 * sec + ringRepeatEveryMs), isEmpty);
      expect(tracker.update(sessions, 119 * sec), isEmpty);
      expect(tracker.update(sessions, 120 * sec), [track.id]);
    });

    test('an interval rings on every phase change, at the end, and then '
        'repeats until dismissed', () {
      final track = _track(
        const IntervalConfig(workMs: 30 * sec, restMs: 10 * sec, rounds: 2),
      );
      final sessions = {track.id: _open(track, EventLog()..start(0))};
      final tracker = RingTracker();
      expect(tracker.update(sessions, sec), isEmpty);
      expect(tracker.update(sessions, 31 * sec), [track.id]); // rest
      // A phase change needs no reaction: no repetition.
      expect(tracker.update(sessions, 39 * sec), isEmpty);
      expect(tracker.update(sessions, 41 * sec), [track.id]); // work 2
      expect(tracker.update(sessions, 50 * sec), isEmpty);
      expect(tracker.update(sessions, 71 * sec), [track.id]); // done
      expect(tracker.update(sessions, 72 * sec), isEmpty);
      expect(tracker.update(sessions, 71 * sec + ringRepeatEveryMs), [
        track.id,
      ]);
    });

    test('a reminder rings when due, repeats, nags, and is quiet after the '
        'ack', () {
      final track = _track(
        const ReminderConfig(intervalMs: 10 * min, nagEveryMs: min),
      );
      final log = EventLog()..start(0);
      final tracker = RingTracker();
      var sessions = {track.id: _open(track, log)};
      expect(tracker.update(sessions, 9 * min), isEmpty);
      expect(tracker.update(sessions, 10 * min), [track.id]);
      expect(tracker.update(sessions, 10 * min + 2 * sec), isEmpty);
      // Due and not acknowledged: the cue repeats.
      expect(tracker.update(sessions, 10 * min + ringRepeatEveryMs), [
        track.id,
      ]);
      expect(tracker.update(sessions, 10 * min + 58 * sec), [track.id]);
      expect(tracker.update(sessions, 11 * min), [track.id]); // nag
      log.ack(11 * min + sec);
      sessions = {track.id: _open(track, log)};
      expect(tracker.update(sessions, 11 * min + 2 * sec), isEmpty);
      expect(tracker.update(sessions, 12 * min), isEmpty);
      expect(tracker.update(sessions, 21 * min + sec), [track.id]);
    });

    test('paused tracks and other modes never ring', () {
      final countdown = _track(const CountdownConfig(durationMs: min));
      final stopwatch = _track(const StopwatchConfig(), id: 't2');
      final paused = EventLog()
        ..start(0)
        ..pause(30 * sec);
      final sessions = {
        countdown.id: _open(countdown, paused),
        stopwatch.id: _open(stopwatch, EventLog(trackId: 't2')..start(0)),
      };
      final tracker = RingTracker();
      expect(tracker.update(sessions, 40 * sec), isEmpty);
      expect(tracker.update(sessions, 10 * min), isEmpty);
    });

    test('ringLevel grows with every signal', () {
      final track = _track(const CountdownConfig(durationMs: min));
      final log = EventLog()..start(0);
      int level(int now) => RingTracker.ringLevel(
        deriveSnapshot(config: track.config, events: log.events, nowMs: now),
      );
      expect(level(0), 0);
      expect(level(min), 1);
    });
  });

  group('laneColumns', () {
    test('rows: one column on phones, more when wide', () {
      expect(
        laneColumns(
          layout: LaneLayout.rows,
          width: 368,
          tileMinWidth: 300,
          wide: false,
        ),
        1,
      );
      expect(
        laneColumns(
          layout: LaneLayout.rows,
          width: 1000,
          tileMinWidth: 300,
          wide: true,
        ),
        2,
      );
      expect(
        laneColumns(
          layout: LaneLayout.rows,
          width: 400,
          tileMinWidth: 300,
          wide: true,
        ),
        1,
      );
    });

    test('tiles: at least two columns', () {
      expect(
        laneColumns(
          layout: LaneLayout.tiles,
          width: 368,
          tileMinWidth: 300,
          wide: false,
        ),
        2,
      );
      expect(
        laneColumns(
          layout: LaneLayout.tiles,
          width: 1000,
          tileMinWidth: 300,
          wide: true,
        ),
        4,
      );
    });
  });

  group('hex colours', () {
    test('parse and format', () {
      expect(parseHexColor('#FF8800'), const Color(0xFFFF8800));
      expect(parseHexColor('ff8800'), const Color(0xFFFF8800));
      expect(parseHexColor('80FF8800'), const Color(0xFFFF8800));
      expect(parseHexColor('xyz'), isNull);
      expect(parseHexColor('12345'), isNull);
      expect(formatHexColor(const Color(0xFF0A0B0C)), '0A0B0C');
    });
  });
}
