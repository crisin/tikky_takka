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

    test('a set without persons in its scene has no protocol on the pad', () {
      final buttons = buildMainPad(
        tracks: [watch],
        persons: const [jacke, kim],
        scenePersonIds: const [],
        sceneSubstanceIds: const ['water'],
        substances: const [water],
      );
      expect(_ids(buttons), ['s:watch']);
    });

    test('the persons of the scene come first, in the order of the scene; '
        'unknown ids are skipped', () {
      final buttons = buildMainPad(
        tracks: [watch],
        persons: const [jacke, kim],
        scenePersonIds: const ['kim', 'gone', 'jacke', 'kim'],
        sceneSubstanceIds: const [],
        substances: const [water],
      );
      expect(_ids(buttons), ['p:kim', 'p:jacke', 's:watch']);
      expect(buttons.first.kind, PadButtonKind.person);
      expect(buttons.first.trackOrNull, isNull);
    });

    test('an old protocol track gets no button', () {
      final old = _track('tent', const ProtocolConfig());
      final buttons = buildMainPad(
        tracks: [old, watch],
        persons: const [],
        scenePersonIds: const [],
        sceneSubstanceIds: const [],
        substances: const [],
      );
      expect(_ids(buttons), ['s:watch']);
    });

    test('a scene of one person shows that person\'s things right away', () {
      final buttons = buildMainPad(
        tracks: [watch],
        persons: const [jacke, kim],
        scenePersonIds: const ['kim'],
        sceneSubstanceIds: const ['tea', 'water'],
        substances: const [water, tea, cola],
      );
      expect(_ids(buttons), ['x:kim:tea', 'x:kim:water', 'o:kim', 's:watch']);
      expect(buttons.first.kind, PadButtonKind.substance);
      expect(buttons.first.personId, 'kim');
      expect(buttons.first.substanceId, 'tea');
    });
  });

  group('buildSubstancePad', () {
    test('the things of the scene in its order, the same for everybody, '
        'at most five, then "Anderes"', () {
      const many = [
        water,
        tea,
        cola,
        Substance(id: 'a', name: 'A'),
        Substance(id: 'b', name: 'B'),
        Substance(id: 'c', name: 'C'),
      ];
      List<String> pad(String person) => _ids(
        buildSubstancePad(
          personId: person,
          sceneSubstanceIds: const [
            'c',
            'tea',
            'gone',
            'a',
            'water',
            'b',
            'cola',
          ],
          substances: many,
        ),
      );
      expect(pad('kim'), [
        'x:kim:c',
        'x:kim:tea',
        'x:kim:a',
        'x:kim:water',
        'x:kim:b',
        'o:kim',
      ]);
      expect(pad('jacke'), [
        for (final id in pad('kim')) id.replaceFirst('kim', 'jacke'),
      ]);
    });

    test('the pad never invents a field: no thing in the scene means only '
        '"Anderes"', () {
      final buttons = buildSubstancePad(
        personId: 'jacke',
        sceneSubstanceIds: const [],
        substances: const [water, tea],
      );
      expect(_ids(buttons), ['o:jacke']);
    });
  });

  group('buildOtherPad', () {
    test('everything that is not on "Was?", what this person had most '
        'often first, then the order of the list', () {
      final buttons = buildOtherPad(
        personId: 'kim',
        substances: const [
          water,
          tea,
          cola,
          Substance(id: 'a', name: 'A'),
        ],
        shownIds: const {'water'},
        use: const [
          SubstanceUse(personId: 'kim', substanceId: 'a', count: 3, lastAt: 1),
          SubstanceUse(
            personId: 'kim',
            substanceId: 'water',
            count: 9,
            lastAt: 9,
          ),
          // Somebody else's use does not count for Kim.
          SubstanceUse(
            personId: 'jacke',
            substanceId: 'cola',
            count: 99,
            lastAt: 99,
          ),
        ],
      );
      expect(_ids(buttons), ['x:kim:a', 'x:kim:tea', 'x:kim:cola']);
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
      expect(mergePadButtons(shownIds: const [], fresh: fresh), fresh);
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
        persons: const [kim, jacke],
        scenePersonIds: const ['kim', 'jacke'],
        sceneSubstanceIds: const [],
        substances: const [],
      );
      final merged = mergePadButtons(shownIds: shown, fresh: reordered);
      expect(_ids(merged), [
        's:watch',
        'c:birds:Reiher',
        'c:birds:Ente',
        // "Specht" is gone; who joined and what is new is appended.
        'p:kim',
        'p:jacke',
        'c:birds:Uhu',
        'c:plain',
      ]);
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

    test('minColumns: two columns where the width allows it, even for '
        'few buttons', () {
      PadLayout two(int count, double width) => computePadLayout(
        count: count,
        width: width,
        height: 600,
        minButtonHeight: 72,
        minButtonWidth: 104,
        gap: 8,
        minColumns: 2,
      );
      expect(two(3, 351).columns, 2);
      expect(two(3, 351).rows, 2);
      // One button, or too narrow for two: one column.
      expect(two(1, 351).columns, 1);
      expect(two(3, 150).columns, 1);
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

    test('protocol: person opens, thing writes, "Anderes" opens', () {
      expect(
        padTapAction(PadButton.person('kim'), RunState.idle),
        PadTapAction.openPerson,
      );
      expect(
        padTapAction(
          PadButton.substance(personId: 'kim', substanceId: 'tea'),
          RunState.running,
        ),
        PadTapAction.entry,
      );
      expect(
        padTapAction(PadButton.other('kim'), RunState.idle),
        PadTapAction.openOther,
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

    test('a thing counts what its person had of it today', () {
      const counts = {
        'kim': {'tea': 2, 'water': 1},
        'jacke': {'tea': 1},
      };
      PadButton thing(String person, String id) =>
          PadButton.substance(personId: person, substanceId: id);
      expect(padEntryCount(thing('kim', 'tea'), counts), 2);
      expect(padEntryCount(thing('jacke', 'water'), counts), 0);
      expect(padEntryCount(thing('gone', 'tea'), counts), 0);
    });

    test('person tile: time since the decisive entry, or the own lockout', () {
      const things = {'tea': tea, 'water': water};
      const facts = [
        LastEntryFact(personId: 'kim', substanceId: 'tea', at: 0),
        LastEntryFact(personId: 'kim', substanceId: 'water', at: 10 * min),
      ];
      final none = padPersonFace(personStand('jacke', facts, 20 * min), things);
      expect(none.digits, TracksStrings.padNoEntry);
      expect(none.line, TracksStrings.padNothingYet);
      expect(none.any, isFalse);

      final plain = padPersonFace(
        personStand('kim', facts, 26 * min + 14 * sec),
        things,
      );
      expect(plain.digits, '16:14');
      expect(plain.line, 'seit Wasser');
      expect(plain.warn, isFalse);

      final locked = padPersonFace(
        personStand(
          'kim',
          facts,
          26 * min,
          lockoutMsBySubstance: const {'tea': 60 * min},
        ),
        things,
      );
      expect(locked.digits, '26:00');
      expect(locked.line, 'Tee: noch 34 min');
      expect(locked.warn, isTrue);

      expect(padLatestFact('kim', facts)!.substanceId, 'water');
      expect(padLatestFact('jacke', facts), isNull);
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

  group('padLockout', () {
    final button = PadButton.substance(personId: 'kim', substanceId: 'tea');
    const lockouts = {'tea': 60 * min};
    const facts = [LastEntryFact(personId: 'kim', substanceId: 'tea', at: 0)];

    test('what is left of the own lockout and how much has passed', () {
      final l = padLockout(
        button,
        facts: facts,
        lockouts: lockouts,
        nowMs: 15 * min,
      );
      expect(l, isNotNull);
      expect(l!.remainingMs, 45 * min);
      expect(l.passed, closeTo(0.25, 0.0001));
    });

    test('none without a lockout, after it ran out, or for someone else', () {
      expect(
        padLockout(button, facts: facts, lockouts: const {}, nowMs: min),
        isNull,
      );
      expect(
        padLockout(button, facts: facts, lockouts: lockouts, nowMs: 61 * min),
        isNull,
      );
      expect(
        padLockout(
          PadButton.substance(personId: 'jacke', substanceId: 'tea'),
          facts: facts,
          lockouts: lockouts,
          nowMs: min,
        ),
        isNull,
      );
    });
  });
}
