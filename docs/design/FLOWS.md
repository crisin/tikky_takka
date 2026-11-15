# Aufbau und Flows

Jeder Abschnitt nennt den Entwurf (`entwuerfe/<name>.html` und `.png`), was der
Bildschirm zeigt und welche Regeln gelten. Maße in logischen Pixeln bei
375 × 812, Dichte „normal“, Knopf- und Zifferngröße 100 %.

## 0. Aufbau der App

```
Set-Titel ▾ (Sets und Szene)                     ⏸ alle     ··· (Einstellungen, Designs, Export)
┌──────────────────────────────────────────────────────────────────────────┐
│  Spuren            Tippfeld                  Zeitleiste                  │
│  Liste der Spuren  große Felder,             Jetzt · Abend · Woche ·     │
│  mit Zeit und      ein Tipp = ein Eintrag    Monat                       │
│  Hauptknopf                                                              │
└──────────────────────────────────────────────────────────────────────────┘
[ Spuren | Tippfeld | Zeitleiste ]   ( + )        ← untere Leiste, immer da
```

- **Untere Leiste:** Pille mit drei Wörtern, 56 hoch, darin der gewählte Reiter
  in `primary`/`onPrimary`. Rechts ein runder Plus-Knopf (56) für „Neue Spur“.
  Abstand 12 zum Rand, 30 zum unteren Rand (Home-Balken).
- **Kopf:** Set-Name groß (30/700) mit Pfeil; darunter „5 Spuren · 4 aktiv“
  (13, Nebentext). Tippen öffnet „Sets und Szene“. Rechts zwei runde Knöpfe
  (48): „Alle pausieren“ und „···“.
- **„···“** führt zu Einstellungen (dort Designs) und zum Export. Verlauf gibt
  es nicht mehr als eigenen Bereich.
- **Oben 54–58 frei** für die Statusleiste; die Entwürfe zeichnen keine.
- **Fensterarten** (von Vizzy übernommen, damit sich nichts doppelt):
  *Ansicht* (die drei Reiter), *Blatt* (von unten, gehört zu dem, was darunter
  liegt: Neue Spur, Sets und Szene, Eintrag, Design anpassen), *Seite* (mit
  Zurück-Pfeil: Einstellungen, Designs, Anderes, Fokus).
- **Rückgängig statt Nachfrage:** Stoppen, Löschen und Eintragen fragen nie
  nach. Die Rückgängig-Leiste steht fest oben (56 hoch) und verdeckt nichts.

## 1. Spuren

### 1.1 Leerer Start — `1-1-leerer-start`

Sechs Felder, eines je Art: Stoppuhr, Timer, Intervall, Zähler, Erinnerung,
Protokoll, jeweils mit einem Satz („zählt hoch, mit Runden“). Ein Tipp legt die
Spur mit Standardwerten an; Name, Farbe und Dauer kommen später über
Bearbeiten. Die Felder bekommen die ersten sechs Palettenfarben.

### 1.2 Spuren — `1-2-spuren`

Eine Spur ist eine getönte Fläche (`tint` der Spurfarbe, Radius 20), 12 Abstand
innen, 8 zwischen den Spuren.

- **Kopfzeile der Spur:** Lampe (8 px, Spurfarbe, pulsiert bei laufender Spur),
  Name (14/600) und Art (14/400), beide in `ink`.
- **Ziffern:** Ziffernschrift, 32 px, Gewicht 500. Darunter eine Nebenzeile
  (13, `ink`): „Runde 3 · 12:40“, „bis 23:44 · von 10:00“.
- **Knöpfe rechts:** ein Nebenknopf (48, `strong`) und der Hauptknopf (60,
  `solid` mit `on`-Farbe für das Icon). Nur ein Nebenknopf ist sichtbar:
  Stoppuhr → Runde, Timer → neu starten, Zähler → letzten Tipp zurücknehmen.
  Stoppen liegt auf langem Druck bzw. im Zustand „pausiert“ (siehe 1.3).
