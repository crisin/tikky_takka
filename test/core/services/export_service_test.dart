import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' show Rect;

import 'package:csv/csv.dart' show Csv;
import 'package:flutter_test/flutter_test.dart';
import 'package:tikky_takka/core/domain/domain.dart';
import 'package:tikky_takka/core/engine/engine.dart';
import 'package:tikky_takka/core/repo/repo.dart';
import 'package:tikky_takka/core/services/export_service.dart';
import 'package:tikky_takka/core/services/export_service_impl.dart';
import 'package:tikky_takka/l10n/formatters.dart';
import 'package:tikky_takka/l10n/strings.dart';
import 'package:tikky_takka/theme/ui_prefs.dart';

import '../../support/events.dart';
import '../../support/test_env.dart';

/// Records what would have been handed to the OS.
class FakeDelivery implements ExportDelivery {
  final List<ExportFile> delivered = [];
  Rect? lastOrigin;
  bool accept = true;
  String? fileToPick;

  @override
  Future<bool> deliver(ExportFile file, {Rect? sharePositionOrigin}) async {
    delivered.add(file);
    lastOrigin = sharePositionOrigin;
    return accept;
  }

  @override
  Future<String?> pickJsonFile() async => fileToPick;
}

/// A test environment plus the export service on top of it.
class ExportEnv {
  ExportEnv._(this.env, this.settings, this.delivery, this.service);

  static Future<ExportEnv> create({int? startMs}) async {
    final env = TestEnv(startMs: startMs ?? _start);
    final settings = await SettingsStore.load(env.db, clock: env.clock);
    final delivery = FakeDelivery();
    final service = ExportServiceImpl(
      history: env.history,
      backup: env.backup,
      people: env.people,
      settings: settings,
      clock: env.clock,
      delivery: delivery,
    );
    return ExportEnv._(env, settings, delivery, service);
  }

  final TestEnv env;
  final SettingsStore settings;
  final FakeDelivery delivery;
  final ExportServiceImpl service;
}

/// 11.11.2026 09:00:00 local time.
final int _start = DateTime(2026, 11, 11, 9).millisecondsSinceEpoch;

/// UTC offset of the test machine on that day, as written by the export.
final String _offset = Fmt.isoOffset(DateTime(2026, 11, 11, 9).timeZoneOffset);

String _text(ExportFile file) => utf8.decode(file.bytes);

/// The CSV text without the byte order mark.
String _csvText(ExportFile file) => utf8.decode(file.bytes.sublist(3));

List<List<dynamic>> _decode(ExportFile file, String separator) =>
    Csv(fieldDelimiter: separator, autoDetect: false).decode(_csvText(file));

/// A stopwatch run with one lap and one pause:
/// 10 min, lap, 5 min, pause 2 min, 3 min 5 s, stop.
/// Net 18:05 (1085 s), paused 120 s, 1 lap. Returns the session id.
Future<String> _stopwatchRun(TestEnv e, Track track) async {
  await e.commands.startTrack(track.id);
  e.clock.advanceMs(10 * min);
  await e.commands.lap(track.id);
  e.clock.advanceMs(5 * min);
  await e.commands.pauseTrack(track.id);
  e.clock.advanceMs(2 * min);
  await e.commands.resumeTrack(track.id);
  e.clock.advanceMs(3 * min + 5 * sec);
  return (await e.commands.stopTrack(track.id))!;
}

/// A protocol session with one entry (Alex, Wasser, "0,5 l").
Future<Track> _protocolRun(TestEnv e, TrackSet set) async {
  final track = await e.makeTrack(
    set,
    const ProtocolConfig(),
    name: 'Protokoll',
  );
  final alex = await e.people.createPerson(name: 'Alex');
  final water = await e.people.createSubstance(name: 'Wasser');
  await e.commands.addEntry(
    track.id,
    personId: alex.id,
    substanceId: water.id,
    amount: '0,5 l',
    note: 'nach dem Tanzen',
  );
  e.clock.advanceMs(min);
  await e.commands.stopTrack(track.id);
  return track;
}

