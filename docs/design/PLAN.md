# Implementierungsplan „Pult“

Stand: 14.11.2026. Baut auf `UMSETZUNG.md` (Pakete P1–P9) auf und macht daraus
einzelne Schritte. Jeder Schritt ist ein Commit, nach dem `flutter analyze` und
`flutter test` sauber sind und die App läuft. Die Angaben zum Code sind gegen
den Stand von heute geprüft; Abweichungen von `UMSETZUNG.md` stehen in
Abschnitt 2.

## 1. Etappen

| Etappe | Pakete | Ergebnis | Wartet auf |
|---|---|---|---|
| **0 Vorbereitung** | – | sauberer Arbeitsstand, Schriftfrage für Ziffern geklärt | E1, O4 (nur Martian Mono) |
| **A Pult sichtbar** | P1 → P2 → P3 → P4 | Spuren als Flächen, untere Leiste, Erfassen in Stufen | O5, E2, E3 |
| **B Zeitleiste** | P5 → P6 | Jetzt mit Falten, Abend / Woche / Monat, Verlauf entfällt | O1, O2, O3, E4 |
| **C Einstellungen und Designs** | P7 → P8 | feste Reiter, sieben Designs mit Bewegung | O4 (übrige Schriften) |
| **D Rest** | P9 | leerer Start, Neue Spur, Fokus | O7 |

A zuerst, weil es ohne offene Grundsatzfragen baubar ist und den größten
sichtbaren Unterschied macht. B und C hängen nicht voneinander ab; P9 kann
jederzeit nach P3 kommen.

## 2. Was der Abgleich mit dem Code ergeben hat

Diese Punkte ändern den Zuschnitt gegenüber `UMSETZUNG.md`:

1. **Radien hängen heute an einem Wert.** `TikkyRadii` rechnet sm / md / lg aus
   `cornerRadius` 12. Die Entwürfe brauchen schon in P2 getrennte Radien
   (Spur 20, Feld 22, klein 14, Blatt 28). Die Rollen-Radien kommen deshalb in
   P1, zunächst aus `cornerRadius` gerechnet; P8 macht sie je Design einstellbar.
2. **Die Ziffernschrift ist Teil von P2, nicht erst von P8.** Schwarz, Dunkel
   und Hell zeigen Martian Mono; gebündelt ist heute keine Schrift
   (`pubspec.yaml` hat weder `fonts:` noch `assets:`). Ohne Martian Mono sieht
   P2 nicht wie der Entwurf aus. O4 wird deshalb geteilt: Martian Mono vor
   Etappe A, die drei anderen vor P8.
3. **`tokens.json` kennt zwei Farben, die `UMSETZUNG.md` nicht nennt:**
   `onDanger` (Schrift auf der klingelnden Spur) und `segment` (gewählter
   Reiter in der Zeitleisten-Pille). Beide kommen mit `warningText` in P1.
4. **Die Palette ist nicht fest zehn Farben.** Sie ist im Editor änderbar, und
   Spuren können eine eigene Farbe haben. `roles(Color)` muss für jede Farbe
   rechnen; der Test gegen `tokens.json` deckt nur die zehn Vorlagenfarben ab.
5. **Stoppen ist heute ein eigener Nebenknopf an jeder Spur** (Zurücksetzen bzw.
   Stopp), langer Druck öffnet Bearbeiten. Der Entwurf zeigt nur einen
   Nebenknopf. Wohin Stoppen wandert, ist eine Entscheidung (E2).
6. **Das Tippfeld hat weder Dock noch Zeit-Knöpfe**, und die 900-ms-Bestätigung
   sitzt in der Protokoll-Spur, nicht im Tippfeld (das kehrt sofort zurück).
   `_PersonPage` ist nur ein Datensatz. P4 baut also eine neue Seite „Was?“ und
   zieht die Bestätigung um, statt Bestehendes abzubauen.
7. **Für „Wie viel?“ ist nichts Neues nötig:** `recentAmounts` gibt es schon,
   und `InlineUndoBar` hat schon einen zweiten Knopf. Es fehlt nur der Balken
   für die Restzeit.
