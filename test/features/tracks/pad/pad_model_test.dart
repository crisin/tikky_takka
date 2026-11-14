import 'package:flutter_test/flutter_test.dart';
import 'package:tikky_takka/core/domain/domain.dart';
import 'package:tikky_takka/core/engine/engine.dart';
import 'package:tikky_takka/core/repo/models.dart';
import 'package:tikky_takka/features/tracks/pad/pad_model.dart';
import 'package:tikky_takka/features/tracks/tracks_strings.dart';
import 'package:tikky_takka/l10n/strings.dart';

import '../../../support/events.dart';

Track _track(String id, TrackConfig config, {String? name}) =>
    Track(id: id, setId: 'set', name: name ?? id, config: config);

const _birds = CounterConfig(labels: ['Reiher', 'Ente', 'Specht']);

OpenSession _open(Track track, EventLog log) => OpenSession(
  session: Session(
    id: log.sessionId,
    trackId: track.id,
    config: track.config,
    startedAt: log.events.first.at,
  ),
  events: log.events,
);

List<String> _ids(Iterable<PadButton> buttons) => [
  for (final b in buttons) b.id,
];

void main() {
  final birds = _track('birds', _birds, name: 'Vögel');
  final plain = _track('plain', const CounterConfig(), name: 'Zähler');
  final watch = _track('watch', const StopwatchConfig(), name: 'Stoppuhr');
  final timer = _track('timer', const CountdownConfig(durationMs: 60 * sec));
  final interval = _track('interval', const IntervalConfig());
  final reminder = _track('reminder', const ReminderConfig(intervalMs: min));
  final tent = _track('tent', const ProtocolConfig(), name: 'Zelt');

  const jacke = Person(id: 'jacke', name: 'Jacke');
  const kim = Person(id: 'kim', name: 'Kim');
  const water = Substance(id: 'water', name: 'Wasser');
  const tea = Substance(id: 'tea', name: 'Tee');
  const cola = Substance(id: 'cola', name: 'Cola');

  group('buildMainPad', () {
    test('one button per label, per plain counter, stopwatch and timer, '
        'in track order', () {
      final buttons = buildMainPad(
        tracks: [watch, birds, timer, plain, interval, reminder],
        persons: const [],
        scenePersonIds: const [],
        sceneSubstanceIds: const [],
        substances: const [],
      );
      expect(_ids(buttons), [
        's:watch',
        'c:birds:Reiher',
        'c:birds:Ente',
        'c:birds:Specht',
        't:timer',
        'c:plain',
        't:interval',
        't:reminder',
      ]);
      expect(buttons[1].kind, PadButtonKind.counter);
      expect(buttons[1].label, 'Reiher');
      expect(buttons[5].label, isNull);
      expect(buttons[4].kind, PadButtonKind.timer);
    });

    test('a repeated label gets one button', () {
      final track = _track('c', const CounterConfig(labels: ['A', 'B', 'A']));
      final buttons = buildMainPad(
        tracks: [track],
        persons: const [],
        scenePersonIds: const [],
        sceneSubstanceIds: const [],
        substances: const [],
      );
      expect(_ids(buttons), ['c:c:A', 'c:c:B']);
    });

    test('protocol without a scene: every person, then "+"', () {
      final buttons = buildMainPad(
        tracks: [tent],
        persons: const [jacke, kim],
        scenePersonIds: const [],
        sceneSubstanceIds: const [],
        substances: const [water],
      );
      expect(_ids(buttons), ['p:tent:jacke', 'p:tent:kim', 'm:tent:-']);
      expect(buttons.first.kind, PadButtonKind.person);
      expect(buttons.last.kind, PadButtonKind.more);
    });

    test('protocol with a scene: the scene persons in scene order; unknown '
        'ids are skipped', () {
      final buttons = buildMainPad(
        tracks: [tent],
        persons: const [jacke, kim],
        scenePersonIds: const ['kim', 'gone', 'jacke'],
        sceneSubstanceIds: const [],
        substances: const [water],
      );
      expect(_ids(buttons), ['p:tent:kim', 'p:tent:jacke', 'm:tent:-']);
    });

    test('a single-person scene shows the substance buttons directly: scene '
        'substances first, then the most used, at most five', () {
      const many = [
        water,
        tea,
        cola,
        Substance(id: 'a', name: 'A'),
        Substance(id: 'b', name: 'B'),
        Substance(id: 'c', name: 'C'),
        Substance(id: 'd', name: 'D'),
      ];
      final buttons = buildMainPad(
        tracks: [tent],
        persons: const [jacke, kim],
        scenePersonIds: const ['kim'],
        sceneSubstanceIds: const ['tea'],
        substances: many,
        useByTrack: const {
          'tent': [
            SubstanceUse(
              personId: 'kim',
              substanceId: 'cola',
              count: 4,
              lastAt: 10,
            ),
            SubstanceUse(
              personId: 'kim',
              substanceId: 'a',
              count: 2,
              lastAt: 10,
            ),
            SubstanceUse(
              personId: 'kim',
              substanceId: 'b',
              count: 2,
              lastAt: 20,
            ),
            SubstanceUse(
              personId: 'kim',
              substanceId: 'c',
              count: 1,
              lastAt: 30,
            ),
            SubstanceUse(
              personId: 'kim',
              substanceId: 'd',
              count: 1,
              lastAt: 5,
            ),
            // Somebody else's use does not count for Kim.
            SubstanceUse(
              personId: 'jacke',
              substanceId: 'water',
              count: 99,
              lastAt: 99,
            ),
          ],
        },
      );
      expect(_ids(buttons), [
        'x:tent:kim:tea',
        'x:tent:kim:cola',
        'x:tent:kim:b',
        'x:tent:kim:a',
        'x:tent:kim:c',
        'm:tent:kim',
      ]);
      expect(buttons.first.kind, PadButtonKind.substance);
      expect(buttons.first.personId, 'kim');
      expect(buttons.first.substanceId, 'tea');
      expect(buttons.last.personId, 'kim');
    });

    test('the pad never invents a substance button: no scene substance and '
        'no earlier entry means only "+"', () {
      final buttons = buildSubstancePad(
        track: tent,
        personId: 'jacke',
        sceneSubstanceIds: const [],
        substances: const [water, tea],
        use: const [],
      );
      expect(_ids(buttons), ['m:tent:jacke']);
    });
  });

  group('mergePadButtons', () {
    final fresh = buildMainPad(
      tracks: [watch, birds],
      persons: const [],
      scenePersonIds: const [],
      sceneSubstanceIds: const [],
      substances: const [],
    );

    test('a new pad shows the fresh buttons', () {
      expect(
        mergePadButtons(shownIds: const [], fresh: fresh, candidates: fresh),
        fresh,
      );
    });

    test('shown buttons keep their places when the tracks are reordered, '
        'new ones go to the end, gone ones leave', () {
      final shown = _ids(fresh);
      final reordered = buildMainPad(
        tracks: [
          _track(
            'birds',
            const CounterConfig(labels: ['Ente', 'Reiher', 'Uhu']),
          ),
          plain,
          watch,
        ],
        persons: const [],
        scenePersonIds: const [],
        sceneSubstanceIds: const [],
        substances: const [],
      );
      final merged = mergePadButtons(
        shownIds: shown,
        fresh: reordered,
        candidates: reordered,
      );
      expect(_ids(merged), [
        's:watch',
        'c:birds:Reiher',
        'c:birds:Ente',
        // "Specht" is gone; "Uhu" and the new track are appended.
        'c:birds:Uhu',
        'c:plain',
      ]);
    });

    test('a substance button stays although another became more used, and '
        'a group never grows beyond the limit', () {
      List<PadButton> pad(List<SubstanceUse> use, {int? limit = 2}) =>
          buildMainPad(
            tracks: [tent],
            persons: const [kim],
            scenePersonIds: const ['kim'],
            sceneSubstanceIds: const [],
            substances: const [water, tea, cola],
            useByTrack: {'tent': use},
            limit: limit,
          );
      const before = [
        SubstanceUse(
          personId: 'kim',
          substanceId: 'water',
          count: 3,
          lastAt: 1,
        ),
        SubstanceUse(personId: 'kim', substanceId: 'tea', count: 2, lastAt: 1),
      ];
      const after = [
        ...before,
        SubstanceUse(personId: 'kim', substanceId: 'cola', count: 9, lastAt: 9),
      ];
      final shown = _ids(pad(before));
      expect(shown, ['x:tent:kim:water', 'x:tent:kim:tea', 'm:tent:kim']);
      // A new pad would now lead with Cola ...
      expect(_ids(pad(after)).first, 'x:tent:kim:cola');
      // ... the open one does not move anything.
      final merged = mergePadButtons(
        shownIds: shown,
        fresh: pad(after),
        candidates: pad(after, limit: null),
        substanceLimit: 2,
      );
      expect(_ids(merged), shown);
    });

    test('a substance that was removed from the list leaves the pad', () {
      final candidates = buildMainPad(
        tracks: [tent],
        persons: const [kim],
        scenePersonIds: const ['kim'],
        sceneSubstanceIds: const ['water'],
        substances: const [water],
        limit: null,
      );
      final merged = mergePadButtons(
        shownIds: const ['x:tent:kim:water', 'x:tent:kim:tea', 'm:tent:kim'],
        fresh: candidates,
        candidates: candidates,
      );
      expect(_ids(merged), ['x:tent:kim:water', 'm:tent:kim']);
    });
  });

  group('computePadLayout', () {
    PadLayout layout(int count, double width, double height) =>
        computePadLayout(
          count: count,
          width: width,
          height: height,
          minButtonHeight: 72,
          minButtonWidth: 104,
          gap: 8,
        );

    test('the buttons fill the pad: rows x rowHeight + gaps = height', () {
      for (final count in [1, 2, 3, 5, 8, 12]) {
        final l = layout(count, 336, 600);
        expect(l.scrolls, isFalse, reason: '$count');
        expect(l.columns * l.rows, greaterThanOrEqualTo(count));
        expect((l.columns - 1) * l.rows, lessThan(count), reason: '$count');
        expect(
          l.rows * l.rowHeight + (l.rows - 1) * 8,
          closeTo(600, 0.001),
          reason: '$count',
        );
        expect(l.rowHeight, greaterThanOrEqualTo(72));
      }
    });

    test('a phone gets few columns, a wide window more', () {
      final phone = layout(12, 336, 600);
      expect(phone.columns, 2);
      expect(phone.rows, 6);
      final desktop = layout(12, 1000, 600);
      expect(desktop.columns, greaterThan(phone.columns));
      expect(desktop.scrolls, isFalse);
    });

    test('never narrower than the minimum width', () {
      // 336 px hold three columns of 104 px with two gaps of 8 px.
      final l = layout(30, 336, 2000);
      expect(l.columns, lessThanOrEqualTo(3));
      expect(layout(30, 100, 4000).columns, 1);
    });

    test('scrolls with rows of the minimum height when it cannot fit', () {
      final l = layout(40, 336, 500);
      expect(l.scrolls, isTrue);
      expect(l.columns, 3);
      expect(l.rows, 14);
      expect(l.rowHeight, 72);
    });

    test('a single button and no button at all', () {
      final one = layout(1, 336, 500);
      expect(one.columns, 1);
      expect(one.rows, 1);
      expect(one.rowHeight, 500);
      expect(layout(0, 336, 500).rows, 0);
    });
  });

  group('padTapAction', () {
    test('counter: always a tick', () {
      for (final state in RunState.values) {
        expect(
          padTapAction(PadButton.counter(birds), state),
          PadTapAction.tick,
        );
      }
    });

    test('stopwatch: start, lap, resume', () {
      final b = PadButton.stopwatch(watch);
      expect(padTapAction(b, RunState.idle), PadTapAction.start);
      expect(padTapAction(b, RunState.stopped), PadTapAction.start);
      expect(padTapAction(b, RunState.running), PadTapAction.lap);
      expect(padTapAction(b, RunState.paused), PadTapAction.resume);
    });

    test('timers: start when idle, dismiss or acknowledge when ringing, '
        'never pause', () {
      for (final track in [timer, interval, reminder]) {
        final b = PadButton.timer(track);
        expect(padTapAction(b, RunState.idle), PadTapAction.start);
        expect(padTapAction(b, RunState.running), PadTapAction.none);
        expect(padTapAction(b, RunState.paused), PadTapAction.none);
      }
      expect(
        padTapAction(PadButton.timer(timer), RunState.ringing),
        PadTapAction.dismiss,
      );
      expect(
        padTapAction(PadButton.timer(interval), RunState.ringing),
        PadTapAction.dismiss,
      );
      expect(
        padTapAction(PadButton.timer(reminder), RunState.ringing),
        PadTapAction.ack,
      );
    });

    test('protocol: person opens, substance writes, "+" opens the sheet', () {
      expect(
        padTapAction(PadButton.person(tent, 'kim'), RunState.idle),
        PadTapAction.openPerson,
      );
      expect(
        padTapAction(
          PadButton.substance(tent, personId: 'kim', substanceId: 'tea'),
          RunState.running,
        ),
        PadTapAction.entry,
      );
      expect(
        padTapAction(PadButton.more(tent), RunState.idle),
        PadTapAction.openSheet,
      );
    });
  });

  group('faces', () {
    test('counter: count and last tap per label', () {
      final log = EventLog(trackId: birds.id)
        ..start(0)
        ..tick(0, label: 'Reiher')
        ..tick(5 * sec, label: 'Ente')
        ..tick(9 * sec, label: 'Reiher');
      final open = _open(birds, log);
      final reiher = PadButton.counter(birds, label: 'Reiher');
      final specht = PadButton.counter(birds, label: 'Specht');
      expect(padCount(reiher, open), 2);
      expect(padLastTapAt(reiher, open), 9 * sec);
      expect(padValue(reiher, open, 20 * sec), '2');
      expect(padSubText(reiher, open, 21 * sec), 'vor 12 s');
      expect(padIsLive(reiher, open, 21 * sec), isTrue);
      expect(padCount(specht, open), 0);
      expect(padLastTapAt(specht, open), isNull);
      expect(padSubText(specht, open, 21 * sec), '');
      expect(padIsLive(specht, open, 21 * sec), isFalse);
      // Idle track.
      expect(padValue(reiher, null, 0), '0');
      expect(padSubText(reiher, null, 0), '');
    });

    test('a counter without labels counts every tick', () {
      final log = EventLog(trackId: plain.id)
        ..start(0)
        ..tick(0)
        ..tick(sec);
      expect(padCount(PadButton.counter(plain), _open(plain, log)), 2);
    });

    test('stopwatch: time and what a tap does', () {
      final b = PadButton.stopwatch(watch);
      expect(padValue(b, null, 0), '00:00');
      expect(padSubText(b, null, 0), TracksStrings.padTapToStart);
      expect(padIsLive(b, null, 0), isFalse);

      final log = EventLog(trackId: watch.id)..start(0);
      expect(padValue(b, _open(watch, log), 65 * sec), '01:05');
      expect(
        padSubText(b, _open(watch, log), 65 * sec),
        TracksStrings.padTapForLap,
      );
      expect(padIsLive(b, _open(watch, log), 65 * sec), isTrue);

      log.lap(60 * sec);
      expect(padSubText(b, _open(watch, log), 65 * sec), 'Runde 1 · vor 5 s');

      log.pause(70 * sec);
      expect(
        padSubText(b, _open(watch, log), 90 * sec),
        TracksStrings.padTapToResume,
      );
      expect(padIsLive(b, _open(watch, log), 90 * sec), isFalse);
    });

    test('timer: remaining time, then "tap to dismiss"', () {
      final b = PadButton.timer(timer);
      expect(padSubText(b, null, 0), TracksStrings.padTapToStart);
      final log = EventLog(trackId: timer.id)..start(0);
      final open = _open(timer, log);
      expect(padValue(b, open, 15 * sec), '00:45');
      expect(padSubText(b, open, 15 * sec), Strings.statusRunning);
      expect(padSubText(b, open, 61 * sec), TracksStrings.padTapToDismiss);
    });

    test('reminder that is due asks for "erledigt"', () {
      final b = PadButton.timer(reminder);
      final log = EventLog(trackId: reminder.id)..start(0);
      expect(
        padSubText(b, _open(reminder, log), 2 * min),
        TracksStrings.padTapToAck,
      );
    });

    test('person and substance buttons count the entries of the open '
        'session', () {
      final log = EventLog(trackId: tent.id)
        ..start(0)
        ..entry(0, person: 'kim', substance: 'tea')
        ..entry(min, person: 'kim', substance: 'water')
        ..entry(2 * min, person: 'jacke', substance: 'tea')
        ..entry(3 * min, person: 'kim', substance: 'tea');
      final open = _open(tent, log);
      final person = PadButton.person(tent, 'kim');
      final kimTea = PadButton.substance(
        tent,
        personId: 'kim',
        substanceId: 'tea',
      );
      expect(padCount(person, open), 3);
      expect(padLastTapAt(person, open), 3 * min);
      expect(padCount(kimTea, open), 2);
      expect(padSubText(kimTea, open, 3 * min + 30 * sec), 'vor 30 s');
      expect(padValue(PadButton.more(tent), open, 0), '+');
    });

    test('a session of another mode (left over) does not count', () {
      final log = EventLog(trackId: birds.id)
        ..start(0)
        ..tick(0, label: 'Reiher');
      final other = OpenSession(
        session: Session(
          id: 's1',
          trackId: birds.id,
          config: const StopwatchConfig(),
          startedAt: 0,
        ),
        events: log.events,
      );
      expect(padCount(PadButton.counter(birds, label: 'Reiher'), other), 0);
    });
  });
}