void main() {
  late ExportEnv x;
  late TestEnv e;

  setUp(() async {
    x = await ExportEnv.create();
    e = x.env;
  });
  tearDown(() => e.dispose());

  group('ExportFormat.encodeCsv', () {
    test('plain fields stay unquoted, CRLF line endings, trailing CRLF', () {
      final csv = ExportFormat.encodeCsv([
        ['a', 'b', 1],
        ['c', '', 2],
      ]);
      expect(csv, 'a;b;1\r\nc;;2\r\n');
    });

    test('quotes fields with separator, quotes and line breaks', () {
      final csv = ExportFormat.encodeCsv([
        ['x;y', 'He said "hi"', 'line1\nline2', ' padded '],
      ]);
      expect(csv, '"x;y";"He said ""hi""";"line1\nline2";" padded "\r\n');
    });

    test('the separator decides what needs quoting', () {
      const row = ['0,5 l', 'a;b'];
      expect(ExportFormat.encodeCsv([row]), '0,5 l;"a;b"\r\n');
      expect(
        ExportFormat.encodeCsv([row], separator: CsvSeparator.comma),
        '"0,5 l",a;b\r\n',
      );
    });

    test('null fields are empty and no rows give an empty text', () {
      expect(
        ExportFormat.encodeCsv([
          ['a', null, 'c'],
        ]),
        'a;;c\r\n',
      );
      expect(ExportFormat.encodeCsv(const []), '');
    });

    test('umlauts survive as UTF-8 behind a byte order mark', () {
      final bytes = ExportFormat.csvBytes(
        const ['Küche'],
        const [
          ['Eichhörnchen'],
        ],
      );
      expect(bytes.sublist(0, 3), [0xEF, 0xBB, 0xBF]);
      expect(utf8.decode(bytes.sublist(3)), 'Küche\r\nEichhörnchen\r\n');
    });
  });

  group('CSV formula injection', () {
    test('text cells that would start a formula get an apostrophe', () {
      expect(ExportFormat.csvSafeText('=1+1'), "'=1+1");
      expect(ExportFormat.csvSafeText('+49 30 123'), "'+49 30 123");
      expect(ExportFormat.csvSafeText('-2 Tabletten'), "'-2 Tabletten");
      expect(ExportFormat.csvSafeText('@SUM(A1)'), "'@SUM(A1)");
      // Also behind leading blanks, tabs and line breaks.
      expect(
        ExportFormat.csvSafeText('  =HYPERLINK("x")'),
        "'  =HYPERLINK(\"x\")",
      );
      expect(ExportFormat.csvSafeText('\t=cmd'), "'\t=cmd");
      expect(ExportFormat.csvSafeText('\r\n@x'), "'\r\n@x");
      expect(ExportFormat.csvSafeText('\tTab'), "'\tTab");
    });

    test('harmless text is left alone', () {
      for (final text in [
        '',
        'Arbeit',
        '0,5 l',
        'a=b',
        'E-Mail @ home',
        '00:18:05',
        '2026-11-11T09:00:00+01:00',
        '2026-11-11T09:00:00-03:30',
        ' führendes Leerzeichen',
      ]) {
        expect(ExportFormat.csvSafeText(text), text);
      }
    });

    test('encodeCsv sanitises strings but never numbers', () {
      final csv = ExportFormat.encodeCsv([
        ['=SUMME(A1:A9)', -5, 1085, '00:18:05', '-1'],
      ]);
      expect(csv, "'=SUMME(A1:A9);-5;1085;00:18:05;'-1\r\n");
    });

    test('names, labels and notes of an export are sanitised', () async {
      final e = await ExportEnv.create();
      addTearDown(e.env.dispose);
      final set = await e.env.makeSet('=Set');
      final track = await e.env.makeTrack(
        set,
        const CounterConfig(),
        name: '@Spur',
      );
      await e.env.commands.tick(track.id, label: '+Label');
      e.env.clock.advanceMs(5 * sec);
      final sessionId = await e.env.commands.stopTrack(track.id);
      await e.env.history.updateSessionNote(sessionId!, '-Notiz');

      final sessions = _decode(
        await e.service.buildSessionsCsv(const ExportOptions()),
        ';',
      );
      expect(sessions[1][0], "'=Set");
      expect(sessions[1][1], "'@Spur");
      expect(sessions[1].last, "'-Notiz");
      // Generated columns keep their plain form.
      expect('${sessions[1][5]}', '00:00:05');
      expect('${sessions[1][6]}', '5');
      expect('${sessions[1][3]}', startsWith('2026-11-11T09:00:00'));

      final events = _decode(
        await e.service.buildEventsCsv(const ExportOptions()),
        ';',
      );
      expect(events.map((r) => r[8]), contains("'+Label"));
    });
  });

  group('ExportFormat rows (pure)', () {
    test('sessions are listed oldest first whatever the input order', () {
      HistorySession session(String id, int startedAt) {
        final log = EventLog(sessionId: id)
          ..start(startedAt)
          ..stop(startedAt + 90 * sec);
        const config = StopwatchConfig();
        return HistorySession(
          session: Session(
            id: id,
            trackId: 't1',
            config: config,
            startedAt: startedAt,
            endedAt: startedAt + 90 * sec,
          ),
          events: log.events,
          summary: summarizeSession(
            config: config,
            events: log.events,
            nowMs: startedAt + hour,
          ),
        );
      }

      final rows = ExportFormat.sessionRows([
        session('late', _start + hour),
        session('early', _start),
      ]);
      expect(rows.map((r) => r[3]), [
        Fmt.isoLocalWithOffset(_start),
        Fmt.isoLocalWithOffset(_start + hour),
      ]);
      // A track that no longer exists still gets a readable name.
      expect(rows.first[1], Strings.deletedTrack);
      expect(rows.first[0], '');
      expect(rows.first[5], '00:01:30');
      expect(rows.first[6], 90);
    });

    test('durations are hh:mm:ss and never roll over at 24 h', () {
      const config = StopwatchConfig();
      final log = EventLog()
        ..start(_start)
        ..stop(_start + 26 * hour + 3 * min + 4 * sec + 999);
      final rows = ExportFormat.sessionRows([
        HistorySession(
          session: Session(
            id: 's1',
            trackId: 't1',
            config: config,
            startedAt: _start,
            endedAt: log.events.last.at,
          ),
          events: log.events,
          summary: summarizeSession(
            config: config,
            events: log.events,
            nowMs: _start + 30 * hour,
          ),
        ),
      ]);
      expect(rows.single[5], '26:03:04');
      expect(rows.single[6], 26 * 3600 + 3 * 60 + 4);
      expect(rows.single[7], 0);
    });

    test('file names carry kind and local time stamp', () {
      final at = DateTime(2026, 11, 11, 21, 5).millisecondsSinceEpoch;
      expect(
        ExportFormat.fileName(ExportKind.sessionsCsv, at),
        'tikky-takka_sitzungen_2026-11-11_2105.csv',
      );
      expect(
        ExportFormat.fileName(ExportKind.eventsCsv, at),
        'tikky-takka_ereignisse_2026-11-11_2105.csv',
      );
      expect(
        ExportFormat.fileName(ExportKind.backupJson, at),
        'tikky-takka_sicherung_2026-11-11_2105.json',
      );
    });
  });

  group('sessions CSV', () {
    test('BOM, header, durations, pause and lap count', () async {
      final set = await e.makeSet('Büro');
      final track = await e.makeTrack(
        set,
        const StopwatchConfig(),
        name: 'Arbeit',
      );
      await _stopwatchRun(e, track);

      final file = await x.service.buildSessionsCsv(const ExportOptions());
      expect(file.mimeType, 'text/csv');
      expect(file.fileName, 'tikky-takka_sitzungen_2026-11-11_0920.csv');
      expect(file.bytes.sublist(0, 3), ExportFormat.utf8Bom);

      final lines = _csvText(file).split('\r\n');
      expect(
        lines[0],
        'Set;Spur;Art;Beginn;Ende;Dauer;Dauer (s);Pausiert (s);'
        'Runden/Anzahl;Notiz',
      );
      expect(
        lines[1],
        'Büro;Arbeit;Stoppuhr;2026-11-11T09:00:00$_offset;'
        '2026-11-11T09:20:05$_offset;'
        '00:18:05;1085;120;1;',
      );
      expect(lines[2], '', reason: 'file ends with a line ending');
      expect(lines, hasLength(3));
    });

    test('notes with separator, quotes and line breaks are escaped', () async {
      final set = await e.makeSet('Büro');
      final track = await e.makeTrack(set, const StopwatchConfig());
      final sessionId = await _stopwatchRun(e, track);
      const note = 'Er sagte "hallo"; dann\nwar Pause, kurz';
      await e.history.updateSessionNote(sessionId, note);

      final semicolon = await x.service.buildSessionsCsv(const ExportOptions());
      expect(
        _csvText(semicolon),
        contains(';"Er sagte ""hallo""; dann\nwar Pause, kurz"\r\n'),
      );
      expect(_decode(semicolon, ';')[1].last, note);

      final comma = await x.service.buildSessionsCsv(
        const ExportOptions(separator: CsvSeparator.comma),
      );
      expect(_csvText(comma), startsWith('Set,Spur,Art,Beginn,Ende,'));
      final rows = _decode(comma, ',');
      expect(rows[1], hasLength(ExportFormat.sessionsHeader.length));
      expect(rows[1].last, note);
      expect(rows[1][5], '00:18:05');
    });

    test('honours the filter (tracks, set, date range)', () async {
      final office = await e.makeSet('Büro');
      final kitchen = await e.makeSet('Küche');
      final work = await e.makeTrack(
        office,
        const StopwatchConfig(),
        name: 'Arbeit',
      );
      final tea = await e.makeTrack(
        kitchen,
        const StopwatchConfig(),
        name: 'Tee',
      );
      await _stopwatchRun(e, work);
      e.clock.advanceMs(hour);
      final secondStart = e.clock.nowMs();
      await _stopwatchRun(e, tea);

      Future<List<String>> tracksFor(HistoryFilter filter) async {
        final file = await x.service.buildSessionsCsv(
          ExportOptions(filter: filter),
        );
        return [for (final row in _decode(file, ';').skip(1)) row[1] as String];
      }

      expect(await tracksFor(HistoryFilter.all), ['Arbeit', 'Tee']);
      expect(await tracksFor(HistoryFilter(trackIds: {tea.id})), ['Tee']);
      expect(await tracksFor(HistoryFilter(setId: office.id)), ['Arbeit']);
      expect(await tracksFor(HistoryFilter(fromMs: secondStart)), ['Tee']);
      expect(await tracksFor(HistoryFilter(toMs: secondStart)), ['Arbeit']);
    });

    test('running sessions are not part of the CSV', () async {
      final set = await e.makeSet();
      final track = await e.makeTrack(set, const StopwatchConfig());
      await e.commands.startTrack(track.id);
      e.clock.advanceMs(min);
      final file = await x.service.buildSessionsCsv(const ExportOptions());
      expect(_decode(file, ';'), hasLength(1));
    });
  });

  group('events CSV', () {
    test('counter ticks: running count, lap duration and labels', () async {
      final set = await e.makeSet('Garten');
      final track = await e.makeTrack(
        set,
        const CounterConfig(labels: ['Reiher', 'Hund']),
        name: 'Tiere',
      );
      await e.commands.tick(track.id, label: 'Reiher');
      e.clock.advanceMs(30 * sec);
      await e.commands.tick(track.id, label: 'Hund');
      e.clock.advanceMs(65 * sec);
      await e.commands.tick(track.id, label: 'Reiher');
      e.clock.advanceMs(sec);
      final sessionId = (await e.commands.stopTrack(track.id))!;

      final file = await x.service.buildEventsCsv(const ExportOptions());
      expect(file.fileName, startsWith('tikky-takka_ereignisse_'));
      expect(file.bytes.sublist(0, 3), ExportFormat.utf8Bom);
      final rows = _decode(file, ';');
      expect(rows.first, ExportFormat.eventsHeader);
      expect(rows.first, [
        'Zeit',
        'Set',
        'Spur',
        'Art',
        'Sitzung',
        'Typ',
        'Laufende Nr.',
        'Rundendauer',
        'Label',
        'Person',
        'Substanz',
        'Menge',
        'Notiz',
      ]);

      final body = rows.skip(1).toList();
      expect(body.map((r) => r[5]), ['Start', 'Tipp', 'Tipp', 'Tipp', 'Stopp']);
      expect(body.map((r) => r[6]), ['', '1', '2', '3', '']);
      expect(body.map((r) => r[7]), [
        '',
        '00:00:00',
        '00:00:30',
        '00:01:05',
        '',
      ]);
      expect(body.map((r) => r[8]), ['', 'Reiher', 'Hund', 'Reiher', '']);
      expect(body[2].sublist(0, 5), [
        '2026-11-11T09:00:30$_offset',
        'Garten',
        'Tiere',
        'Zähler',
        sessionId,
      ]);
    });

    test('events of several sessions are in chronological order', () async {
      final set = await e.makeSet();
      final a = await e.makeTrack(set, const StopwatchConfig(), name: 'A');
      final b = await e.makeTrack(set, const StopwatchConfig(), name: 'B');
      await e.commands.startTrack(a.id);
      e.clock.advanceMs(min);
      await e.commands.startTrack(b.id);
      e.clock.advanceMs(min);
      await e.commands.lap(a.id);
      e.clock.advanceMs(min);
      await e.commands.stopTrack(b.id);
      e.clock.advanceMs(min);
      await e.commands.stopTrack(a.id);

      final file = await x.service.buildEventsCsv(
        const ExportOptions(separator: CsvSeparator.comma),
      );
      final body = _decode(file, ',').skip(1).toList();
      expect(body.map((r) => '${r[2]} ${r[5]}'), [
        'A Start',
        'B Start',
        'A Runde',
        'B Stopp',
        'A Stopp',
      ]);
      final times = [for (final r in body) r[0] as String];
      expect(times, [...times]..sort());
    });
  });

  group('protocol tracks', () {
    late TrackSet set;
    late Track stopwatch;
    late Track protocol;

    setUp(() async {
      set = await e.makeSet('Festival');
      stopwatch = await e.makeTrack(
        set,
        const StopwatchConfig(),
        name: 'Arbeit',
      );
      await _stopwatchRun(e, stopwatch);
      protocol = await _protocolRun(e, set);
    });

    test('are excluded from both CSV files by default', () async {
      final sessions = await x.service.buildSessionsCsv(const ExportOptions());
      final events = await x.service.buildEventsCsv(const ExportOptions());
      for (final file in [sessions, events]) {
        final text = _csvText(file);
        expect(text, isNot(contains('Protokoll')));
        expect(text, isNot(contains('Alex')));
        expect(text, isNot(contains('Wasser')));
        expect(text, isNot(contains('0,5 l')));
        expect(text, isNot(contains('nach dem Tanzen')));
        expect(text, contains('Arbeit'));
      }
    });

    test('stay excluded even when the filter names the track', () async {
      final options = ExportOptions(
        filter: HistoryFilter(trackIds: {protocol.id}),
      );
      expect(
        _decode(await x.service.buildSessionsCsv(options), ';'),
        hasLength(1),
      );
      expect(
        _decode(await x.service.buildEventsCsv(options), ';'),
        hasLength(1),
      );
      final backup = jsonDecode(
        _text(await x.service.buildJsonBackup(options)),
      );
      expect((backup as Map)['sessions'], isEmpty);
      expect(backup['events'], isEmpty);
    });

    test('are included in the CSV files with the explicit opt-in', () async {
      const options = ExportOptions(includeProtocol: true);
      final sessions = _decode(await x.service.buildSessionsCsv(options), ';');
      expect(sessions.skip(1).map((r) => r[1]), ['Arbeit', 'Protokoll']);
      expect(sessions[2][2], 'Protokoll');
      expect(sessions[2][8], '1', reason: 'one entry');

      final events = _decode(await x.service.buildEventsCsv(options), ';');
      final entry = events.singleWhere((r) => r[5] == 'Eintrag');
      expect(entry.sublist(6), [
        '1',
        '',
        '',
        'Alex',
        'Wasser',
        '0,5 l',
        'nach dem Tanzen',
      ]);
    });

    test('are excluded from the JSON backup by default', () async {
      final file = await x.service.buildJsonBackup(const ExportOptions());
      final json = jsonDecode(_text(file)) as Map<String, dynamic>;
      expect((json['tracks'] as List).map((t) => (t as Map)['id']), [
        stopwatch.id,
      ]);
      expect(json['persons'], isEmpty);
      expect(json['substances'], isEmpty);
      expect((json['sessions'] as List).map((s) => (s as Map)['trackId']), [
        stopwatch.id,
      ]);
      expect(
        (json['events'] as List).map((ev) => (ev as Map)['type']),
        isNot(contains('entry')),
      );
      expect(_text(file), isNot(contains('Alex')));
      expect(_text(file), isNot(contains('Wasser')));
    });

    test('are included in the JSON backup with the explicit opt-in', () async {
      final file = await x.service.buildJsonBackup(
        const ExportOptions(includeProtocol: true),
      );
      final json = jsonDecode(_text(file)) as Map<String, dynamic>;
      expect(json['tracks'], hasLength(2));
      expect(json['persons'], hasLength(1));
      expect(json['substances'], hasLength(1));
      expect(json['sessions'], hasLength(2));
      expect(
        (json['events'] as List).map((ev) => (ev as Map)['type']),
        contains('entry'),
      );
    });
  });

  group('JSON backup', () {
    test('is UTF-8 JSON without BOM, with app id and schema version', () async {
      await e.sets.ensureSeedData();
      final file = await x.service.buildJsonBackup(const ExportOptions());
      expect(file.mimeType, 'application/json');
      expect(file.fileName, 'tikky-takka_sicherung_2026-11-11_0900.json');
      expect(file.bytes.first, '{'.codeUnitAt(0));
      final json = jsonDecode(_text(file)) as Map<String, dynamic>;
      expect(json['app'], BackupData.appId);
      expect(json['schemaVersion'], BackupData.currentSchemaVersion);
      expect(json['exportedAt'], _start);
      expect(json['sets'], hasLength(1));
      expect(json['tracks'], hasLength(3));
      expect(json['settings'], isA<Map<String, dynamic>>());
    });

    /// Entity lists of a database as comparable JSON, sorted by id.
    Future<Map<String, List<String>>> dump(TestEnv env) async {
      final data = await env.backup.readAll(includeProtocol: true);
      List<String> sorted(Iterable<Map<String, Object?>> items) =>
          [for (final item in items) jsonEncode(item)]..sort();
      return {
        'sets': sorted(data.sets.map((s) => s.toJson())),
        'tracks': sorted(data.tracks.map((t) => t.toJson())),
        'sessions': sorted(data.sessions.map((s) => s.toJson())),
        'events': sorted(data.events.map((ev) => ev.toJson())),
        'persons': sorted(data.persons.map((p) => p.toJson())),
        'substances': sorted(data.substances.map((s) => s.toJson())),
      };
    }

    test('export -> import round trip restores everything', () async {
      final set = await e.makeSet('Festival');
      final stopwatch = await e.makeTrack(
        set,
        const StopwatchConfig(exclusive: true),
        name: 'Arbeit',
      );
      final sessionId = await _stopwatchRun(e, stopwatch);
      await e.history.updateSessionNote(sessionId, 'Notiz mit "Zitat"; ä ö ü');
      final counter = await e.makeTrack(
        set,
        const CounterConfig(labels: ['Eichhörnchen']),
        name: 'Zähler',
      );
      await e.commands.tick(counter.id, label: 'Eichhörnchen');
      await e.commands.stopTrack(counter.id);
      await _protocolRun(e, set);
      // A timer that is still running is part of a backup, too.
      final timer = await e.makeTrack(
        set,
        const CountdownConfig(durationMs: 10 * min),
        name: 'Timer',
      );
      await e.commands.startTrack(timer.id);
      await x.settings.setString('test.custom', 'wert');

      final file = await x.service.buildJsonBackup(
        const ExportOptions(includeProtocol: true),
      );

      final y = await ExportEnv.create(startMs: _start + 24 * hour);
      addTearDown(y.env.dispose);
      final report = await y.service.importJsonBackup(_text(file));

      expect(report.inserted['sets'], 1);
      expect(report.inserted['tracks'], 4);
      expect(report.inserted['sessions'], 4);
      expect(report.inserted['persons'], 1);
      expect(report.inserted['substances'], 1);
      expect(report.updatedTotal, 0);
      expect(await dump(y.env), await dump(e));

      // The in-memory settings were refreshed after the merge.
      expect(y.settings.getString('test.custom'), 'wert');

      // The running timer keeps running in the restored database.
      expect(await y.env.commands.getOpenSession(timer.id), isNotNull);

      // The derived figures are the same, too.
      final sessions = await y.service.buildSessionsCsv(
        const ExportOptions(includeProtocol: true),
      );
      expect(
        _csvText(sessions),
        _csvText(
          await x.service.buildSessionsCsv(
            const ExportOptions(includeProtocol: true),
          ),
        ),
      );
    });

    test('importing twice adds nothing and destroys nothing', () async {
      final set = await e.makeSet('Büro');
      final track = await e.makeTrack(set, const StopwatchConfig());
      await _stopwatchRun(e, track);
      final json = _text(
        await x.service.buildJsonBackup(const ExportOptions()),
      );

      final y = await ExportEnv.create(startMs: _start + 24 * hour);
      addTearDown(y.env.dispose);
      // Data that only exists locally must survive every import. The test
      // ids are sequential per environment: skip the ones the backup uses.
      for (var i = 0; i < 100; i++) {
        y.env.newId();
      }
      final localSet = await y.env.makeSet('Nur hier');
      final localTrack = await y.env.makeTrack(
        localSet,
        const StopwatchConfig(),
        name: 'Lokal',
      );
      await _stopwatchRun(y.env, localTrack);

      final first = await y.service.importJsonBackup(json);
      expect(first.inserted['sets'], 1);
      final afterFirst = await dump(y.env);

      final second = await y.service.importJsonBackup(json);
      expect(second.insertedTotal, 0);
      expect(second.updatedTotal, 0);
      expect(second.skipped['sets'], 1);
      expect(second.skipped['tracks'], 1);
      expect(second.skipped['sessions'], 1);
      expect(await dump(y.env), afterFirst);

      expect(
        (await y.env.sets.getSets()).map((s) => s.name),
        unorderedEquals(['Nur hier', 'Büro']),
      );
      expect(await y.env.history.getSessions(HistoryFilter.all), hasLength(2));
    });

    test('newer local changes win over an older backup', () async {
      final set = await e.makeSet('Alt');
      final json = _text(
        await x.service.buildJsonBackup(const ExportOptions()),
      );
      e.clock.advanceMs(min);
      await e.sets.renameSet(set.id, 'Neu');

      final report = await x.service.importJsonBackup(json);
      expect(report.updatedTotal, 0);
      expect((await e.sets.getSet(set.id))!.name, 'Neu');
    });

    test('a byte order mark in front of the JSON is tolerated', () async {
      await e.makeSet('Büro');
      final json = _text(
        await x.service.buildJsonBackup(const ExportOptions()),
      );
      final y = await ExportEnv.create();
      addTearDown(y.env.dispose);
      final report = await y.service.importJsonBackup('\u{FEFF}$json');
      expect(report.inserted['sets'], 1);
    });

    test('rejects files that are not a backup', () async {
      await e.makeSet('Büro');
      for (final source in [
        '',
        'kein json',
        '[]',
        '"text"',
        '{}',
        '{"app":"something_else","schemaVersion":1}',
        '{"app":"tikky_takka","schemaVersion":999}',
        'Set;Spur;Art\r\n',
      ]) {
        await expectLater(
          x.service.importJsonBackup(source),
          throwsFormatException,
          reason: source,
        );
      }
      // Nothing was touched.
      expect((await e.sets.getSets()).map((s) => s.name), ['Büro']);
    });
  });

  group('delivery', () {
    test('deliver and pick go through the delivery, unchanged', () async {
      final file = ExportFile(
        fileName: 'a.csv',
        mimeType: 'text/csv',
        bytes: Uint8List.fromList([1, 2, 3]),
      );
      const origin = Rect.fromLTWH(1, 2, 3, 4);
      expect(await x.service.deliver(file, sharePositionOrigin: origin), true);
      expect(x.delivery.delivered.single, same(file));
      expect(x.delivery.lastOrigin, origin);

      x.delivery.accept = false;
      expect(await x.service.deliver(file), false);

      expect(await x.service.pickJsonFile(), isNull);
      x.delivery.fileToPick = '{}';
      expect(await x.service.pickJsonFile(), '{}');
    });

    test('the default service is a placeholder that throws', () {
      const service = UnimplementedExportService();
      expect(
        () => service.buildSessionsCsv(const ExportOptions()),
        throwsUnimplementedError,
      );
      expect(service.pickJsonFile, throwsUnimplementedError);
    });
  });
}