8. **„Anzahl heute“ gibt es nicht.** `sessionCounts` zählt die offene Sitzung.
   Was „heute“ heißt, hängt an O3; bis dahin bleibt die Anzahl die der offenen
   Sitzung.
9. **Falten brauchen mehr als `StripViewport`.** `layoutStrip` und `computeAxis`
   rechnen Zeit → x selbst aus `(startMs, msPerPx)`; Bündelung und Ausblenden
   rechnen in Millisekunden. P5 beginnt deshalb mit einem Umbau ohne sichtbare
   Änderung.
10. **„Tag beginnt um“ wird in P6 gebraucht**, steht aber in P7. Das Feld und
    die Rechnung kommen an den Anfang von P6; P7 liefert nur die Zeile dazu.
11. **Der Export liest seinen Zeitraum aus `historyFilterProvider`** und hat
    keinen Parameter dafür. Der muss dazu, bevor der Verlauf verschwindet.
12. **Schon erledigt:** `ContrastWarning` nennt bereits jedes durchgefallene
    Paar; `openTimelineEvent` schickt Protokoll-Einträge bereits ans
    Eintragsblatt.
13. **`ShellDestination` wird nicht gespeichert**, kann also frei umgebaut
    werden. `TracksView` und `TimelineMode` werden gespeichert und bleiben.

## 3. Entscheidungen, die anstehen

Offene Punkte O1–O7 stehen in `README.md`. Dazu kommen vier, die erst beim
Abgleich aufgefallen sind. Die Spalte „Vorschlag“ ist nur ein Vorschlag.

| Nr. | Frage | Vorschlag | Gebraucht vor |
|---|---|---|---|
| E1 | Im Arbeitsstand liegen ungesicherte Änderungen (Alarme, Diagnose, App-Icon, die Design-Dokumente). Vor dem Umbau committen? | ja, als eigene Commits | Etappe 0 |
| O4a | Martian Mono bündeln (Lizenztext lesen, Tabellenziffern prüfen)? | ja | P2 |
| O5 | Anzahl (×3) auf den Feldern immer sichtbar? | immer, wie gezeichnet | P4 |
| E2 | Wo liegt Stoppen, wenn es nur einen Nebenknopf gibt? | langer Druck auf den **Hauptknopf** und der Stopp-Knopf im Zustand „pausiert“; langer Druck auf die Fläche bleibt Bearbeiten. Für Zähler und Erinnerung (kein „pausiert“) zusätzlich „Stoppen“ im Bearbeiten-Blatt und als Aktion für Screenreader | P2 |
| E3 | Die untere Leiste ab 720 px Breite: Seitenleiste mit Spuren / Tippfeld / Zeitleiste und Einstellungen darunter? | ja | P3 |
| O7 | Tippen auf die Spur öffnet den Fokus? | ja; bis P9 tut Tippen nichts | P9 |
| O1 | Abend senkrecht? | – | P6 |
| O2 | Liste und Zusammenfassung gehen in „Kompakt“ und den Summen auf? | – | P6 |
| O3 | „Tag beginnt um 06:00“? | – | P6 |
| E4 | Trefferflächen unter 48: Wochenzeilen 48 statt 42, Kalenderzellen 48 statt 46, Chips im Abend mit 48er Trefferfläche und Wahl des nächstliegenden? | ja | P6 |
| O4b | Space Mono, Silkscreen, Fredoka bündeln? | nach Prüfung der Ziffernbreite je Schrift | P8 |
| O6 | Ampel pro Person | bleibt draußen | – |

## 4. Schritte

Schreibweise: **P2.3** = dritter Schritt in Paket 2. „Test“ nennt, was neu oder
angepasst grün sein muss. Nach jedem Paket: Web-Build bei 375 × 812 neben den
genannten Entwurf legen.

### Etappe 0 · Vorbereitung

- **0.1** Offenen Arbeitsstand committen (E1).
- **0.2** Martian Mono: Lizenztext lesen, Datei und Lizenz nach `assets/fonts/`,
  `flutter: fonts:` in `pubspec.yaml`, `TikkyFonts` um die Familie ergänzen,
  noch nirgends verwenden. Prüfen, dass `0`–`9`, `:` und `+` gleich breit sind
  (Test misst die Breiten mit `TextPainter`).

