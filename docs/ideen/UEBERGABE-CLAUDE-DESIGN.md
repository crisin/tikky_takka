# Übergabe an Claude Design: Tikky Takka

Stand: 14.11.2026. Zweck: Du sollst für die App Entwürfe und Varianten
entwickeln, vor allem für das **Smartphone**. Dieses Dokument sagt, was die App
ist, was schon steht, woran sie sich orientieren soll und was feststeht. Die
Ideen (Nr. 16–28) sind **Vorschläge zum Prüfen**, keine Beschlüsse.

Weiterlesen im Repo: `README.md`, `docs/ideen/BACKLOG.md` (alle Ideen mit Status
und Stand in der App), `docs/ideen/INSPIRATION.md` (Recherche mit Quellen und
Lizenzen).

## 1. Was die App ist

Mehrere Timer gleichzeitig, als konfigurierbare **Spuren** nebeneinander. Alles
lokal auf dem Gerät, kein Konto, kein Netzwerk.

Spurtypen (`TrackMode`): **Stoppuhr, Timer (Countdown), Intervall, Zähler,
Erinnerung, Protokoll.** Spuren lassen sich zu **Sets** gruppieren (gemeinsam
starten/pausieren, umsortieren, pro Set eigenes Theme/Darstellung).

Wichtigster Grundsatz: Gespeichert werden **nur Ereignisse mit Zeitstempel**
(Start, Pause, Runde, Eintrag, Stopp …). Alle angezeigten Werte werden daraus
berechnet. Die App zählt nichts im Hintergrund.

Hauptbereiche (Navigation unten bzw. Seitenleiste ab 720 px): **Spuren,
Verlauf, Einstellungen.**

Ansichten des Spuren-Bildschirms (Umschalter oben, pro Set gemerkt):
**Spuren** (Liste der Spuren mit großer Zeit und Hauptknopf), **Tippfeld**
(Raster großer Knöpfe, ein Tipp = ein Eintrag) und **Zeitleiste** mit
Unteransichten **Streifen** (Zeit waagerecht, eine Zeile je Spur, Zoom),
**Liste** und **Zusammenfassung**.

**Protokoll-Spur:** Es werden Personen und Einträge (Substanzen o. Ä.) mit
Zeitstempel erfasst, damit man später sieht, wer wann was hatte und wie lange
zurück. Eine **Szene** (Teil des Sets) legt fest, wer dabei ist und was heute
dran ist; diese stehen bei der Erfassung vorn. Die App bewertet nichts von
sich aus (keine Dosierungs- oder Kombinationsregeln); Warnfarben kommen nur aus
selbst eingestellten Sperrzeiten.

## 2. Nutzungssituation (wichtig für jeden Entwurf)

- **Unterwegs, draußen, im Dunkeln, mit einer Hand, schnell.** Ein Zitat aus
  dem Gespräch: „Wenn wir durch den Park laufen, sind die Vögel schnell weg …
  Je schneller man eingeben kann, desto besser die Daten.“
- Beim Protokoll teilweise **eingeschränkte Aufmerksamkeit**; deshalb große
  Tippziele, wenig Text, keine Nachfragen, nichts verdeckt Knöpfe.
- Gemeint ist **ein Handy für alle** (kein Abgleich zwischen Geräten).
- Getestet wurde bisher auf einem **iPhone 12 mini (Safari, Web-Build)**.
  Bedenke also kleine Bildschirme (375 × 812) und iOS-Gewohnheiten, auch
  wenn Android ebenso unterstützt wird.

## 3. Technischer Rahmen (was feststeht)

- **Flutter**; ein Code für iOS, Android, Web, Windows. Entwürfe müssen sich in
  Flutter bauen lassen (keine Effekte, die Flutter nicht sauber kann).
- **Adaptiv:** iOS/macOS bekommen Cupertino-Elemente (Navigationsleiste,
  große Titel), Android Material 3. Ab **720 px Breite** Navigationsleiste
  seitlich und Raster. Gestalte primär das Handy und zeige, wie es sich auf
  Tablet/Desktop verhält, nur wenn es sich dort grundlegend ändert.
- **Alle Maße, Farben, Radien, Schriften kommen aus Tokens** (`lib/theme/
  tokens.dart`). Entwürfe sollten in Tokens denken, nicht in Einzelwerten.

### Aktuelle Tokens (Auszug)

