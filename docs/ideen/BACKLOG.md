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

## Früher festgehalten

| Idee | Status | Quelle |
|---|---|---|
| Log pro Spur abschaltbar (Schalter in den Einstellungen) | offen | Gespräch 11.11. – im Datenmodell vorhanden, ohne Oberfläche |
| Laufende Timer auf dem Sperrbildschirm (iOS Live Activities, Android-Dauerbenachrichtigung) | offen | Konzept 11.11. |
| Abgleich zwischen Geräten | offen | Konzept 11.11. |
| Dauerhafter Alarmton mit eigenem Audio-Paket | offen | Integration 14.11. |
