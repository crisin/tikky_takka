# Umsetzung in Flutter

Arbeitspakete in einer Reihenfolge, in der jedes für sich lauffähig bleibt.
Jedes Paket nennt die Entwürfe, die Dateien in `lib/`, die es betrifft, und
woran man erkennt, dass es fertig ist. Die Dateiangaben stammen aus dem Stand
vom 14.11.2026; vor dem Start eines Pakets kurz nachsehen, ob sie noch stimmen.

## Grundsätze für jedes Paket

- **Tokens zuerst.** Kein Widget bekommt einen festen Farb-, Maß- oder
  Schriftwert; alles kommt aus `context.tikky` (`lib/theme/tokens.dart`). Fehlt
  ein Token, wird es dort ergänzt.
- **Die Engine bleibt unberührt.** Gespeichert werden weiter nur Ereignisse;
  alle Anzeigen sind abgeleitet. Kein Paket hier braucht eine Schema-Änderung,
  außer P7 („Tag beginnt um“ ist eine Einstellung, keine Tabelle).
- **Vorlage ist das HTML.** Maße und Farben aus `entwuerfe/<name>.html` und
  `entwuerfe/tikky.css` übernehmen, nicht aus dem PNG schätzen.
- **Adaptive Schicht:** Die Entwürfe sind auf allen Plattformen gleich.
  Cupertino- bzw. Material-Teile bleiben für das, was nicht gezeichnet ist
  (Dialoge, Auswahlräder, System-Blätter).
- **Tests mitziehen.** Die Widget-Tests hängen an Keys (`LaneKeys`, `PadKeys`,
  `StripKeys`, `TimelineKeys` …). Keys bleiben erhalten, wo das Element bleibt.
- **Muss-Regeln** aus `docs/ideen/UEBERGABE-CLAUDE-DESIGN.md` Abschnitt 8
  gelten weiter (Tippziele, Kontrast, Deutsch, keine Nachfragen, nichts
  verdeckt Felder, Ziffern springen nicht, keine Bewertung).

## P1 · Farbrollen und neue Tokens

Entwürfe: alle. Beschreibung: `DESIGNS.md` Abschnitt 2 und 5.

- `lib/theme/tikky_theme.dart`: `TikkyColors` um `warningText` ergänzen.
- `lib/theme/tokens.dart`: Rollen je Spurfarbe als Typ (`solid`, `tint`,
  `strong`, `ink`, `on`) und eine Funktion `trackRoles(Track)` bzw.
  `roles(Color)`; Ergebnis je Farbe und Design zwischenspeichern. Neue Maße
  aus der Tabelle in `DESIGNS.md` Abschnitt 5; `colorBar` und `progressBar`
  bleiben vorerst, bis P2 sie nicht mehr braucht.
- `lib/theme/theme_presets.dart`: `textMuted` der drei Vorlagen auf die Werte
  aus `tokens.json` setzen.
- `lib/features/settings/contrast.dart`: `ContrastPair` um die Rollen-Paare
  erweitern (`ink` auf `tint`, `ink` auf `strong`, `on` auf `solid`, Text auf
  `strong`, `warningText` auf `tint`).

Fertig, wenn: ein Test für alle zehn Palettenfarben in Hell, Dunkel und Schwarz
die Werte aus `tokens.json` trifft und kein Paar unter 4,5:1 liegt.

## P2 · Spur als Fläche

Entwürfe: `1-2-spuren`, `1-3-zustaende`, `5-1-hell-oliv-test`.

- `lib/features/tracks/track_lane.dart`: `_LaneFrame` zeichnet die Fläche in
  `tint` statt Fläche + Farbbalken; Füllung für Timer und Intervall hinter dem
  Inhalt; ein Nebenknopf statt zwei; Lampe; Zustände laufend / pausiert /
  klingelt / fällig / bereit. `_LaneTimeBlock` ohne Fortschrittsleiste,
  Nebenzeile in `ink`.
- `lib/features/tracks/lane_view.dart`: `LaneControls` liefert, welcher
  Nebenknopf sichtbar ist; Stoppen wandert in den Zustand „pausiert“ und auf
  langen Druck.
- `lib/features/protocol/protocol_lane.dart`: die Spur zeigt nur noch „Wer bist
  du?“ mit einer Kachel je Person; die Erfassung selbst zieht nach P4 um.
- `lib/theme/ui_prefs.dart`: `showProgressBar` verliert seine Bedeutung
  (Füllung statt Leiste) – als „Fortschritt in der Spur zeigen“ weiterführen.
- Raster-Layout (`LaneLayout.tiles`, ab 720 px) ist nicht gezeichnet: dieselbe
  Fläche und dieselben Rollen verwenden, Aufbau lassen.