- **Timer und Intervall:** die Spur selbst ist der Fortschrittsbalken. Eine
  Füllung in `strong` zeigt die **Restzeit** von links und schrumpft nach
  links. Die dünne Fortschrittsleiste (3 px) entfällt.
- **Zähler mit Labels:** unter der Zeile drei Felder (48 hoch, `strong`,
  Radius 14) mit Name und Anzahl.
- **Protokoll:** statt Ziffern die Frage „Wer bist du?“ und eine Kachel pro
  Person (60 hoch): Kürzel im Kreis (Personenfarbe), Name, darunter letzter
  Eintrag und Minuten seitdem. Rechts ein schmales Plus (48) für „Andere“ und
  Szene. Tippen auf eine Person öffnet „Was?“ (2.2).
- **Bereite Spur:** keine Fläche, nur ein 1-px-Umriss in `border`; Lampe hohl;
  Name in Textfarbe, Ziffern klein (22) in Nebentext, Hauptknopf (48) nur als
  Umriss in Spurfarbe. Höhe 66 statt 101.
- **Tippen auf die Spur** (außerhalb der Knöpfe) öffnet den Fokus (1.5),
  **langer Druck** das Bearbeiten-Blatt (1.4).

### 1.3 Zustände — `1-3-zustaende`

| Zustand | Aussehen | Knöpfe |
|---|---|---|
| Timer klingelt | ganze Spur in `danger`, Schrift `onDanger`; Ziffern zählen hoch („+0:42“), Nebenzeile „klingelt seit 23:44“ | „+1′“ (Umriss), „Aus“ (gefüllt in `onDanger`) |
| pausiert | keine Fläche, Umriss 1,5 px in `strong`, Lampe hohl, Nebenzeile „pausiert seit 4 min“ | Stopp (sichern), Weiter |
| Intervall läuft | Füllung wie Timer; darunter ein Segmentbalken: fertige Runden in Spurfarbe, laufende in Textfarbe, offene in `strong` (8 hoch, 4 Abstand) | nächste Runde, Pause |
| Erinnerung fällig | Umriss 2 px in `warning`; Ziffern zählen hoch („+3:12“) | „+10′“ (später), Erledigt |
| bereit | wie 1.2 | Start bzw. +1 |

Nach **Stoppen** steht oben die Rückgängig-Leiste: „Vögel gestoppt · 10 Tipps
gesichert“ mit „Rückgängig“ und einem Balken, der die verbleibende Zeit zeigt
(10 s). Die Sitzung liegt dann in der Zeitleiste.

### 1.4 Neue Spur / Bearbeiten — `1-4-neue-spur`

Blatt von unten. Reihenfolge: Art (sechs Knöpfe, 3 × 2), Name, Dauer, Farbe,
Schalter.

- **Dauer ohne Tastatur:** „−“ und „+“ (je 1 Minute) um die große Zeit, darunter
  Schnellwahl 1 · 3 · 5 · 10 · 15 · 30 Minuten.
- **Farbe:** die zehn Palettenfarben als Felder (5 × 2, 48 hoch); die gewählte
  hat einen Ring und einen Haken.
- Welche Felder erscheinen, hängt wie heute von der Art ab; gezeichnet ist der
  Timer.

### 1.5 Fokus — `1-5-fokus`

Eine Spur groß, der Rest tritt zurück (Idee 22 und 28). Ring mit 300
Durchmesser, 14 breit: Spur in `strong`, Rest in `solid`, Start oben, läuft im
Uhrzeigersinn ab. In der Mitte die Zeit (56) und „bis 23:44“. Darunter „+1 min“,
Pause (88) und „Neu“. Unten bleiben andere laufende Spuren als schmale Felder
(52 hoch) erreichbar. Keine untere Leiste; der Pfeil oben links schließt.

## 2. Tippfeld und Protokoll

Grundsatz: Solange das Tippfeld offen ist, wechselt kein Feld seinen Platz und
nichts schiebt sich davor. Der Hintergrund eines bewegten Designs steht hier
still.

### 2.1 Tippfeld — `2-1-tippfeld`