### P1 · Farbrollen und Tokens

- **P1.1** `TikkyColors` um `warningText`, `onDanger`, `segment`; `fromJson`
  füllt Fehlendes aus der Vorlage. Vorlagen in `theme_presets.dart` auf die
  Werte aus `tokens.json` (auch `textMuted`).
  Test: `theme_test.dart` liest ein altes gespeichertes Design ohne die Felder.
- **P1.2** Neu `lib/theme/track_roles.dart`: `TrackRoles {solid, tint, strong,
  ink, on}` und die reine Funktion `trackRolesFor(Color, background, isDark)`
  nach `DESIGNS.md` Abschnitt 2 (Mischung 18 / 34 % bzw. 14 / 28 %, `ink` in
  1-%-Schritten bis 4,6:1 gegen `strong`). `contrastRatio` zieht dafür von
  `features/settings/contrast.dart` nach `lib/theme/`.
  Test: liest `docs/design/tokens.json` und vergleicht alle zehn Farben in
  Schwarz, Dunkel und Hell auf den Hex-Wert.
- **P1.3** `TikkyTokens.roles(Color)` und `trackRoles(Track)` mit Zwischen-
  speicher je Design. `ContrastPair` um `inkOnTint`, `inkOnStrong`,
  `onOnSolid`, `textOnStrong`, `warningTextOnTint`; `contrastIssues` prüft sie
  für jede Palettenfarbe.
  Test: kein Paar unter 4,5 in den drei Vorlagen; `contrast_color_test.dart`.
- **P1.4** Maße: `TikkyRadii` bekommt `lane`, `pad`, `small`, `sheet`, `pill`
  (aus `cornerRadius`: × 20/12, 22/12, 14/12, 28/12). `TikkySizes` bekommt
  `laneHeightActive` 101, `laneHeightIdle` 66, `primaryButton` 60,
  `primaryButtonIdle` 48, `secondaryButton` 48, `digitsLarge` 32,
  `digitsMedium` 22, `digitsFocus` 56, `lamp` 8, `pagePadLanes` 12,
  `navPill` 56. `colorBar` und `progressBar` bleiben, bis P2 und P4 sie nicht
  mehr brauchen (sie stecken auch in `protocol_lane.dart`, `tracks_screen.dart`
  und `track_editor_sheet.dart`).
  Sichtbar ändern sich hier nur Ziffern- und Knopfgrößen; das ist gewollt.

### P2 · Spur als Fläche

Entwürfe `1-2-spuren`, `1-3-zustaende`, `5-1-hell-oliv-test`.

- **P2.1** `lane_view.dart`: `LaneControls.secondary` liefert genau einen
  Nebenknopf nach Zustand (Stoppuhr: Runde, pausiert: Stopp · Timer: neu
  starten, klingelt: +1′ · Intervall: nächste Runde · Zähler: zurücknehmen ·
  Erinnerung fällig: +10′). Neues Feld `canStop` für E2. Dazu ein
  abgeleiteter `LaneLook {running, paused, ringing, due, idle}`.
  Test: `lane_view_test.dart` (rein, 23 Stellen anpassen).
- **P2.2** `track_lane.dart`, Rahmen: `_LaneFrame` zeichnet nach `LaneLook`
  Fläche in `tint`, Umriss (bereit 1 px `border`, pausiert 1,5 px `strong`,
  fällig 2 px `warning`) oder volle `danger`-Fläche. Farbbalken entfällt. Lampe
  voll oder hohl; Puls nur bei laufender Spur und ohne „Bewegung reduzieren“.
- **P2.3** Inhalt: Kopfzeile Name 14/600 und Art 14/400 in `ink`; Ziffern in
  Martian Mono 32/500; Nebenzeile 13 in `ink`. Bereite Spur einzeilig mit
  Ziffern 22 in Nebentext und Umriss-Knopf 48.
- **P2.4** Füllung für Timer und Intervall hinter dem Inhalt (`strong`, zeigt
  die Restzeit, schrumpft nach links); `_ProgressBar` entfällt.
  `showProgressBar` schaltet die Füllung, Beschriftung „Fortschritt in der Spur
  zeigen“; Schlüssel bleibt. `LaneKeys.progress` wandert auf die Füllung.
