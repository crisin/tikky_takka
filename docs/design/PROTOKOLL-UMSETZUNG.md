# Protokoll – Arbeitspakete

Stand: 24.11.2026. Setzt `PROTOKOLL.md` um (P1–P6 dort entschieden). Die
Pakete heißen B1–B8, damit sie sich nicht mit P1–P9 aus `UMSETZUNG.md` und
den Entscheidungen P1–P6 überschneiden.

**Alle acht Pakete sind gebaut** (Zweig `protokoll`, ein Commit je Paket).
Gebaut wurde in der Reihenfolge B1, B2, B3, B5, B4, B6, B7, B8. Was vom Plan
unten abweicht, steht im nächsten Abschnitt; die Paket-Beschreibungen
darunter sind der ursprüngliche Plan.

## Stand und Abweichungen

| Paket | Stand | Anders als geplant |
|---|---|---|
| B1 | gebaut | – |
| B2 | gebaut | Das Tippfeld hatte den Weg Person → „Was?“ → „Anderes“ schon; er wurde von der Protokoll-Spur auf Szene und `entries` umgehängt. `tap_pad.dart` ist nicht aufgeteilt worden. |
| B3 | gebaut | Enthält schon das Entfernen von Protokoll-Spur, Formular und Sitzungsliste (im Plan B8), weil das Blatt sonst zwei Arten von Einträgen hätte kennen müssen. |
| B4 | gebaut | „Protokoll starten“ nur im Set ohne Spuren; „Rückgängig“ beim Entfernen steht in der Szene. Die Listen-Seite ist weg, die Editoren liegen in `protocol_editors.dart`. |
| B5 | gebaut | Die Zeitleiste ist **nicht** umgeschrieben. Die Einträge kommen als eine Spur „Protokoll“ mit einer offenen Sitzung an (`lib/core/engine/protocol_lane.dart`), gebildet aus `entries`; gespeichert wird davon nichts. Streifen, Abend, Woche und Monat arbeiten darauf unverändert. |
| B6 | gebaut | In der Zeitleiste stehen die Sachen vorn in der bestehenden Filter-Reihe statt in einer eigenen. |
| B7 | gebaut | Einträge stehen in der Liste der Ereignisse, nicht in der Liste der Sitzungen. |
| B8 | gebaut | `TrackMode.protocol` und `ProtocolConfig` **bleiben**: als Art der Spur „Protokoll“ in Zeitleiste und Export. Alte Protokoll-Spuren löscht kein Schema-Schritt, sondern `purgeProtocolTracks()` beim Start. `schemaVersion` ist 2 (nur die neue Tabelle). |

**Nicht geprüft:** ein echtes Gerät, die Ansicht bei 375 × 812 (im Browser
nur in der breiten Ansicht durchgeklickt), iOS/Cupertino über die
vorhandenen Widget-Tests hinaus, große Systemschrift auf dem Brett.

**Offen geblieben:** `lib/features/history/` (der alte Verlauf) existiert
weiter. In der Rechnung (`derive.dart`, `snapshots.dart`, `summary.dart`)
stehen die Protokoll-Zweige noch, weil die Spur „Protokoll“ sie für
Zeitleiste und Export braucht.

Reihenfolge so, dass die App nach jedem Paket läuft und `flutter analyze`
und `flutter test` sauber sind. Die Dateiangaben stammen aus einer Suche im
Stand vom 24.11.2026, nicht aus einem vollständigen Durchlesen; vor dem
Start eines Pakets nachsehen, ob sie stimmen. Die Grundsätze aus
`UMSETZUNG.md` gelten weiter (Tokens, Muss-Regeln, Tests mitziehen).

**Übergang:** Bis B8 liegen alte Protokoll-Spuren (in `events`) und neue
Einträge (in `entries`) nebeneinander. Das Brett schreibt ab B2 nur noch neue
Einträge; die Zeitleiste zeigt sie erst ab B5. Alte Einträge werden in B8
gelöscht (P4).

**Kein neuer Entwurf:** Es gibt keine gezeichnete Vorlage. Maße und Aussehen
kommen aus den bestehenden Entwürfen, auf die jedes Paket verweist.