Oben die feste Leiste (56), darunter ein Raster aus zwei Spalten, das den Platz
füllt (hier 4 Zeilen, je 143 hoch). Reihenfolge wie die Spuren.

- **Stoppuhr / Timer / Intervall:** Name oben, unten Zeit (22) und ein Hinweis
  („Tippen = Runde 4“, „läuft bis 23:44“). Der Timer zeigt die Restzeit als
  Füllung wie in 1.2. Bereite Spuren nur als Umriss.
- **Zähler:** ein Feld je Label mit Anzahl („×3“) und „vor 12 min“.
- **Protokoll:** ein Feld je Person der Szene (Kürzel, Name, letzter Eintrag).
  Tippen öffnet „Was?“.

### 2.2 Was? — `2-2-was` (Stufe 0)

Die Seite einer Person. Sie zeigt nur, was zum Eintragen nötig ist.

- **Leiste oben:** „Was hattest du?“ und „Ein Tipp trägt ein, mit der Uhrzeit
  von jetzt.“ Die Leiste hat immer dieselbe Höhe.
- **Kopf:** Zurück (48), Kürzel im Kreis (40), Name (24/700).
- **Felder:** bis zu fünf Sachen plus „Anderes“, 2 × 3, je etwa 175 hoch. Auf
  dem Feld steht der **Name groß (28/700)** und klein die Anzahl heute („×3“),
  diese nur mit dem Schalter „Anzahl auf den Erfassen-Feldern zeigen“ (O5).
- **Eine Zeit steht nur, wo ein eigener Abstand läuft:** „Abstand: noch 34 min“
  in Warnfarbe mit einem 4-px-Balken. Das Feld bleibt antippbar; die App sperrt
  nichts.
- **Keine Zeit-Knöpfe, kein Dock, keine „vor … min“-Zeilen.** Der Schalter
  `zeiten` in den Entwürfen blendet „vor 26 min“ auf allen Feldern ein, zum
  Vergleich (O5 betrifft nur die Anzahl).
- **Reihenfolge der Felder** wie heute: erst die Sachen der Szene, dann die
  häufigsten dieser Person.
- Bei genau einer Person in der Szene entfällt der Schritt „Wer“.

### 2.3 Eingetragen — `2-3-eingetragen` (Stufe 1)

Direkt nach dem Tipp, ohne dass sich etwas verschiebt:

- Das getippte Feld bekommt die starke Fläche, einen 2-px-Rand in Spurfarbe und
  „✓ eingetragen“; die Anzahl ist schon erhöht.
- Die Leiste oben zeigt „Krille · Wasser“ und „23:41 · jetzt“, daneben
  **„Ändern“** (Umriss) und **„Rückgängig“** (gefüllt). Der Balken an der
  Unterkante läuft 10 s.
- Nach etwa 900 ms (`captureConfirm`) geht die Ansicht wie heute zurück zur
  Personenwahl; die Leiste bleibt die vollen 10 s oder bis zum nächsten Eintrag.
- Ein klingelnder Timer übernimmt diese Leiste („Nudeln fertig“ / „Aus“), statt
  ein eigenes Dock zu brauchen. Nicht gezeichnet.

### 2.4 und 2.5 Ändern — `2-4-aendern`, `2-5-aendern-aufgeklappt` (Stufe 2)

Ein Blatt über der unteren Hälfte; die Felder darüber bleiben sichtbar. Es
öffnet sich nur auf „Ändern“.

- **Wann?** Jetzt · −5 min · −10 min · −30 min · Uhr. Ein Tipp verschiebt den
  eben gemachten Eintrag (Idee 18, aber nachträglich statt als Modus vorher).
- **Wie viel?** die zuletzt für diese Sache benutzten Mengen als Knöpfe, dazu
  „Andere Menge“ (Freitext). Mengen werden weiterhin nie addiert.
- **Wer, Was, Notiz** sind zugeklappte Zeilen (56 hoch) mit dem aktuellen Wert.
  Antippen klappt die Zeile auf: Wer und Was zeigen Knöpfe, Notiz ein Feld.
  Immer nur eine Zeile ist offen.