| Bereich | Stand |
|---|---|
| Abstände | 2 / 4 / 8 / 12 / 16 / 24 / 32 / 48 (mal Dichte: kompakt 0,8, normal 1, geräumig 1,25) |
| Seitenrand | 16 |
| Radius | Basis 12 (einstellbar 0–40), klein ½, groß 1½ |
| Linien | 1 px Haarlinie, einstellbar 0–4 |
| Schrift | iOS-Textstile: Text und Überschrift 17, Beschriftung 16, Nebenzeile 15, Fußnote 13, Titel 22; **Ziffern groß 44**, mittel 24, klein 17 |
| Ziffern | Tabellenziffern (springen nicht), wahlweise Monospace, Gewicht 100–900 |
| Schriftfamilien | nur Systemschriften: System, Serif, Mono, Schmal. Nichts wird gebündelt oder geladen |
| Tippziele | mind. 48; Hauptknopf einer Spur 56 (rund); Nebenknöpfe 40; Protokoll-Erfassung 64; **Tippfeld-Knöpfe mind. 72 × 104**; alles mal „Knopfgröße“ aus den Einstellungen |
| Spur (Liste) | mind. 84 hoch, 4 px Farbbalken am Rand, 3 px Fortschrittsleiste |
| Streifen | Spur 52, Unterspur 44, Achse 30, Balken 22/14, Marker 13, Namensspalte 124 (Handy) bzw. 184 |
| Bewegung | 120 / 200 / 320 ms, easeOutCubic; Rückgängig-Fenster 5 s (Meldung) bzw. 10 s (Leiste) |

### Themes (alle über einen Editor änderbar)

- **Hell** (Hintergrund `#F6F6F4`, Fläche weiß), **Dunkel** (`#151517`),
  **Schwarz** (reines `#000000` für OLED), dazu System und Systemfarben
  (Android 12+) und eigene Themes.
- Je Theme: 10 Spurfarben (für hell und für dunkel getrennt abgestimmt: Blau,
  Rot, Grün, Orange, Violett, Türkis, Rosa, Braun, Schiefer, Oliv),
  semantische Farben (Gefahr, Erfolg, Warnung), Hauptfarbe ist bewusst
  **neutral (fast Schwarz/Weiß)**; Farbe kommt von den Spuren.
- Die App ist also **farbneutral gebaut, die Spurfarben tragen die
  Identität.** Bitte nicht eine feste Markenfarbe über alles legen.

### Weitere Einstellungen, die der Entwurf aushalten muss

Dichte (kompakt/normal/geräumig), Ziffergröße, Knopfgröße, **Linkshänder-Modus**
(spiegelt bisher nur die Rückgängig-Leiste), „Bildschirm anlassen“, App-Sperre,
System-Textgröße (skaliert alles weiter).

## 4. Was die Nutzer wollen (aus Aufnahme und Handytest)

Kurzfassung der Ideenliste, vollständig in `BACKLOG.md`:

1. **Ein Tipp = ein Eintrag.** Große Knöpfe, nichts lesen, nichts ausfüllen.
2. **Rückgängig, das nichts verdeckt:** feste Leiste oben mit großem Knopf.
3. **„Wer bist du?“ vor „Was?“**: Karten pro Person, dann bis zu fünf
   Vorschläge plus „+“.
4. **Zeit zwischen zwei Einträgen sehen** und **Timer je Substanz** im Streifen.
5. **„Größer, an iOS orientiert“:** große Titel, gruppierte Listen, Wischaktionen,
   Kontextmenüs sind noch offen (Nr. 15).
6. Zwei Sichten auf Einträge: **Zeitleiste zum Durchgehen** und
   **Zusammenfassung** („was ist insgesamt passiert“).
7. Noch offen: **Ampel pro Person** (Nr. 5; nur aus selbst eingestellten
   Werten, Regeln ungeklärt), Anzeige pro Szene einstellbar (Nr. 6).

## 5. Wo die Gestaltung am meisten hilft (meine Einschätzung)

1. **Streifen auf dem Handy.** Hier ist es am engsten: schmale Namensspalte,
   Marker und Abstände („25 min“) haben oft nur beim Hineinzoomen Platz.
   Idee 19 (Fisheye) setzt genau hier an.
2. **Das Zusammenspiel der Ansichten.** Drei Ansichten plus drei
   Zeitleisten-Modi, dazu Sets: Wie bleibt das auf dem Handy klar, ohne dass
   der Umschalter zur Menüwüste wird?
3. **Laufende Timer immer sichtbar** (Idee 16, Dock) bei Wechsel der Ansicht.
4. **Navigation und Hauptknopf** (Idee 21): Wo liegt der Daumen, was ist
   „Neu“, was ist „Start“?
5. **Das iOS-Gefühl** (Nr. 15, Idee 26): Titel, Listen, Wischen, Menüs.
6. **Timer-Darstellung:** große Ziffern in der Liste, evtl. Ring (Idee 22),
   Segmentbalken (Idee 20).

## 6. Inspirationen (kurz; Details in `INSPIRATION.md`)