| Paket | Inhalt | Größe |
|---|---|---|
| B1 | Tabelle, Repository und Rechnung für Einträge | mittel |
| B2 | Brett und „Was?“ im Tippfeld | groß |
| B3 | „Ändern“ und „Anderes“ auf Einträgen | mittel |
| B4 | Szene als einziger Ort, erster Start | mittel |
| B5 | Zeitleiste rechnet aus Einträgen | groß |
| B6 | Filter | klein |
| B7 | Export und Sicherung | klein |
| B8 | Altes entfernen | mittel |

## B1 · Einträge speichern und rechnen

Nichts an der Oberfläche ändert sich.

- `lib/core/db/tables.dart`: neue Tabelle `Entries` (`entries`): `id`, `at`,
  `personId`, `substanceId`, `amount`, `note`, `createdAt`, `updatedAt`,
  `extraJson`. Indizes auf `at`, (`personId`, `at`) und `substanceId`.
  `personId` und `substanceId` sind Pflicht („Ohne Person“ entfällt).
- `lib/core/db/app_database.dart`: Tabelle aufnehmen, `schemaVersion` 2,
  Schritt 1 → 2 legt nur `entries` an. Danach `build_runner`.
- `lib/core/domain/`: neuer Typ `Entry` (eigene Datei), in `domain.dart`
  ausführen.
- `lib/core/repo/`: neues `EntryRepository` (anlegen, ändern, löschen,
  wiederherstellen für Rückgängig; beobachten nach Zeitraum, nach Person;
  letzter Eintrag je Person und Sache). Provider in `providers.dart`.
- `lib/core/engine/`: neue Datei mit reinen Funktionen auf `Entry`: Stand je
  Person (maßgeblicher Eintrag, Zeit seitdem), laufende Abstände (Vorlage:
  `deriveLockouts` in `derive.dart`, `LockoutStatus` in `snapshots.dart`),
  Anzahl je Sache am logischen Tag (`logical_day.dart`), Kette einer Sache.
- `lib/core/services/dev/app_reset.dart`: `entries` in `counts()` und
  `wipe()` aufnehmen; Zeile „Einträge“ auf der Entwickler-Seite.

Fertig, wenn: Tests zeigen, dass ein Abstand über den Tageswechsel und
unabhängig vom Set weiterläuft, dass die Anzahl am Tagesbeginn (06:00) neu
zählt, und dass Löschen und Wiederherstellen denselben Eintrag ergeben.

## B2 · Brett und „Was?“

Vorlage: `PROTOKOLL.md` 4 und 5. Aussehen der Kachel aus `3-1-jetzt` (Karte
je Person), „Was?“ aus `2-2-was`, Bestätigung aus `2-3-eingetragen`.

- `lib/features/tracks/pad/pad_model.dart`: Personen kommen aus der Szene des
  Sets, nicht mehr aus Protokoll-Spuren. `PadButton.person` / `.substance` /
  `.other` verlieren die Spur. `buildSubstancePad` nimmt die Sachen der Szene
  in deren Reihenfolge; `topSubstanceIds` und das Platzhalten entfallen hier.
- `lib/features/tracks/pad/tap_pad.dart` (1628 Zeilen): die Personen-Kacheln
  und die Seite „Was?“ in eigene Dateien unter `lib/features/protocol/`
  auslagern (Brett, Was?). Kachel: Kürzel, Name, große Zeit, Zeile darunter;
  mindestens 72 hoch; feste Plätze. Eine Person in der Szene: das Tippfeld
  zeigt gleich ihre Sachen.
- `lib/features/tracks/pad/pad_actions.dart`: Eintragen schreibt über
  `EntryRepository`; Rückgängig löscht den Eintrag wieder.
- „Was?“: Zeile „zuletzt Bier · vor 26 min ›“ unter dem Namen (öffnet in B3
  „Ändern“, bis dahin ohne Tipp). Nach dem Tipp etwa 900 ms
  (`captureConfirm`) Bestätigung und zurück zum Brett; dasselbe Feld löst in
  dieser Zeit nicht erneut aus.
- Feste Leiste oben: „Krille · Bier · 23:41“ mit „Rückgängig“; „Ändern“
  kommt in B3.
- Anzahl auf den Feldern nur mit dem Schalter aus O5 (Standard aus).
- Tests: `test/features/tracks/pad/`, `test/features/protocol/
  protocol_capture_test.dart`, `capture_logic_test.dart`.

Fertig, wenn: mit zwei Personen und vier Sachen in der Szene zwei Tipps einen
Eintrag in `entries` schreiben, die Kachel danach „0:0x seit …“ zeigt, ein
Doppeltipp nur einen Eintrag ergibt und „Rückgängig“ ihn entfernt. Im
Web-Build bei 375 × 812 neben `3-1-jetzt` und `2-2-was` angesehen.