- **Unten:** „Löschen“ (Text in `danger`, mit Rückgängig) und „Fertig“.
- Änderungen gelten sofort; „Fertig“ schließt nur.

### 2.6 Anderes — `2-6-anderes`

Eigene Seite statt Formular. Die übrigen Sachen als Felder (88 hoch), auch hier
trägt ein Tipp ein. Darunter „Steht nicht da? Neu anlegen“: ein Namensfeld und
„Eintragen“. Farbe und Abstand der neuen Sache kommen später über die
Verwaltung.

### 2.7 Sets und Szene — `2-7-sets-und-szene`

Ein Blatt für beides, erreichbar über den Set-Titel.

- **Sets:** Zeilen mit Name, „5 Spuren · 4 aktiv“, dem Design des Sets als
  kleines Schild und einem Haken beim aktiven. „+ Neues Set“ oben rechts.
- **Szene für das aktive Set:** „Wer ist dabei?“ und „Was ist dran?“ als Knöpfe
  zum An- und Abwählen (gewählt = volle Farbe). Reihenfolge des Antippens =
  Reihenfolge beim Erfassen, wie heute.

## 3. Zeitleiste

Eine Zeitachse, vier Zoomstufen. Der Umschalter (Jetzt · Abend · Woche · Monat)
sitzt als Pille (48 hoch) unter dem Kopf. Oben rechts Filter (Personen, Spuren,
Start und Stopp) und Export des sichtbaren Zeitraums. Zwei Steuerzeilen statt
vier.

Übergänge: Tag in der Woche antippen → Abend dieses Tages. Tag im Monat
antippen → Abend. Eintrag antippen → Eintragsblatt (3.5). Zusammenziehen und
Aufziehen mit zwei Fingern wechselt die Stufe.

### 3.1 Jetzt — `3-1-jetzt`

Standardansicht. Beantwortet „wer hatte zuletzt was, und wie lange ist das
her“.

- **Karte pro Person** (2 Spalten, 95 hoch): Kürzel, Name, groß die Zeit seit
  dem maßgeblichen Eintrag („26:14 seit Bier“), darunter eine Zeile. Maßgeblich
  ist die Sache mit laufendem eigenem Abstand, sonst der letzte Eintrag. Läuft
  ein Abstand, steht dort „Abstand: noch 34 min“ in Warnfarbe, sonst der
  zweitletzte Eintrag in Nebentext. Tippen öffnet „Was?“ für die Person.
- **Streifen** der letzten rund zwei Stunden, waagerecht, volle Breite. Es gibt
  **keine Namensspalte** mehr: der Name steht in einer eigenen Zeile über der
  Spur, links daneben läuft die Zeit.
- **Personen zuerst.** Eine Person ist auf- oder zugeklappt:
  - *zugeklappt:* alle Einträge auf einer Zeile, farbig nach Sache, die Sache
    steht unter dem Punkt.
  - *aufgeklappt:* eine Zeile pro Sache (40 hoch). Zwischen zwei Punkten steht
    der Abstand („1 h“), vom letzten Punkt bis zur Jetzt-Linie die laufende
    Zeit im Rahmen („26 min“). Text erscheint nur, wo mindestens 56 px Platz
    sind. Läuft ein eigener Abstand, liegt ein Band in Warnfarbe (18 %)
    dahinter und die laufende Zeit ist in Warnfarbe.
- **Übrige Spuren kompakt** darunter (32 je Spur): Name und Wert in einer Zeile,
  darunter ein 12-px-Balken. Stoppuhr mit Lücken für Runden, Timer mit
  gestricheltem Rest bis zum geplanten Ende, Zähler mit Bündeln („4“, „5“).
- **Falte:** eine Strecke ohne jeden Eintrag wird auf 24 px gestaucht,
  schraffiert, mit der Dauer an der Achse („27 min“). Balken laufen durch. Vor
  und hinter der Falte gilt derselbe Maßstab. Vorschlag für die Schwelle: ab
  20 Minuten ohne Ereignis, nie die letzten 10 Minuten vor „jetzt“.