- **P2.5** Knöpfe: `_PrimaryButton` in `solid` / `on`, `_SecondaryButton`
  sichtbar 48 in `strong`. Segmentbalken für Intervall. Label-Felder des
  Zählers 48 hoch in `strong`. Langer Druck auf den Hauptknopf stoppt (E2),
  mit Rückgängig.
- **P2.6** Rückgängig nach Stoppen als `InlineUndoBar` oben in der Liste statt
  Snackbar: „Vögel gestoppt · 10 Tipps gesichert“, Balken für 10 s.
  `InlineUndoBar` bekommt dafür `remaining` (Balken an der Unterkante).
- **P2.7** `protocol_lane.dart`, nur Schritt 1: Fläche und Kacheln je Person
  (60 hoch, Kürzel im Kreis, letzter Eintrag, Minuten seitdem), schmales Plus.
  Schritt 2 (`_CapturePanel`) bleibt bis P4 unverändert in Funktion.
- **P2.8** Raster-Layout (`LaneLayout.tiles`) und `SampleLane` in
  `theme_preview.dart` auf dieselbe Fläche und dieselben Rollen.
  Test: `track_lanes_test.dart`, `protocol_lane_test.dart`.

### P3 · Untere Leiste und Kopf

Entwürfe `1-2-spuren`, `2-7-sets-und-szene`.

- **P3.1** `adaptive_scaffold.dart`: neues Widget `NavPill` (drei Wörter, 56
  hoch, gewählter Reiter in `primary` / `onPrimary`) und runder Plus-Knopf 56;
  12 zum Rand, 30 nach unten plus sichere Zone. Ersetzt in schmaler Breite
  `CupertinoTabBar` und `NavigationBar`.
- **P3.2** `app.dart`: Die Leiste schaltet `TracksView` des aktiven Sets
  (`ui.tracksView.<setId>` bleibt). `ShellDestination` schrumpft; Einstellungen
  wird eine Seite hinter „···“. Verlauf bleibt bis P6 als Eintrag im
  „···“-Menü erreichbar. Ab 720 px Seitenleiste nach E3.
- **P3.3** `tracks_screen.dart`: Kopf mit Set-Titel 30/700 und Pfeil, darunter
  „5 Spuren · 4 aktiv“, rechts „Alle pausieren“ und „···“ (je 48).
  `TracksViewSwitch` entfällt aus dem Kopf; das Plus wandert in die Leiste und
  behält `TracksScreenKeys.addTrack`. Tastenkürzel bleiben.
- **P3.4** `set_switcher.dart` und `protocol_scene_sheet.dart`: ein Blatt „Sets
  und Szene“. Oben die Sets (Name, Zählung, Design-Schild, Haken, „+ Neues
  Set“), darunter „Wer ist dabei?“ und „Was ist dran?“ für das aktive Set.
  Umbenennen, Löschen und Archiv bleiben im „Mehr“ der Zeile.
  Test: `tracks_screen_test.dart`, `tracks_view_test.dart` (dort hängt ein
  Finder an `CupertinoSlidingSegmentedControl<TracksView>`),
  `protocol_scene_test.dart`, `app_smoke_test.dart`.

### P4 · Tippfeld und Erfassen in Stufen

Entwürfe `2-1` bis `2-6`. Vorher O5.

- **P4.1** `pad_model.dart`: `PadButton` bekommt `count`, `since` und
  `lockoutRemaining` als getrennte Felder (heute rechnet die Kachel die Sperre
  selbst). `padSubText` bleibt für Zähler und Uhren.
  Test: `pad_model`-Tests in `test/features/tracks/pad/`.
- **P4.2** `tap_pad.dart`: `_PadTile` als Fläche in `tint` (bereit: Umriss),
  Raster zwei Spalten, das die Höhe füllt; Timer mit Füllung; Personen-Feld mit
  Kürzel und letztem Eintrag.
