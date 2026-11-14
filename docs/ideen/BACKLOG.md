# Ideenliste Tikky Takka

Jede Idee hat einen Status: `offen`, `geplant`, `teilweise`, `gebaut`,
`verworfen`.
Quelle ist die Aufnahme oder das Gespräch, aus dem sie stammt. Transkripte
liegen unter `aufnahmen/`; neue Aufnahmen kommen mit
`tools/idee.sh "<pfad zur audiodatei>"` dazu.

## Aus der Aufnahme vom 14.11. (`aufnahmen/14-11-big-brain-timer-durchbruch.md`)

Alle Punkte betreffen den Protokoll-Modus ("Baller-Modus").

| Nr. | Idee | Status | Stand in der App |
|---|---|---|---|
| 1 | **Szenen:** vor dem Abend festlegen, wer dabei ist und was heute die Hauptsachen sind. Diese Personen und Substanzen sind dann vorausgewählt; alles andere kommt per Hand aus dem Gesamtbestand. [00:29–01:03] | gebaut | Eine Szene gehört zum Set: „Wer ist dabei?“ und „Was ist heute dran?“ (Reihenfolge = Reihenfolge des Antippens), mit „Szene leeren“. Erreichbar über die Set-Optionen („Szene bearbeiten“) und den Knopf „Szene“ auf der Protokoll-Spur. Szenen-Personen und -Substanzen stehen bei der Erfassung vorn; alle anderen über „Andere“ bzw. „+“. Wird eine Person oder Substanz gelöscht, verschwindet sie aus allen Szenen. Im Backup enthalten, aber nur zusammen mit den Protokolldaten. |
| 2 | **Ein-Tipp-Erfassung:** große Knöpfe, ein Tipp = Eintrag mit Zeitstempel ("Jacke, das – zack"). Nichts lesen, nichts ausfüllen müssen. [00:06–00:21, 02:59–03:04, 05:28–05:42] | gebaut | Auf der Protokoll-Spur: Personenkarte antippen, dann ein großer Substanz-Knopf – der Tipp schreibt sofort den Eintrag (Person, Substanz, jetzt; ohne Menge, ohne Nachfrage). Bei genau einer Person in der Szene ist es ein einziger Tipp. Danach stehen „Rückgängig“ und „Details“ (Menge, Notiz, Zeit) rund zehn Sekunden in einer Leiste in der Spur selbst – keine Meldung mehr, die Knöpfe verdeckt. Dasselbe geht im Tippfeld (siehe unten). Nicht gebaut: Erfassung von außerhalb der App (Widget/Shortcut). |
| 3 | **"Wer bist du?" beim Öffnen:** Ist eine Szene aktiv, fragt die App zuerst nach der Person, dargestellt als Karten/Notizen pro Anwesendem. [01:33–02:27] | gebaut | Die Spur zeigt zuerst „Wer bist du?“ mit einer Karte pro Person (Name, Farbe, letzter Eintrag, Zeit seitdem, eigene Rest-Sperrzeit). Mit Szene nur die Anwesenden plus „Andere“; ohne Szene alle. Bei genau einer Person in der Szene entfällt der Schritt. Die Frage steht auf der Spur, nicht als eigener Bildschirm beim App-Start. |
| 4 | **Top-5-Vorschläge:** Nach der Personenwahl stehen die fünf wahrscheinlichsten Sachen direkt zur Auswahl, plus ein "+ / ?" für etwas anderes. [02:27–02:58] | gebaut | Nach der Personenwahl bis zu fünf Knöpfe: erst die Substanzen der Szene (in deren Reihenfolge), dann die von dieser Person am häufigsten eingetragenen (über alle Sitzungen der Spur, bei Gleichstand die zuletzt benutzte). „+“ öffnet das volle Eintragsblatt mit gewählter Person. Ohne Szene und ohne frühere Einträge gibt es noch keine Knöpfe, nur „+“. |
| 5 | **Status-Ansicht mit Ampel:** pro Person eine Farbe (grün/gelb/rot), abgeleitet aus dem, was intus ist, und den selbst eingestellten Sperrzeiten pro Substanz. Grün nur, wenn wirklich lange nichts war. [03:05–04:22] | offen | Teilweise. Die Spur zeigt pro Person den letzten Eintrag und die Rest-Sperrzeit, aber keine Ampel und keine Gesamtübersicht. |
| 6 | **Anzeige pro Szene einstellbar:** im Club anderes sehen als auf dem Festival; Sortierung der letzten Timer frei wählbar. [04:25–04:50] | offen | Teilweise. Pro Set lassen sich Theme und Darstellung überschreiben; über die Szene des Sets auch, welche Personen und Substanzen vorn stehen. Die Sortierung der letzten Einträge ist nicht einstellbar. |
| 7 | **Nur zählen, Timer nur wo nötig:** Jeder Tipp wird gezählt und mit Zeit notiert, aber ein sichtbarer Timer läuft nur für Substanzen, bei denen ich das einstelle. [05:42–05:55] | gebaut | Jeder Substanz-Knopf zeigt, wie oft die Person das in der laufenden Sitzung eingetragen hat. Eine Restzeit erscheint nur bei Substanzen mit selbst eingestellter Sperrzeit und nur solange sie läuft; sie wird angezeigt, sperrt aber nichts. Keine eigene Einstellung nötig. |
| 8 | **Zwei Ansichten der Einträge, umschaltbar:** Zeitleiste zum Durchgehen und Zusammenfassung ("was ist insgesamt passiert", nach Gewichtung sortiert). Der Timer bleibt dabei vorne sichtbar. [05:56–06:36] | gebaut | Auf dem Spuren-Bildschirm gibt es oben den Umschalter „Spuren / Tippfeld / Zeitleiste“ (pro Set gemerkt). Die Zeitleiste zeigt alle Spuren des Sets in einer Liste nach Zeit (neueste oder älteste zuerst), für „Laufende Sitzungen“, „Heute“ oder „Letzte 24 h“; Start/Pause/Stopp sind ausgeblendet, bis man sie einschaltet; Spuren lassen sich ausblenden; nach mehr als fünf Minuten Abstand steht ein Hinweis („12 min früher“). Antippen öffnet das Bearbeiten (Zeit, Label, Notiz, Löschen mit Rückgängig; Protokoll-Einträge im bekannten Eintragsblatt). Umschaltbar auf „Zusammenfassung“: pro Zähler je Label Anzahl, erste/letzte Zeit und mittlerer Abstand; pro Stoppuhr Nettozeit und Runden; pro Protokoll-Spur je Person je Substanz Anzahl, erste und letzte Zeit – sortiert nach Anzahl oder nach letzter Zeit. Laufende Timer stehen in beiden Ansichten oben in einer festen Zeile. Grenzen: Mengen werden nie addiert (Freitext); Timer, Intervalle und Erinnerungen haben keine Summenzeile; bei „Heute“/„Letzte 24 h“ zählt die Stoppuhr-Nettozeit die ganze Sitzung, auch wenn sie vor dem Zeitraum begann. Bisher nur in Tests geprüft, noch nicht auf einem Gerät angesehen. |
| 9 | **Bedienung im Zustand:** so einfach, dass man sofort weiß, was wo ist. [04:53–05:08] | offen | Grundsatz, kein einzelnes Feature. Maßstab für 1–4: Karten und Knöpfe sind mindestens 56 px hoch (mal Knopfgröße aus den Einstellungen), wenig Text, keine Nachfragen. Noch nicht im echten Einsatz ausprobiert. |
| 10 | **Statistik für den Abend:** Knopf, der zeigt, was über den Abend zusammenkam, pro Person. [03:05–03:12] | gebaut | Über Nr. 8: „Zeitleiste“ → „Zusammenfassung“ zeigt pro Person, was wie oft und wann zuerst/zuletzt eingetragen wurde – für die laufende Sitzung, heute oder die letzten 24 Stunden. Reine Zählung: keine Mengensummen, keine Bewertung, keine Ampel (die bleibt Nr. 5). Kein eigener Knopf auf der Protokoll-Spur; der Weg führt über den Umschalter oben. Noch nicht auf einem Gerät angesehen. |