## B3 · „Ändern“ und „Anderes“

Vorlage: `PROTOKOLL.md` 6 und 7; Entwürfe `2-4-aendern`,
`2-5-aendern-aufgeklappt`, `3-5-eintrag`, `2-6-anderes`.

- `lib/features/protocol/entry_edit_sheet.dart`: arbeitet auf `Entry` statt
  `TrackEvent`. „Wer“ ohne „Ohne Person“. Frühere Mengen kommen aus den
  Einträgen dieser Sache.
- `lib/features/protocol/protocol_entry_sheet.dart`: entfällt (Formular für
  neue Einträge). Aufrufer umstellen.
- „Ändern“ erreichbar aus der Leiste, aus der Zeile „zuletzt …“ und per
  langem Druck auf ein Feld (trägt ein, öffnet dann das Blatt).
- „Anderes“: übrige Sachen, zuerst die häufigsten dieser Person (hier lebt
  die Häufigkeit weiter); „Neu anlegen“ mit Namensfeld. Eine so eingetragene
  Sache kommt nicht von selbst in die Szene.
- Tests: `test/features/protocol/protocol_entry_flow_test.dart`.

Fertig, wenn: ein eben getippter Eintrag über „Ändern“ auf „−10 min“, eine
andere Person und eine Menge gesetzt werden kann, jede Änderung sofort
gespeichert ist und „Löschen“ Rückgängig anbietet.

## B4 · Szene und erster Start

Vorlage: `PROTOKOLL.md` 8 und 9; Entwürfe `2-7-sets-und-szene`,
`1-1-leerer-start`.

- `lib/features/tracks/set_switcher.dart`,
  `lib/features/protocol/protocol_scene_sheet.dart`: die Szene nur noch in
  „Sets und Szene“; das eigene Szene-Blatt entfällt. „+ Neu“ am Ende jeder
  Reihe. Langer Druck auf einen Knopf öffnet Name, Farbe, bei Sachen den
  Abstand, „Entfernen“ mit Rückgängig (Editoren aus
  `protocol_people_screen.dart` übernehmen).
- `lib/features/protocol/protocol_people_screen.dart`: die Seite mit den zwei
  Listen entfällt. `lib/features/settings/settings_screen.dart`,
  `settings_hooks.dart`, `lib/app_wiring.dart`: die Zeilen „Personen“ und
  „Substanzen“ und ihre Haken entfernen.
- `lib/features/tracks/tracks_screen.dart`: leerer Start mit zwei Wegen –
  „Protokoll“ (Wer ist dabei? → Was ist dran? → Brett) und „Spur anlegen“
  (fünf Arten).
- `lib/features/tracks/tracks_view.dart`: der zuletzt offene Reiter wird je
  Set gemerkt.
- Tests: `test/core/repo/scene_test.dart`,
  `test/features/protocol/protocol_scene_test.dart`,
  `test/features/settings/settings_screen_test.dart`.

Fertig, wenn: nach „App zurücksetzen“ der Weg „Protokoll“ ohne Umweg über
die Einstellungen zum ersten Eintrag führt und die App danach im Tippfeld
öffnet.

## B5 · Zeitleiste aus Einträgen

Vorlage: `PROTOKOLL.md` 10; Entwürfe `3-1-jetzt` bis `3-5-eintrag`.

- `lib/features/tracks/timeline/strip/strip_model.dart` (1382 Zeilen),
  `strip_view.dart`: Personen und ihre Zeilen je Sache kommen aus `entries`.
  Tipp auf den Namen springt zum Brett.
- `lib/features/tracks/timeline/person_cards.dart`: entfällt aus „Jetzt“.
- `lib/features/tracks/timeline/evening/evening_layout.dart`,
  `evening_view.dart`: Spalten je Person aus Einträgen des logischen Tags;
  „Kompakt“ ist die Liste aller Einträge.
- `lib/core/engine/period_counts.dart`,
  `lib/features/tracks/timeline/period/`: Woche und Monat zählen Einträge.
- `lib/features/tracks/timeline/timeline_event_sheet.dart`: Einträge öffnen
  das Blatt aus B3; das Ereignisblatt bleibt für Spuren.