| Projekt | Was daran interessant ist | Lizenz |
|---|---|---|
| [Flex](https://github.com/brandonp2412/Flex) | Schwebende Pillen-Navigation, großer Pausen-Ring, Segmentbalken, Stepper, Einstellungen als Listenzeilen | MIT |
| [Table Habit](https://github.com/FriesI23/mhabit) | Einklappbare, farbige Gruppen; Farbwähler mit „an Theme anpassen“ | Apache-2.0 |
| [Loop Habit Tracker](https://github.com/iSoron/uhabits) | Dichte Matrix, Kalender-Heatmap, Serien | GPL-3.0 |
| [TimeTagger](https://timetagger.app/demo) | Fisheye-Tagesansicht mit Trichterlinien (Demo ohne Konto) | GPL-3.0 |
| [babytracker](https://github.com/BeyensJ/babytracker) | Laufende-Timer-Dock, „Fortsetzen“ per Tipp, „gestartet vor …“, Zen-Modus (nur aus README bekannt, keine Bilder) | MIT |
| [Ice Cubes](https://github.com/Dimillian/IceCubesApp) | iOS-Gefühl: eine Akzentfarbe, Listen ohne Kartenrahmen | AGPL-3.0 |

Nicht angesehen, aber vorgemerkt: Immich (Timeline-Scrubber), Nomie
(Tipp-Tracker), lichess mobile (Schachuhr), OpenHIIT (Intervall-Konfiguration).

Muster und Ideen sind frei verwendbar. **Code aus GPL/AGPL-Projekten nicht
übernehmen**, solange die App selbst nicht unter einer solchen Lizenz steht
(die Lizenz der App ist im Repo nicht festgelegt).

## 7. Gewünschte Ergebnisse

Bitte zuerst **Varianten, nicht eine Lösung**, und pro Entwurf kurz sagen, was
er auf Kosten von was gewinnt.

1. **Streifen (Handy, 375 × 812):** 2–3 Varianten, darunter eine mit
   Fisheye (Idee 19) und eine ohne. Mit Beispieldaten: 4 Spuren, davon eine
   Protokoll-Spur mit 2 Personen × 3 Substanzen und Abständen.
2. **Spuren-Bildschirm (Handy):** Liste mit Dock für laufende Timer (Idee 16),
   mit und ohne Ring (Idee 22); Zustände: läuft, pausiert, Timer klingelt,
   leer.
3. **Navigation und Ansichts-Umschalter (Handy):** wie kommen Spuren /
   Tippfeld / Zeitleiste und Streifen / Liste / Zusammenfassung zusammen,
   ohne zwei Leisten übereinander?
4. **Protokoll-Erfassung:** „Wer bist du?“ → Substanz-Knöpfe → Rückgängig-Leiste,
   inklusive „Gestartet vor …“-Chips (Idee 18).
5. **Je Entwurf in drei Themes:** Hell, Dunkel, Schwarz; mit einer
   Hell-Variante mit Spurfarbe Gelb/Oliv (kritisch für Kontrast).
6. Eine **Tokenliste** zu dem, was sich gegenüber heute ändert (neue
   Abstände, Größen, Radien), damit es in `tokens.dart` landen kann.

## 8. Muss gelten

- Tippziele nie unter 48; im Tippfeld nie unter 72 hoch. Mit „Knopfgröße“ und
  „geräumig“ prüfen.
- **Kontrast** in allen Themes und mit allen 10 Spurfarben (WCAG AA für Text;
  Farbe nie als einziger Träger: Spuren haben auch Namen, Muster oder Form).
- Texte auf **Deutsch**, kurz. Keine englischen Platzhalter.
- Keine Nachfragen-Dialoge im Erfassungsweg. Löschen mit Rückgängig statt
  Bestätigen.
- Nichts darf Knöpfe im Tippfeld verdecken oder verschieben, solange es offen
  ist.
- Keine Animation, die Ziffern springen lässt (Tabellenziffern beibehalten).
- Keine Bewertung von Personen oder Substanzen durch die App (keine
  „gefährlich“-Hinweise von sich aus).

## 9. Was ich nicht weiß

- **Es gibt keine Screenshots der eigenen App in diesem Repo.** Der Web-Build
  liegt unter `build/web` und kann lokal gestartet werden (`README.md`, Abschnitt
  „Web“); der Streifen und die Zeitleiste sind laut Backlog „bisher nur in
  Tests geprüft, noch nicht auf einem Gerät angesehen“. Bitte vor dem Entwerfen
  auf einem echten Handy ansehen oder Screenshots mitgeben lassen.
- Ob die Nutzer **Android oder iOS** überwiegend haben, ist nicht festgelegt;
  getestet wurde auf iOS.
- Die Quellen zu Immich und Nomie stammen nur aus Suchergebnissen.