- **P4.3** Seite „Was?“: feste Leiste oben („Was hattest du?“), Kopf mit
  Zurück, Kürzel und Name, 2 × 3 Felder mit Name 28/700 und Anzahl; Zeile
  „Abstand: noch 34 min“ mit 4-px-Balken nur bei laufendem Abstand. Bei genau
  einer Person entfällt „Wer“.
- **P4.4** Stufe 1: getipptes Feld mit `strong`, 2-px-Rand und „✓ eingetragen“;
  Leiste zeigt „Krille · Wasser / 23:41 · jetzt“ mit „Ändern“ und
  „Rückgängig“ und dem Balken aus P2.6. Rückkehr zur Personenwahl nach
  `captureConfirm` (900 ms) – die Wartezeit zieht aus `ProtocolLane._capture`
  ins Tippfeld. Kein Feld wechselt dabei den Platz (Test prüft die Rechtecke
  vor und nach dem Tipp).
- **P4.5** `protocol_entry_sheet.dart`: `_EntrySheet` neu als halbhohes Blatt.
  „Wann?“ als Knöpfe (Jetzt · −5 · −10 · −30 · Uhr), „Wie viel?“ aus
  `recentAmounts` plus „Andere Menge“, Zeilen Wer / Was / Notiz zugeklappt,
  immer nur eine offen. Jede Änderung speichert sofort; „Fertig“ schließt,
  „Löschen“ mit Rückgängig. Die String-Keys der Tests (`amount`, `time-now`,
  `save-entry` …) bleiben, wo das Element bleibt.
- **P4.6** Zweite Variante von „Wann?“ für ältere Einträge (Uhrzeit mit −5 / −1
  / +1 / +5, Abstand zum vorherigen, „Nochmal jetzt“). Wird in P6 aus der
  Zeitleiste geöffnet, ist aber hier fertig.
- **P4.7** Seite „Anderes“ (Felder 88 hoch, „Neu anlegen“ mit Namensfeld).
- **P4.8** `protocol_lane.dart`: `_CapturePanel` und `_SubstanceButton`
  entfallen; eine Personen-Kachel öffnet „Was?“ im Tippfeld für diese Person.
  Der Zifferntasten-Weg in `tracks_screen.dart` und
  `protocol_session_screen.dart` rufen weiter `showProtocolEntrySheet`.
  Test: `protocol_capture_test.dart`, `tap_pad_test.dart`,
  `protocol_undo_bar_test.dart`, `protocol_entry_flow_test.dart`,
  `protocol_test_support.dart` (Helfer `card` / `button`).

### P5 · Zeitleiste „Jetzt“

Entwurf `3-1-jetzt`.

- **P5.1** Umbau ohne sichtbare Änderung: neue Klasse `TimeScale` (Zeit ↔ x)
  in `strip_viewport.dart`, zunächst linear. `layoutStrip` und `computeAxis`
  nehmen die Skala statt `(startMs, msPerPx)`; Bündelung und Ausblenden rechnen
  in Pixeln. Auch die Stellen in `strip_painter.dart` (Schraffur, Jetzt-Linie)
  und `strip_view.dart` (Puls, Zoom auf ein Bündel).
  Test: die drei Streifen-Tests unverändert grün.
- **P5.2** Falten rechnen (reine Funktion): Strecken ohne Ereignis ab 20 min,
  nie die letzten 10 min vor „jetzt“, laufende Balken zählen nicht als
  Ereignis. `TimeScale` stückweise linear mit 24 px je Falte; Schieben und
  Zoomen rechnen über die Skala.
  Test: kein Ereignis in einer Falte; Zeit → x → Zeit außerhalb umkehrbar;
  x ist monoton.
- **P5.3** Zeichnen: Falte schraffiert mit Dauer an der Achse
  (`strip_axis.dart`), Balken laufen durch. `followAnchor` 0,85.
- **P5.4** `strip_model.dart`: `gutter` 0, Beschriftungszeile über jeder Spur
  (`subLane` 40), Personen vor den übrigen Spuren, auf- / zugeklappt je Person
  (gemerkt je Set unter neuem Schlüssel `ui.stripOpen.<setId>`), zugeklappt
  alle Sachen auf einer Zeile mit Wort darunter.