Fertig, wenn: `track_lanes_test.dart` und `lane_view_test.dart` grün sind und
die Spuren im Web-Build bei 375 × 812 wie `1-2-spuren.png` aussehen.

## P3 · Untere Leiste und Kopf

Entwürfe: `1-2-spuren` (Leiste, Kopf), `2-7-sets-und-szene`.

- `lib/app.dart`: `ShellDestination` hat heute `tracks, history, settings`.
  Neu sind die drei Ansichten die Ziele der Leiste; Einstellungen wird eine
  Seite hinter „···“, Verlauf entfällt als Ziel (erst nach P6 entfernen).
- `lib/adaptive/adaptive_scaffold.dart`: `AdaptiveNavScaffold` bekommt die
  Pille mit Plus-Knopf für schmale Breiten; die Seitenleiste ab 720 px bleibt.
- `lib/features/tracks/tracks_view.dart`: `TracksView` / `TracksViewSwitch`
  (heute Umschalter oben, pro Set gemerkt) wird zur unteren Leiste; die
  Merk-Logik `ui.tracksView.<setId>` bleibt.
- `lib/features/tracks/tracks_screen.dart`: Kopf mit großem Set-Titel, „Alle
  pausieren“ und „···“; das Plus wandert in die Leiste.
- `lib/features/tracks/set_switcher.dart` und
  `lib/features/protocol/protocol_scene_sheet.dart`: ein gemeinsames Blatt
  „Sets und Szene“.

Fertig, wenn: alle drei Ansichten mit dem Daumen erreichbar sind, der Set-Name
nicht mehr abgeschnitten wird und `tracks_screen_test.dart` angepasst grün ist.

## P4 · Tippfeld und Erfassen in Stufen

Entwürfe: `2-1-tippfeld` bis `2-6-anderes`. Beschreibung: `FLOWS.md` Abschnitt 2.

- `lib/features/tracks/pad/tap_pad.dart`: `_PadTile` als getönte Fläche;
  `_PersonPage` wird zur Seite „Was?“ mit großen Namen, kleiner Anzahl und Zeit
  nur bei laufendem Abstand. Kein Dock, keine Zeit-Knöpfe.
- `lib/features/tracks/pad/pad_model.dart`: `PadButton` liefert „Abstand läuft
  noch …“ getrennt von „vor …“, damit die Seite entscheiden kann, was sie zeigt.
- `lib/adaptive/inline_undo_bar.dart`: zweiter Knopf „Ändern“ neben
  „Rückgängig“; Balken für die Restzeit.
- `lib/features/protocol/protocol_entry_sheet.dart`: `_EntrySheet` wird das
  eine Eintragsblatt mit „Wann?“, „Wie viel?“ und zuklappbaren Zeilen Wer /
  Was / Notiz. Zwei Varianten von „Wann?“: Knöpfe (frischer Eintrag) und
  Uhrzeit mit Schritten (älterer Eintrag).
- `lib/features/protocol/protocol_lane.dart`: `_CapturePanel` und
  `_SubstanceButton` entfallen zugunsten der Tippfeld-Seite (ein Ort für das
  Erfassen); von der Spur aus öffnet eine Personen-Kachel dieselbe Seite.
- „Wie viel?“ braucht die zuletzt benutzten Mengen je Sache: aus den
  Ereignissen ableiten (`lib/features/protocol/protocol_logic.dart`), nichts
  Neues speichern.
- Seite „Anderes“ ersetzt den Weg über das volle Blatt.

Fertig, wenn: ein Eintrag zwei Tipps braucht (einer bei einer Person), danach
nichts seinen Platz gewechselt hat, „Ändern“ Zeit und Menge in je einem Tipp
setzt und `protocol_capture_test.dart`, `tap_pad_test.dart` und
`protocol_undo_bar_test.dart` angepasst grün sind.

## P5 · Zeitleiste „Jetzt“

Entwurf: `3-1-jetzt`. Beschreibung: `FLOWS.md` 3.1.

- `lib/features/tracks/timeline/strip/strip_model.dart`: keine Namensspalte
  (`gutter` 0), Beschriftungszeile über jeder Spur; Personen vor den übrigen
  Spuren; Zustand auf- / zugeklappt je Person; zugeklappte Zeile mischt alle
  Sachen; **Falten** als stückweise lineare Zeitachse (`StripViewport` rechnet
  Zeit ↔ x mit einer Liste gestauchter Strecken).
- `lib/features/tracks/timeline/strip/strip_painter.dart`: Falte, Band in
  Warnfarbe, laufender Abstand im Rahmen, kompakte Spuren.