- **Jetzt-Linie** bei etwa 85 % der Breite, 1,5 px, mit der Uhrzeit als Schild.
- Unten rechts „Alles“ und „Jetzt“ statt der vier Zoom-Knöpfe; Zoom sonst mit
  zwei Fingern.
- Punkte haben eine Trefferfläche von 48 × 48.

### 3.2 Abend — `3-2-abend` (offen: O1)

Der ganze Abend auf einer Seite, ohne Scrollen. Die Zeit läuft **senkrecht**
von oben (Beginn) nach unten (jetzt), wie eine Kalender-Tagesansicht.

- **Blättern:** „‹ Sa. 14.11. ›“ mit „Abend · seit 20:50“. Rechts der Schalter
  „Kompakt“: gleiche Spalten ohne Maßstab, ein Eintrag pro Zeile mit Uhrzeit –
  das ersetzt die heutige Liste.
- **Spalten:** Uhrzeit (42 breit) · Spuren (46) · eine Spalte je Person. Hat
  das Set kein Protokoll, bekommt jede Spur eine Spalte.
- **Spaltenkopf je Person:** Kürzel, Name, darunter die Summen („Kippe 4 ·
  Bier 3 · Wasser 2 · Mate 1“). Das ersetzt die Zusammenfassung für den Abend.
- **Eintrag:** ein kleines Schild mit dem Namen der Sache (20 hoch, Fläche
  `tint`, Schrift `ink`). Liegen zwei Einträge enger als 22 px, rutscht der
  zweite in den rechten Platz der Spalte (zwei Plätze je Person).
- **Sache antippen:** alle Einträge dieser Sache bei dieser Person werden voll
  eingefärbt, eine Linie am linken Spaltenrand verbindet sie bis „jetzt“, und
  unter dem Spaltenkopf erscheint die **Kette**:
  `Bier  21:20  55 min  22:15  1 h  23:15  26 min  jetzt`. Der letzte Abstand
  ist in Warnfarbe, wenn ein eigener Abstand läuft.
- **Spuren-Spalte:** je Spur ein senkrechter 8-px-Balken (Stoppuhr mit Lücken
  für Runden, Timer mit gestricheltem Rest).
- **Jetzt-Linie** waagerecht mit Uhrzeit in der Zeitspalte; darunter ist die
  Zukunft schraffiert. Läuft ein Abstand, steht dort „Abstand bis 00:15“.
- Maßstab: Beginn des Abends bis zur nächsten vollen Stunde nach „jetzt“,
  auf die verfügbare Höhe verteilt (hier 210 Minuten auf 396 px).

### 3.3 Woche — `3-3-woche`

- **Blättern:** „‹ 9. – 15. November ›“ mit Kalenderwoche.
- **Sieben Zeilen** (42 hoch): Wochentag und Datum, ein Streifen von 18 bis
  6 Uhr, rechts die Anzahl. Jeder Eintrag ist ein 3-px-Strich in der Farbe der
  Sache. Heute hat einen Rahmen und die Jetzt-Linie; Tage in der Zukunft sind
  blass.
- **Darunter „Diese Woche · 39 Einträge“:** je Sache ein Balken mit Anzahl,
  absteigend.
- Der Streifen zeigt das Fenster von 12 Stunden um die Nacht, weil dort die
  Einträge liegen. Welche 12 Stunden das sind, hängt an „Tag beginnt um“
  (offen: O3): Beginn des Tages minus 12 Stunden bis Beginn des Tages.

### 3.4 Monat — `3-4-monat`

- **Blättern:** „‹ November 2026 ›“.
- **Was zählen:** Knöpfe „Alles · Bier · Kippe · Wasser · Mate“; die Reihe
  scrollt seitlich.
- **Kalender** Montag bis Sonntag, sechs Zeilen. Vier Stufen nach Anzahl:
  0 → Fläche, 1–2 → `tint`, 3–4 → `strong`, ab 5 → `solid`. Die Anzahl steht
  unten rechts in der Zelle. Heute hat einen Ring, künftige Tage nur einen
  Umriss, Tage anderer Monate sind blass.