- **P5.5** Painter: Abstand zwischen zwei Punkten als Text ab 56 px Platz,
  laufende Zeit im Rahmen, Band in Warnfarbe bei laufendem Abstand; übrige
  Spuren kompakt (32 je Spur). Trefferfläche der Punkte 48 × 48.
- **P5.6** `timeline_view.dart`: Karten je Person über dem Streifen (maßgeblich
  ist die Sache mit laufendem Abstand, sonst der letzte Eintrag; Tippen öffnet
  „Was?“). `RunningStrip` entfällt. „Alles“ und „Jetzt“ statt vier Knöpfen;
  `StripKeys` für die beiden bleiben.

### P6 · Abend, Woche, Monat; Verlauf geht auf

Entwürfe `3-2` bis `3-5`. Vorher O1, O2, O3, E4.

- **P6.1** `ui_prefs.dart`: `dayStartMinutes` (Standard nach O3). Reine
  Funktionen in `lib/core/engine/`: logischer Tag zu einem Zeitpunkt, Beginn
  und Ende eines logischen Tags (über lokale Kalenderdaten, damit die
  Zeitumstellung stimmt).
  Test: 01:30 zählt zum Vortag; Tage mit 23 und 25 Stunden.
- **P6.2** Neuer Typ `TimelineLevel {now, evening, week, month}` mit neuem
  Schlüssel `ui.timelineLevel.<setId>`. Fehlt er, wird der alte
  `ui.timelineMode.<setId>` gelesen: `strip` → `now`, `list` → `evening` mit
  „Kompakt“, `summary` → `evening`. `TimelineMode` bleibt unverändert im Code.
  `TimelineScope` wird durch Stufe plus Datum ersetzt. Umschalter als Pille 48.
- **P6.3** `history_repository.dart`: `getEntries` / `watchEntries(setId,
  fromMs, toMs)` für Protokoll-Einträge. Engine: Anzahl je Tag und Sache,
  Monatszahlen (Anzahl, Tage mit Eintrag, längste Pause in Tagen).
  Test: derselbe Datensatz ergibt in Abend, Woche und Monat dieselben Summen.
- **P6.4** `timeline/evening/`: reine Layout-Funktion (Spalten, zwei Plätze je
  Person bei unter 22 px Abstand, Maßstab bis zur nächsten vollen Stunde),
  dann die Ansicht mit Spaltenkopf und Summen, Spuren-Spalte, Jetzt-Linie,
  schraffierter Zukunft. Sache antippen zeigt die Kette. „Kompakt“.
- **P6.5** `timeline/week/`: sieben Zeilen mit dem 12-Stunden-Fenster vor dem
  Tagesbeginn, Summenbalken je Sache. Tag antippen → Abend.
- **P6.6** `timeline/month/`: Kalender mit vier Stufen, Auswahl „Was zählen“,
  drei Kennzahlen. Tag antippen → Abend.
- **P6.7** Eintrag aus der Zeitleiste öffnet das Blatt aus P4.6.
  `_EventSheet` bleibt für Start, Pause, Runde und Tipp.
- **P6.8** `showExportSheet` bekommt einen Zeitraum als Parameter; Export- und
  Filter-Knopf im Kopf der Zeitleiste. Sitzungen bleiben über
  `SessionDetailPage` erreichbar (aus Abend und Woche).
- **P6.9** `HistoryScreen`, Filterleiste und Summenansicht entfernen, Eintrag
  aus dem „···“-Menü nehmen; `history_filter_logic.dart` bleibt, soweit der
  Export es braucht. Zwei-Finger-Wechsel der Stufe zuletzt.
  Test: `history_screen_test.dart` entfällt, `export_sheet_test.dart` angepasst.

### P7 · Einstellungen mit festen Reitern

Entwurf `4-1-einstellungen`.

- **P7.1** `SliderSettingTile` mit Rücksetz-Punkt in Warnfarbe bei geändertem
  Wert (Trefferfläche 48).
- **P7.2** `settings_screen.dart`: fünf feste Reiter Design · Bedienung ·
  Alarme · Daten · System; die bestehenden Abschnitte werden verteilt,
  `DisplaySettingsScreen` geht in „Bedienung“ auf. Was nicht geht, ist
  ausgegraut mit Hinweis statt versteckt.