- `lib/features/tracks/timeline/strip/strip_axis.dart`: Achse mit Falten-Dauer.
- `lib/features/tracks/timeline/timeline_view.dart`: Karten je Person über dem
  Streifen; `RunningStrip` entfällt (die Spuren zeigen ihre Zeit selbst);
  „Alles“ / „Jetzt“ statt vier Zoom-Knöpfen.

Fertig, wenn: `strip_model_test.dart`, `strip_viewport_test.dart` und
`strip_axis_test.dart` um Falten erweitert grün sind (kein Ereignis liegt je in
einer Falte; Zeit → x → Zeit ist außerhalb der Falten umkehrbar).

## P6 · Zeitleiste Abend, Woche, Monat; Verlauf geht auf

Entwürfe: `3-2-abend` bis `3-5-eintrag`. Vorher O1, O2 und O3 klären.

- `lib/features/tracks/timeline/timeline_mode.dart`: `TimelineMode` hat heute
  `strip, list, summary` und ist gespeichert („never rename“). Neu: Stufen
  `now, evening, week, month`. Gespeicherte alte Werte abbilden: `strip` →
  `now`, `list` → `evening` mit „Kompakt“, `summary` → `evening`.
- `lib/features/tracks/timeline/timeline_logic.dart`: `TimelineScope`
  (`open, today, last24h`) wird durch die Stufe plus Datum ersetzt; der „Tag“
  beginnt zur eingestellten Uhrzeit.
- Neu `timeline/evening/`: Spalten je Person, Platzvergabe (zwei Plätze je
  Spalte, Abstand 22 px), Kette der Abstände für die gewählte Sache. Reine
  Funktionen für Layout, eigener Painter oder positionierte Widgets.
- Neu `timeline/week/` und `timeline/month/`: brauchen Ereignisse je Tag und
  Sache über den Zeitraum. `lib/core/repo/history_repository.dart` hat
  `getDailySums` / `getWeeklySums` für Spuren; für Einträge je Sache fehlt eine
  Abfrage (`getSubstanceUse` gilt je Spur, ohne Zeitraum).
- `lib/core/engine/history_math.dart` bzw. `summary.dart`: Kennzahlen für den
  Monat (Anzahl, Tage mit Eintrag, längste Pause).
- `lib/features/history/`: `HistoryScreen`, `HistoryFilterBar`,
  `HistorySumsView` gehen in den Stufen auf; `SessionDetailPage` bleibt als
  Ziel für eine angetippte Sitzung; `export_sheet.dart` hängt am Export-Knopf
  der Zeitleiste und nimmt den sichtbaren Zeitraum als Vorgabe.
- `lib/features/tracks/timeline/timeline_event_sheet.dart`: `_EventSheet` wird
  für Protokoll-Einträge durch das Eintragsblatt aus P4 ersetzt; für Start,
  Pause, Runde und Tipp bleibt es.

Fertig, wenn: derselbe Datensatz in allen vier Stufen dieselben Summen ergibt
(Test), ein Tag aus Woche und Monat zum Abend führt und der Bereich „Verlauf“
aus der Navigation verschwunden ist, ohne dass Export oder Sitzungsdetails
fehlen.

## P7 · Einstellungen mit festen Reitern

Entwurf: `4-1-einstellungen`. Beschreibung: `FLOWS.md` 4.1.

- `lib/features/settings/settings_screen.dart`: die Abschnitte
  (`_AppearanceSection`, `_BehaviourSection`, `_SetsSection`, `_DataSection`,
  `_AboutSection`) auf fünf Reiter verteilen; `display_settings_screen.dart`
  geht in „Bedienung“ auf.
- `lib/features/settings/widgets/setting_rows.dart`: `SliderSettingTile` mit
  Wert rechts und Rücksetz-Punkt bei geändertem Wert.
- `lib/features/settings/widgets/theme_preview.dart`: `PinnedPreview` zeigt
  eine laufende Spur im neuen Aufbau.
- `lib/theme/ui_prefs.dart`: neues Feld für „Tag beginnt um“ (Minuten nach
  Mitternacht, Standard 360) mit Schlüssel in `UiPrefsKeys`.

## P8 · Design-Modell und die vier neuen Designs

Entwürfe: `4-2-designs`, `4-3-design-anpassen`, `5-2-neon` bis `5-5-lava`.
Beschreibung: `DESIGNS.md`. Vorher O4 klären.

- `lib/theme/tikky_theme.dart`: `TikkyTheme` um Form (Radien je Rolle statt
  einem `cornerRadius`, Randbreite, Schatten-Art), Schriften (Text / Titel /
  Ziffern statt einem `fontFamily`) und Bewegung (Hintergrund, laufende Spur,
  Tempo, Stärke, „beim Erfassen ruhig“) erweitern. `fromJson` muss alte
  gespeicherte Designs weiter lesen (fehlende Felder = Werte der Vorlage).