- `lib/features/tracks/timeline/timeline_logic.dart`: Personen-Filter auf
  Einträge.
- Tests: `test/features/tracks/timeline/` (Streifen, Abend, Woche, Monat).

Fertig, wenn: ein Eintrag vom Brett in allen vier Stufen erscheint, das
Antippen dort „Ändern“ öffnet und die Zahlen mit den Kacheln übereinstimmen.

## B6 · Filter

Vorlage: `PROTOKOLL.md` 4 („Filter“); Aussehen der Reihe aus `3-4-monat`
(„Was zählen“).

- Ein gemeinsamer Zustand „gewählte Sache“ (Provider, je Set, nur im
  Speicher). Reihe „Alles · Sachen der Szene“ über den Kacheln, 48 hoch,
  scrollt seitlich.
- Brett: Kacheln zeigen bei gesetztem Filter Zeit, Anzahl und Abstand nur für
  diese Sache, sonst „–“. Plätze bleiben. Ein Tipp öffnet weiter „Was?“ (P6).
- Zeitleiste: derselbe Zustand in allen vier Stufen; der Monat nutzt ihn
  statt seiner eigenen Auswahl.

Fertig, wenn: „Bier“ auf dem Brett gewählt auch im Monat gewählt ist, und
ein Test belegt, dass der Filter nie einen Eintrag schreibt.

## B7 · Export und Sicherung

- `lib/core/services/export_service.dart`, `export_service_impl.dart`,
  `lib/features/history/export_sheet.dart`: Einträge als eigene CSV (Zeit,
  Person, Sache, Menge, Notiz). Der Schalter „Protokoll einschließen“ bleibt
  ein ausdrückliches Ja, Standard aus.
- `lib/core/repo/backup_repository.dart`: `entries` in Sicherung und Import
  (Zusammenführen nach `id`). Protokoll-Spuren aus alten Sicherungen werden
  beim Import übersprungen.
- Tests: `test/core/services/export_service_test.dart`,
  `test/features/history/export_sheet_test.dart`.

Fertig, wenn: Sichern, Zurücksetzen und Importieren dieselben Einträge
ergibt und eine alte Sicherung mit Protokoll-Spur ohne Fehler importiert.

## B8 · Altes entfernen

- `lib/core/domain/enums.dart`, `track_config.dart`: `TrackMode.protocol` und
  `ProtocolConfig` entfernen. Unbekannte Arten in gespeicherten Zeilen dürfen
  die App nicht stürzen lassen.
- `lib/core/db/app_database.dart`: `schemaVersion` 3; der Schritt löscht
  Spuren der Art `protocol` samt Sitzungen und Ereignissen. `events` verliert
  nichts an Spalten (`personId` und `substanceId` bleiben ungenutzt stehen).
- Entfällt: `lib/features/protocol/protocol_lane.dart`,
  `protocol_session_screen.dart`, die Sitzungs-Teile von
  `protocol_logic.dart`; Protokoll-Zweige in `tracks_screen.dart`,
  `track_editor_sheet.dart` (sechste Art), `derive.dart`, `snapshots.dart`,
  `summary.dart`, `track_commands.dart`, `history_repository.dart`,
  `lib/features/history/`.
- Tests der alten Wege entfernen oder umstellen
  (`protocol_lane_test.dart`, `lockout_across_sessions_test.dart`,
  `reminder_protocol_test.dart`, `track_lanes_test.dart`).
- Dokumente: `FLOWS.md` (1.1, 1.2, 2.x, 3.1), `README.md`,
  `docs/ideen/BACKLOG.md`, `CLAUDE.md` („Protokoll“ ist keine Spurart mehr),
  `docs/GERAETETEST.md`.

Fertig, wenn: eine Suche nach `TrackMode.protocol` nichts mehr findet und
eine Datenbank mit alter Protokoll-Spur nach dem Update ohne diese Spur
startet.

## Was offen bleibt

- **Kein Entwurf.** Wie viele Kacheln bei 375 × 812 lesbar bleiben und ob die
  Filter-Reihe im Dunkeln versehentlich getroffen wird, zeigt sich erst in B2
  und B6 am Gerät.
- **Ampel (O6)** ist nicht Teil dieser Pakete.
- **Verlauf:** `lib/features/history/` gibt es noch, obwohl der Verlauf laut
  `FLOWS.md` in der Zeitleiste aufgeht. B8 entfernt dort nur die
  Protokoll-Teile.