- **P7.3** Zeile „Tag beginnt um“ in „Bedienung“. `PinnedPreview` bleibt oben
  stehen und zeigt die Spur aus P2.

### P8 · Design-Modell und vier neue Designs

Entwürfe `4-2`, `4-3`, `5-2` bis `5-5`. Vorher O4b.

- **P8.1** `TikkyTheme` um `shape` (Radien je Rolle, Randbreite, Schatten-Art),
  `fonts` (Text / Titel / Ziffern, Größe, Gewicht, Laufweite) und `motion`
  (Hintergrund, laufende Spur, Tempo, Stärke, „Beim Erfassen ruhig“).
  `fromJson` liest Version 1 weiter: fehlendes `shape` wird aus `cornerRadius`
  gerechnet wie in P1.4, fehlende `fonts` aus `fontFamily`.
  Test: `theme_test.dart` mit einem gespeicherten Design von heute.
- **P8.2** Schriften bündeln (nach O4b), Vorlagen Neon, Kassette, Arcade, Lava
  aus `tokens.json`. Der Test aus P1.2 läuft über alle sieben.
- **P8.3** Flächen-Dekoration: Rand, Glühen, harter und versetzter Schatten,
  Streifen oben, schräg gestreifte Füllung – als Teil von `surfaceDecoration`,
  gesteuert über die Felder aus P8.1. Großbuchstaben für Arcade als Schrift-
  Eigenschaft, nicht im Widget.
- **P8.4** `lib/theme/effects/`: Hintergrund (Raster, Lava, Sterne) hinter dem
  Inhalt mit Schleier; Spule und Atmen in der Spur. Ein Schalter bündelt
  `MediaQuery.disableAnimations`, die App-Einstellung und „Beim Erfassen
  ruhig“ (Tippfeld und „Was?“).
  Test: im Tippfeld läuft kein Ticker, solange der Schalter an ist.
- **P8.5** Looks: Änderungen je Vorlage unter neuem Schlüssel `theme.looks`
  als Differenz; „Zurücksetzen“ löscht den Eintrag. `theme.custom` bleibt für
  eigene Designs und bekommt einen Verweis auf die Vorlage.
- **P8.6** `theme_list_screen.dart` als Galerie mit Geltung „Überall“ / „Nur im
  Set …“; `theme_editor_screen.dart` als Blatt mit vier Reitern unter zwei
  laufenden Spuren, Kontrast-Zeile unten.

### P9 · Leerer Start, Neue Spur, Fokus

Entwürfe `1-1`, `1-4`, `1-5`. Vorher O7.

- **P9.1** Leerer Start: sechs Felder, ein Tipp legt mit
  `TrackConfig.defaultFor(mode)` an. `TracksScreenKeys.emptyAddTrack` bleibt
  am ersten Feld oder der Test wird angepasst.
- **P9.2** `track_editor_sheet.dart`: Art als 3 × 2 Knöpfe, Dauer mit − / + und
  Schnellwahl, Farbe als 5 × 2 Felder (eigene Farbe bleibt dahinter
  erreichbar). `TrackEditorKeys` bleiben.
- **P9.3** `lib/features/tracks/focus/`: Seite mit Ring (300, 14 breit), Zeit
  56, Knöpfe aus `LaneModel`, andere laufende Spuren als Felder unten. Tippen
  auf die Spur öffnet sie.

## 5. Durchgehend

- Jede Farbe und jedes Maß aus `context.tikky`; fehlt ein Token, kommt es dort
  dazu, nicht ins Widget.
- Engine und Tabellen bleiben unberührt; neu gespeichert werden nur
  Einstellungen (`dayStartMinutes`, `ui.timelineLevel.*`, `ui.stripOpen.*`,
  `theme.looks`).
- Neue Texte auf Deutsch in die jeweilige `*_strings.dart`.
- Was nur am Gerät prüfbar ist (Haptik, sichere Zonen der Leiste, Schriftbild,
  Leistung der Hintergründe), kommt als Zeile nach `docs/GERAETETEST.md`.
- Nach P6 und P8 `README.md` und `docs/ideen/BACKLOG.md` nachziehen.
