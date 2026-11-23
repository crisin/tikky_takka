# Inspiration aus Open-Source-Apps

Recherche vom 14.11.2026. Fokus: Smartphone. Gesehen wurden Screenshots bzw.
die Demo (Flex, Table Habit, Loop, Ice Cubes, TimeTagger). Beim babytracker
gibt es weder Screenshots noch Demo; dort stammt alles aus dem README-Text.
Aussagen zu Immich und Nomie stammen aus Suchergebnissen und PR-Titeln, nicht
aus eigener Ansicht.

Die Ideen A–M stehen als Nr. 16–28 in `BACKLOG.md` (A = 16 … M = 28), Status
`offen`. Das Übergabe-Dokument für das Design ist
`UEBERGABE-CLAUDE-DESIGN.md`.

## Lizenzen (wichtig, falls Code übernommen werden soll)

| Projekt | Lizenz |
|---|---|
| Flex (brandonp2412) | MIT |
| Table Habit / mhabit | Apache-2.0 |
| babytracker (BeyensJ) | MIT |
| OpenHIIT | MIT |
| Loop Habit Tracker | GPL-3.0 |
| lichess mobile | GPL-3.0 |
| Ice Cubes | **AGPL-3.0** (nicht MIT) |
| TimeTagger | GPL-3.0 |

Muster und Ideen sind frei. Code nur aus MIT/Apache-Projekten übernehmen.

## Was ich gesehen habe

### Flex – Flutter, Material 3 (Training, Pausen-Timer)
Repo: <https://github.com/brandonp2412/Flex>

- **Schwebende Pillen-Navigation unten**: Icons, nur der gewählte Reiter zeigt
  sein Label; der Knopf „Add“ schwebt als Extended-FAB darüber.
- **Fortschritt als Segmentbalken**: pro Übung eine Reihe von Balken, gefüllt =
  Satz erledigt. Man sieht „3 von 4“ ohne Zahl.
- **Steppers (− Wert +)** für Wiederholungen/Gewicht statt Tastatur.
- **Pausen-Timer als großer Ring** mit Restzeit in der Mitte und Hundertstel
  klein darunter.
- **Einstellungen**: Zeilen mit Icon, Titel und Untertitel, oben eine Suche.
- Listen beginnen mit Suchfeld und Filter/Menü in einer Zeile.

### Table Habit – Flutter, Material 3, dynamische Farben
Repo: <https://github.com/FriesI23/mhabit>

- **Gruppen einklappbar**, Gruppenkopf in der Gruppenfarbe, Anzahl daneben.
- **Datumsspalten (3 Tage)** rechts, pro Zeile Häkchen; kleiner Fortschrittsring
  links statt Checkbox.
- **Farbwähler mit „an Theme anpassen“** (Tint to theme): die gewählte Farbe
  wird leicht Richtung Theme verschoben, damit sie in Hell und Dunkel passt.
- Bearbeiten-Seite als schlichte Liste: Icon links, Wert rechts, kein Formular.

### Loop Habit Tracker – Android
Repo: <https://github.com/iSoron/uhabits>

- **Dichte Matrix**: Zeilen = Gewohnheiten, Spalten = Tage; Zahlenwerte (z. B.
  1,2 km) stehen in derselben Zelle wie Häkchen.
- **Detailseite** stapelt Übersicht (Ring + Kennzahlen), Verlauf-Kurve,
  Balken, Kalender-Heatmap, Serien als Balken auf einer Zeitachse.
- **Widgets** zeigen dieselbe Heatmap bzw. einen Ein-Tipp-Knopf.

### Ice Cubes – SwiftUI, iOS
Repo: <https://github.com/Dimillian/IceCubesApp>

- Dunkles Design mit einer einzigen Akzentfarbe (Violett), Liste ohne
  Kartenrahmen, Trennung nur durch Abstand und feine Linien.