- **Drei Kennzahlen:** Anzahl im Monat, Tage mit Eintrag, längste Pause in
  Tagen. Reine Zählung, keine Bewertung.

### 3.5 Eintrag — `3-5-eintrag`

Dasselbe Blatt wie 2.4, geöffnet aus der Zeitleiste. Unterschiede: „Wann?“
zeigt die genaue Uhrzeit mit −5 / −1 / +1 / +5, die Unterzeile nennt den
Abstand zum vorherigen Eintrag („1 h nach dem vorherigen · vor 26 min“), und
unten gibt es „Nochmal jetzt“ (derselbe Eintrag mit der Uhrzeit von jetzt,
Idee 17).

Es gibt genau ein Eintragsblatt in der App. Es ersetzt das heutige
Eintragsblatt des Protokolls und das Ereignisblatt der Zeitleiste.

## 4. Einstellungen und Designs

### 4.1 Einstellungen — `4-1-einstellungen`

Eine Seite mit **festen Reitern in immer gleicher Reihenfolge:** Design ·
Bedienung · Alarme · Daten · System. Nichts verschwindet je nach Zustand; was
gerade nicht geht, ist ausgegraut mit Hinweis (z. B. Alarme im Web).

- **Vorschau bleibt oben stehen:** eine laufende Spur, an der man jede Änderung
  sofort sieht.
- **Regler-Zeile:** Name, Wert rechts, darunter der Regler. Weicht der Wert vom
  Standard ab, steht ein Punkt in Warnfarbe am Namen; Antippen des Punkts setzt
  zurück.
- **Bedienung** (gezeichnet): Knopfgröße, Zifferngröße, Dichte (Kompakt /
  Normal / Geräumig), Linkshänder, Haptik, „Tag beginnt um“.
- **Verteilung der übrigen Einstellungen** (nicht gezeichnet): Design → 4.2;
  Alarme → Erlaubnis, Ton und Vibration; Daten → Export, Sicherung, Import,
  Personen und Sachen; System → App-Sperre, Bildschirm anlassen, 24-Stunden-
  Format, Diagnose, Über.

### 4.2 Designs — `4-2-designs`

- **Geltung:** „Überall“ oder „Nur im Set …“ (die bestehende Set-Überschreibung).
- **Kacheln** (2 Spalten): jede zeigt eine kleine Spur im jeweiligen Design mit
  dessen Schrift, Radius und Farben, darunter Name und ein Wort zur Bewegung
  („ruhig“, „glüht“, „Band läuft“, „blinkt“, „fließt“). Das aktive Design hat
  einen Rahmen und „✓ aktiv“. Antippen wendet sofort an.
- Letzte Kachel „Eigenes Design – von einer Vorlage aus“.
- Unten „<Design> anpassen“.

### 4.3 Design anpassen — `4-3-design-anpassen`

Ein Blatt unter zwei echten, laufenden Spuren: die Wirkung ist immer zu sehen.

- **Vorlagen-Pille:** „‹ Neon ›“ blättert durch die Designs; darunter steht,
  wie viele Werte geändert sind. „Zurücksetzen“ verwirft die Änderungen an
  diesem Design.
- **Feste Reiter:** Farbe · Form · Schrift · Bewegung.
- **Bewegung** (gezeichnet): Hintergrund (Aus / Raster / Lava / Sterne),
  Laufende Spuren (Ruhig / Puls / Glühen), Tempo, „Beim Erfassen ruhig“.
- **Kontrast-Zeile** unten: „Kontrast geprüft: alle 10 Spurfarben lesbar.“ Bei
  einem Verstoß steht dort, welche Farbe auf welcher Fläche durchfällt.
- Inhalt der anderen Reiter steht in `DESIGNS.md`.

## 5. Dieselbe Seite in fünf Designs

`5-1-hell-oliv-test`, `5-2-neon`, `5-3-kassette`, `5-4-arcade`, `5-5-lava`
zeigen 1.2 in den übrigen Designs. Sie belegen, dass ein Design nur Tokens und
ein paar Zusätze tauscht; der Aufbau bleibt gleich.