- `lib/theme/theme_presets.dart`: Neon, Kassette, Arcade, Lava aus
  `tokens.json`.
- `lib/theme/theme_controllers.dart`: `CustomThemesController` speichert heute
  ganze eigene Designs. Neu: Änderungen je Vorlage („Look“) – entweder als
  Differenz zur Vorlage oder weiter als ganzes Design mit Verweis auf die
  Vorlage; „Zurücksetzen“ löscht den Eintrag.
- `pubspec.yaml`: Schriften unter `flutter: fonts:` bündeln, Lizenztexte in
  `assets/fonts/`. `TikkyFonts` um die neuen Familien erweitern.
- Neu `lib/theme/effects/`: Hintergrund-Widget (Raster, Lava, Sterne) hinter
  dem Inhalt, Spule und Glühen als Teil der Spur. Alles hinter einem Schalter,
  der „Bewegung reduzieren“ des Systems beachtet (`MediaQuery.disableAnimations`).
- `lib/features/settings/theme_list_screen.dart` → Galerie mit Kacheln;
  `theme_editor_screen.dart` → Blatt mit vier Reitern unter zwei laufenden
  Spuren; `ContrastWarning` zeigt das durchgefallene Paar.

Fertig, wenn: `theme_test.dart` alte gespeicherte Designs weiter liest, jedes
der sieben Designs den Kontrast-Test aus P1 besteht und im Tippfeld nichts
animiert, solange „Beim Erfassen ruhig“ an ist.

## P9 · Leerer Start, Neue Spur, Fokus

Entwürfe: `1-1-leerer-start`, `1-4-neue-spur`, `1-5-fokus`.

- `lib/features/tracks/tracks_screen.dart`: leerer Zustand mit sechs Feldern,
  ein Tipp legt mit Standardwerten an (`TrackConfig` je Art).
- `lib/features/tracks/track_editor_sheet.dart`: Art als sechs Knöpfe statt
  Liste, Dauer mit Schritten und Schnellwahl, Farbe als zehn Felder.
- Neu `lib/features/tracks/focus/`: Seite mit Ring; nutzt `LaneModel` für Zeit
  und Knöpfe.

## Reihenfolge und Abhängigkeiten

```
P1 ─┬─ P2 ─┬─ P3 ── P9
    │      └─ P4
    ├─ P5 ── P6
    └─ P7 ── P8
```

P1 bis P4 ergeben zusammen die sichtbare Richtung „Pult“ und sind ohne offene
Fragen baubar (bis auf O5). P5 ist unabhängig von O1–O3. P6 und P8 warten auf
Entscheidungen.

## Abgleich mit dem Backlog

| Backlog | Stand nach dieser Runde |
|---|---|
| Nr. 5 Ampel | weiter offen (O6); Karten in „Jetzt“ zeigen Zeit und Abstand ohne Farbe |
| Nr. 6 Anzeige pro Szene | Design je Set bleibt; Sortierung nicht behandelt |
| Nr. 15 „Größer, an iOS orientiert“ | durch Richtung A ersetzt: eigener Look auf allen Plattformen |
| Nr. 16 Dock | im Fokus als Felder unten; im Tippfeld bewusst kein Dock, ein Alarm übernimmt die Leiste |
| Nr. 17 Fortsetzen | „Nochmal jetzt“ im Eintragsblatt (P4/P6) |
| Nr. 18 „Gestartet vor …“ | „Wann?“ im Eintragsblatt, nachträglich (P4) |
| Nr. 19 Fisheye | als Falte umgesetzt (P5) |
| Nr. 20 Segmentbalken | Intervall-Spur (P2) |
| Nr. 21 Pillen-Navigation | untere Leiste, mit Wörtern statt Icons (P3) |
| Nr. 22 Ring | im Fokus (P9); in der Liste ist die Spur selbst der Balken |
| Nr. 23 Farbe ans Design anpassen | Rollen (P1) und Schalter im Editor (P8) |
| Nr. 24 Einklappbare Gruppen | Personen in „Jetzt“ auf- und zuklappbar (P5); Sets nicht |
| Nr. 25 Heatmap und Serien | Monat (P6) |
| Nr. 26 Einstellungen als Zeilen | feste Reiter, Regler mit Rücksetz-Punkt (P7); keine Suche |
| Nr. 27 „Seit …“-Zeile | Karten in „Jetzt“, Kachel je Person in der Spur |
| Nr. 28 Zen-Modus | Fokus (P9) |