- Tab-Leiste unten mit Icon + Label; auf dem iPad stattdessen Seitenleiste.
- Nützlich vor allem für den offenen Punkt „näher an iOS“ (Nr. 15), weniger für
  Timer.

### TimeTagger – Web, Zeitleiste (Demo getestet)
Demo: <https://timetagger.app/demo> (ohne Konto, Zufallsdaten)

- **Tagesansicht senkrecht**: 24-h-Säule am linken Rand, rechts daneben die
  Einträge **vergrößert**; zwischen Säule und Detail verbinden **trichterförmige
  Linien** beide Ebenen (Fisheye). Leere Stunden werden gestaucht, belegte
  gedehnt; Dauer steht am Rand („1h23m“).
- Jetzt-Linie gestrichelt; Farbe pro Tag/Tag-Gruppe als schmaler Balken.

### babytracker – nur README
Repo: <https://github.com/BeyensJ/babytracker>

Beschrieben, nicht gesehen: fester **Dock mit laufenden Timern** über alle
Ansichten; **„Fortsetzen“ mit einem Tipp** bei gerade beendeter Sitzung;
**anpassbare untere Leiste** (häufigste Aktionen) plus „+ Mehr“; **Zen-Modus**
und **OLED-Schwarz** für nachts; „Gestartet vor 10 min“ als nachträgliche
Startzeit; **Wachfenster** („1 h 45 min wach“ / „schläft seit 22:15“).

## Ideen für Tikky Takka

| # | Idee | Woher | Bezug zum Backlog |
|---|---|---|---|
| A | **Laufende-Timer-Dock**: eine feste Leiste (unten) mit allen laufenden Spuren, auf jedem Reiter sichtbar, Tipp = pausieren/stoppen | babytracker | ergänzt Nr. 8 („Timer bleibt vorne sichtbar“) |
| B | **„Fortsetzen“ als Ein-Tipp** auf gerade beendeten Sitzungen im Verlauf / in der Zeitleiste | babytracker | Nr. 2, 11 |
| C | **„Gestartet vor …“**: Startzeit beim Erfassen nachträglich um Minuten verschieben (Chips: 5 / 10 / 30 min) | babytracker | Nr. 2 („Details“) |
| D | **Fisheye-Streifen**: leere Zeit stauchen, belegte Zeit dehnen; Verbindungslinien zwischen Übersicht und Detail | TimeTagger | Nr. 13, 14 (Streifen, Abstände) |
| E | **Segmentbalken statt Zahl** für „n von m“ (Sitzungen, Runden, Intervalle) | Flex | Nr. 7 |
| F | **Pillen-Navigation**, nur gewählter Reiter mit Label, FAB schwebt darüber | Flex | Nr. 15 |
| G | **Großer Ring** für Timer und Intervall mit Restzeit in der Mitte | Flex | Nr. 15 |
| H | **Farbwähler mit „an Theme anpassen“** im Design-Editor | Table Habit | Designs |
| I | **Einklappbare Gruppen** (Sets) mit Anzahl und Gruppenfarbe | Table Habit | Sets |
| J | **Kalender-Heatmap und Serien** auf der Detailseite einer Spur/Substanz | Loop | Verlauf, Nr. 10 |
| K | **Einstellungen als Listenzeilen** mit Icon, Titel, Untertitel + Suche | Flex, Ice Cubes | Nr. 15 (gruppierte Listen) |
| L | **Wachfenster / „seit …“-Zeile** pro Spur („zuletzt vor 1 h 45 min“) | babytracker | Nr. 5, 13 |
| M | **Zen-Modus**: nur große Knöpfe + schwarzer Hintergrund, alles andere aus | babytracker | Nr. 9, 11 |

## Noch nicht angesehen

- **Immich** (Timeline-Scrubber, Flutter): Code unter
  `mobile/lib/presentation/widgets/timeline/scrubber.widget.dart`.
- **Nomie 6** (Tipp-Tracker): kein Handy-Screenshot gefunden.
- **lichess mobile**, **OpenHIIT**: Screenshots nicht geprüft.