### Offene Fragen aus der Aufnahme

- **Ein Handy oder mehrere?** Bei [03:12–03:29] klingt an, dass jeder auf dem
  eigenen Handy seinen Status sieht, auch wenn alles auf einem Handy erfasst
  wurde. Das bräuchte Abgleich zwischen Geräten und widerspricht "komplett
  lokal". Ohne Abgleich geht: ein Handy erfasst für alle. So ist es jetzt
  gebaut (Nr. 1–4); die Frage nach mehreren Geräten bleibt offen.
- **Ampel-Regeln (Nr. 5):** Die Farben können nur aus selbst eingestellten
  Werten kommen (Sperrzeiten, eigene Schwellen). Die App bringt keine
  Dosierungs-, Abstands- oder Kombinationsregeln mit und bewertet keine
  Kombinationen von sich aus. Zu klären: Was genau macht rot – eine laufende
  Sperrzeit, oder braucht es selbst definierbare Kombi-Regeln ("A und B
  zusammen = rot")?
- **Szene gegen Set:** ~~Ist eine Szene ein eigenes Ding, oder reicht es, Sets
  um "wer ist dabei" und "was ist heute dran" zu erweitern?~~
  **Entschieden: Sets erweitert.** Eine Szene ist kein eigenes Ding; das Set
  bekommt die zwei Listen "wer ist dabei" und "was ist heute dran".
- **Unklare Stellen im Transkript:** [00:02] "Wurbits" (vermutlich Widgets
  oder Shortcuts auf dem Startbildschirm?), [02:11] "Notes … für Konfi",
  Namen und Substanz-Kürzel sind automatisch erkannt und können falsch
  geschrieben sein.

## Aus dem Gespräch vom 14.11. (Schnellerfassung)

"Wenn wir durch den Park laufen, sind die Vögel schnell weg, wenn man ein
bisschen laut ist. Je schneller man eingeben kann, desto besser die Daten."

| Nr. | Idee | Status | Stand in der App |
|---|---|---|---|
| 11 | **Tippfeld:** eine Ansicht nur aus großen Knöpfen, die den Bildschirm füllt; ein Tipp = ein Eintrag, nichts fragt nach, nichts verdeckt etwas. | gebaut | Ansicht „Tippfeld“ im Umschalter des Spuren-Bildschirms (pro Set gemerkt). Knöpfe in Spur-Reihenfolge: pro Zähler-Label einer (ohne Labels einer pro Zähler; der erste Tipp startet die Sitzung), pro Stoppuhr einer (Start / Runde / Fortsetzen), pro Timer, Intervall und Erinnerung einer (Start, bei „fertig“ bzw. „fällig“ ausschalten/erledigen – pausieren nur in der Spuren-Ansicht), pro Protokoll-Person einer (führt zu ihren bis zu fünf Substanz-Knöpfen plus „+“ und „Zurück“; bei genau einer Person in der Szene stehen die Substanz-Knöpfe direkt da). Jeder Knopf zeigt Farbe, Namen, Anzahl bzw. Zeit und „vor … s“ seit dem letzten Tipp. Spalten und Zeilen richten sich nach Platz und Anzahl; mindestens 72 px hoch (mal Knopfgröße), gescrollt wird nur, wenn es nicht passt. Die Knöpfe wechseln ihren Platz nicht, solange das Tippfeld offen ist. Schnelle Tipps werden der Reihe nach geschrieben, keiner geht verloren (nur ein Doppeltipp auf denselben Knopf innerhalb von 150 ms zählt einmal). Tastatur: 1–9 und 0, Rücktaste = zurücknehmen, Esc = zurück. „Bildschirm anlassen“ gilt wie überall in der App. Bisher nur in Tests geprüft – nicht im Park, nicht auf einem Gerät. |
| 12 | **Rückgängig, das nichts verdeckt:** die letzte Erfassung steht oben in einer festen Leiste mit großem „Rückgängig“. | gebaut | Feste Leiste oben im Tippfeld („Reiher · 14:02:11“), bleibt rund zehn Sekunden oder bis zur nächsten Erfassung und nimmt genau diesen einen Eintrag zurück (Tipp, Runde, Protokoll-Eintrag, Start, Ausschalten, Erledigt). Kein Rückgängig gibt es beim Starten/Fortsetzen einer exklusiven Stoppuhr, weil das andere Stoppuhren pausiert. Die Protokoll-Spur nutzt dieselbe Leiste statt der Meldung am unteren Rand. |

Offen dazu: Linkshänder-Layout spiegelt nur die Rückgängig-Leiste, nicht das
Knopfraster. Zum Löschen eines Sets bleibt dessen gemerkte Ansicht als
ungenutzter Eintrag in den Einstellungen liegen.

## Aus dem ersten Handytest am 14.11. (iPhone 12 mini, Safari)

| Nr. | Idee | Status | Stand in der App |
|---|---|---|---|
| 13 | **Unter-Spuren pro Substanz mit Timer im Streifen:** jede Substanz der Protokoll-Spur bekommt im „Streifen“ eine eigene Unter-Spur, mit eigenem Timer. | gebaut | Unter der Protokoll-Spur eine Unter-Spur pro Substanz (Reihenfolge des ersten Eintrags). Bei mehreren Personen steht jede Person als eigene Zeile darüber, ihre Substanzen eingerückt darunter; Einträge ohne Substanz bleiben auf der Personenzeile. Links neben jeder Substanz läuft die Zeit seit ihrem letzten Eintrag (`mm:ss` bzw. `h:mm:ss`), in Warnfarbe solange eine selbst eingestellte Sperrzeit läuft; nur bei offener Sitzung. |
| 14 | **Zeit zwischen zwei Einträgen anzeigen.** | gebaut | Im Streifen steht auf jeder Substanz-Unter-Spur zwischen zwei Markern der Abstand („25 min“) und vom letzten Marker bis zur Jetzt-Linie die laufende Zeit (umrandet) – jeweils nur, wo der Text Platz hat; auf dem Handy oft erst beim Hineinzoomen. Antippen eines Markers zeigt immer „25 min nach dem vorherigen“. Die Listen-Zeitleiste behält ihren Hinweis ab fünf Minuten Abstand. |
| 15 | **Größer, an iOS orientiert.** | teilweise | Schriftgrößen folgen jetzt den iOS-Textstilen (Apple HIG, Standardgröße): Text und Überschriften 17, Beschriftungen 16, Nebenzeilen 15, Fußnoten 13, Titel 22; große Zahlen 44. Streifen-Spuren 52/44 px hoch, Marker größer, Namensspalte am Handy breiter. Tippziele bleiben ≥ 48 px. Auf iOS außerdem: große Titel bei „Verlauf“ und „Einstellungen“, die beim Scrollen in die Leiste wandern (Filter und Umschalter des Verlaufs scrollen mit dem Titel weg, wie das Suchfeld in Mail); Abschnitte wie die Einstellungen-App (Kopf in Großbuchstaben, 17-pt-Zeilen, kein Ripple); in der Eintragsliste einer Protokoll-Sitzung Wischen zum Löschen (mit Rückgängig) und zwischen zwei Einträgen der Abstand („25 min früher“). Offen: Kontextmenüs bei langem Druck, große Titel auf dem Spuren-Bildschirm (dort steht der Set-Umschalter), Ansicht auf einem echten iPhone. |

## Aus der Recherche zu Open-Source-Apps (14.11.)

Quelle: `docs/ideen/INSPIRATION.md` (dort mit Screenshots-Beschreibung, Lizenzen
und Herkunft). Nur gesammelt, nichts entschieden oder gebaut.

| Nr. | Idee | Status | Stand in der App |
|---|---|---|---|
| 16 | **Laufende-Timer-Dock:** feste Leiste mit allen laufenden Spuren, auf jedem Reiter sichtbar; Tipp = pausieren/stoppen. (babytracker) | offen | Laufende Timer stehen nur in der Zeitleiste in einer festen Zeile (Nr. 8). |
| 17 | **„Fortsetzen“ mit einem Tipp** auf gerade beendeten Sitzungen in Verlauf und Zeitleiste. (babytracker) | offen | – |
| 18 | **„Gestartet vor …“:** beim Erfassen die Startzeit um Minuten nach hinten schieben (Chips 5 / 10 / 30 min). (babytracker) | offen | Zeit lässt sich über „Details“ ändern (Nr. 2), aber ohne Schnellwahl. |
| 19 | **Fisheye-Streifen:** leere Zeit stauchen, belegte dehnen; Verbindungslinien zwischen Übersicht und Detail. (TimeTagger) | offen | Der Streifen hat gleichmäßige Zeitachse mit Zoom (Nr. 13/14). |
| 20 | **Segmentbalken statt Zahl** für „n von m“ (Sitzungen, Runden, Intervalle). (Flex) | offen | – |
| 21 | **Schwebende Pillen-Navigation:** nur der gewählte Reiter mit Label, Hauptknopf schwebt darüber. (Flex) | offen | Material: NavigationBar, iOS: Cupertino-Leiste, ab 720 px Rail. |
| 22 | **Großer Ring** für Timer und Intervall mit Restzeit in der Mitte. (Flex) | offen | Dünne Fortschrittsleiste (3 px) und große Ziffern. |
| 23 | **Farbwähler mit „an Theme anpassen“** im Design-Editor. (Table Habit) | offen | Farbwähler vorhanden, ohne Anpassung an das Theme. |
| 24 | **Einklappbare Gruppen** mit Anzahl und Gruppenfarbe. (Table Habit) | offen | Sets gruppieren Spuren, ohne Einklappen. |
| 25 | **Kalender-Heatmap und Serien** auf der Detailseite einer Spur oder Substanz. (Loop Habit Tracker) | offen | Verlauf mit Tages- und Wochensummen (Nr. 10 deckt nur den Abend ab). |
| 26 | **Einstellungen als Listenzeilen** mit Icon, Titel, Untertitel und Suche. (Flex, Ice Cubes) | offen | Teil von Nr. 15 („gruppierte Listen“). |
| 27 | **„Seit …“-Zeile / Wachfenster** pro Spur („zuletzt vor 1 h 45 min“). (babytracker) | offen | Protokoll-Spur zeigt Zeit seit dem letzten Eintrag (Nr. 3, 13); andere Spuren nicht. |
| 28 | **Zen-Modus:** nur große Knöpfe auf schwarzem Grund, alles andere aus. (babytracker) | offen | Tippfeld (Nr. 11) und Theme „Schwarz“ gibt es getrennt. |

## Früher festgehalten

| Idee | Status | Quelle |
|---|---|---|
| Log pro Spur abschaltbar (Schalter in den Einstellungen) | offen | Gespräch 11.11. – im Datenmodell vorhanden, ohne Oberfläche |
| Laufende Timer auf dem Sperrbildschirm (iOS Live Activities, Android-Dauerbenachrichtigung) | offen | Konzept 11.11. |
| Abgleich zwischen Geräten | offen | Konzept 11.11. |
| Dauerhafter Alarmton mit eigenem Audio-Paket | offen | Integration 14.11. |

## Aus der Design-Runde vom 14.11. (Richtung „Pult“)

Quelle: `docs/design/` (Einstieg `README.md`, Entwürfe unter `entwuerfe/`,
Arbeitspakete in `UMSETZUNG.md`). Entworfen, noch nichts davon gebaut. Wie die
Ideen Nr. 16–28 darin aufgehen, steht in `UMSETZUNG.md` unter „Abgleich mit dem
Backlog“.

| Nr. | Idee | Status | Stand in der App |
|---|---|---|---|
| 29 | **Spur als Fläche:** die Spurfarbe trägt die ganze Spur, Timer und Intervall füllen sie als Fortschritt, bereite Spuren sind nur ein Umriss. Fünf Farbrollen je Spurfarbe, damit der Kontrast in jedem Design hält. | geplant | Paket P1 und P2. |
| 30 | **Untere Leiste mit Spuren / Tippfeld / Zeitleiste** als Wörter, Plus daneben; Einstellungen hinter „···“. | geplant | Paket P3. |
| 31 | **Erfassen in Stufen:** Wer → Was → fertig; „Ändern“ öffnet ein Blatt mit Wann und Wie viel, Wer / Was / Notiz zugeklappt. Ein Eintragsblatt für Tippfeld und Zeitleiste. | geplant | Paket P4. |
| 32 | **Zeitleiste mit vier Zoomstufen** (Jetzt, Abend, Woche, Monat); der Verlauf geht darin auf. Jetzt mit Karten je Person und Falten für leere Zeit, Abend senkrecht mit einer Spalte je Person. | geplant | Paket P5 und P6; offen sind O1–O3 in `docs/design/README.md`. |
| 33 | **„Tag beginnt um …“:** Einträge nach Mitternacht zählen zum Abend davor. | offen | Teil von P7; Standard 06:00 nicht bestätigt (O3). |
| 34 | **Designs als Vorlage plus eigene Änderungen**, mit Form, Schrift und Bewegung; neu Neon, Kassette, Arcade, Lava. Editor als Blatt unter laufenden Spuren. | geplant | Paket P8; Schriften offen (O4). |
| 35 | **Einstellungen mit festen Reitern** (Design, Bedienung, Alarme, Daten, System), Regler mit Rücksetz-Punkt. | geplant | Paket P7. |
| 36 | **Fokus:** eine Spur groß mit Ring, die anderen laufenden als Felder darunter. | geplant | Paket P9. |
| 37 | **Leerer Start mit sechs Vorlagen**, ein Tipp legt die Spur an. | geplant | Paket P9. |
