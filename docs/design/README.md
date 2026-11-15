# Tikky Takka – Design „Pult“

Stand: 14.11.2026. Ergebnis der Design-Runde nach `docs/ideen/UEBERGABE-CLAUDE-DESIGN.md`.
Dieser Ordner ist die Vorlage für die Umsetzung in Flutter.

## Was hier liegt

| Datei | Inhalt |
|---|---|
| `README.md` | dieser Einstieg: was entschieden ist, was offen ist |
| `FLOWS.md` | Aufbau der App und jeder Bildschirm mit seinen Regeln (Spuren, Tippfeld, Erfassen, Zeitleiste, Einstellungen) |
| `DESIGNS.md` | Design-Modell, die sieben Designs, alle Tokens, Kontrastregeln, Bewegung |
| `UMSETZUNG.md` | Arbeitspakete in sinnvoller Reihenfolge, mit den Dateien in `lib/`, die sie betreffen |
| `PLAN.md` | die Pakete als einzelne Schritte, gegen den Code geprüft, mit den anstehenden Entscheidungen |
| `tokens.json` | alle Farb- und Formwerte der sieben Designs, maschinenlesbar |
| `entwuerfe/` | 25 Bildschirme als HTML (im Browser öffnen: `entwuerfe/index.html`) und als PNG (750 × 1624, also 375 × 812 in doppelter Auflösung) |

Die HTML-Seiten sind die genaue Vorlage: alle Maße, Farben und Abstände stehen in
`entwuerfe/tikky.css` und im Markup der Seite. Unter jedem Bildschirm lässt sich
das Design umschalten. Die PNGs zeigen jeden Bildschirm in seinem Standard-Design.

Die Seiten laden vier Schriften von Google Fonts; ohne Netz erscheinen
Ersatzschriften.

## Entschieden

1. **Richtung A „Pult“.** Die Spurfarbe wird zur Fläche, laufende Spuren sind
   laut, bereite nur ein Umriss. B (Nativ) und C (Anzeigetafel) sind verworfen.
2. **Drei Ansichten in der unteren Leiste:** Spuren, Tippfeld, Zeitleiste, als
   Wörter. Rechts daneben das Plus. Einstellungen, Designs und Export liegen
   hinter „···“ oben rechts.
3. **Der Verlauf geht in der Zeitleiste auf.** Vier Zoomstufen auf einer Achse:
   Jetzt, Abend, Woche, Monat.
4. **Die Zeitleiste beantwortet zuerst „wer, wann, was“** und danach „über Tage
   und Wochen“.
5. **Designs mit Bewegung.** Farben, Formen, Schriften und animierte
   Hintergründe; Flächen bleiben deckend, beim Erfassen steht der Hintergrund
   still.
6. **Erfassen in Stufen:** Wer → Was → fertig. Zeit, Menge und Notiz kommen
   erst auf „Ändern“.

## Offen (noch nicht entschieden)

Diese Punkte sind in den Entwürfen so gezeichnet, aber nicht bestätigt. Vor dem
Bauen des jeweiligen Pakets klären.

| Nr. | Frage | So gezeichnet |
|---|---|---|
| O1 | **Abend senkrecht?** Neue Ansicht mit einer Spalte pro Person neben dem bestehenden waagerechten Streifen. | senkrecht |
| O2 | **Liste und Zusammenfassung** sind keine eigenen Ansichten mehr. Reicht „Kompakt“ im Abend und Summen in Spaltenkopf, Woche und Monat? | ja |
| O3 | **„Tag beginnt um 06:00“** als neue Einstellung, damit Einträge nach Mitternacht zum Abend davor zählen. Passt 06:00 als Standard? | 06:00 |
| O4 | **Vier gebündelte Schriften** (Martian Mono, Space Mono, Silkscreen, Fredoka). Nach den Einträgen bei Google Fonts und Font Squirrel stehen sie unter der SIL Open Font License; die Lizenztexte selbst sind nicht nachgelesen. Tabellenziffern sind für keine der vier geprüft. | alle vier |
| O5 | **Anzahl (×3) auf den Erfassen-Feldern:** immer sichtbar oder erst mit Schalter? Entschieden: **mit Schalter, Standard aus**. | immer |
| O6 | **Ampel pro Person** (Backlog Nr. 5) ist nicht gezeichnet. Die Karten in „Jetzt“ zeigen nur die Zeit seit dem letzten Eintrag und den selbst eingestellten Abstand. | keine Ampel |
| O7 | **Wie kommt man in den Fokus?** Vorschlag: Tippen auf die Spur außerhalb der Knöpfe; langer Druck bleibt Bearbeiten. Ebenfalls nur Vorschlag: Stufenwechsel der Zeitleiste mit zwei Fingern und die Schwelle für Falten (20 Minuten). | Tippen |

## Nicht gezeichnet

App-Sperre, Alarm-Erlaubnis, Export-Dialog, Diagnose, Personen und Sachen
verwalten (samt Abstand festlegen), die Einstellungs-Reiter Alarme / Daten /
System, die Editor-Reiter Farbe / Form / Schrift, die Kompakt-Ansicht des
Abends, der klingelnde Timer in der Leiste über dem Tippfeld, Linkshänder-
Spiegelung, Tablet und Desktop. Für diese Teile gilt die bestehende App, bis es
einen Entwurf gibt.

## Was geprüft ist und was nicht

- **Gerendert und angesehen:** alle 25 HTML-Seiten in Chromium bei 375 × 812,
  jeweils im Standard-Design der Seite. Vier Fehler sind dabei aufgefallen und
  behoben (überlaufender Text in der Rückgängig-Leiste, Ellipsen statt
  abgerundeter Rechtecke in Woche und Monat, Jetzt-Linie über einem Eintrag,
  umbrechende Zeile im Design-Editor).
- **Gerechnet:** Kontrast für Text, Nebentext, Warntext und alle zehn
  Spurfarben in allen sieben Designs (Tabelle in `DESIGNS.md`).
- **Nicht geprüft:** jede Seite in jedem der sieben Designs, andere Browser,
  ein echtes Gerät, große System-Textgröße, „geräumig“ und große Knopfgröße,
  lange Namen. Die Maße sind auf 375 × 812 ausgelegt; das iPhone 12 mini hat
  genau diese Größe.
- **Unter 48 px:** die Eintrags-Chips im Abend (20 px hoch), die Wochenzeilen
  (42 px), die Kalenderzellen (46 px), der Regler-Griff. Für Knöpfe gilt 48 px
  weiter; diese vier Stellen brauchen beim Bauen eine größere Trefferfläche
  oder eine bewusste Ausnahme.

## Beispieldaten

Set „Festival“ mit fünf Spuren: Unterwegs (Stoppuhr), Nudeln (Timer 10:00),
Vögel (Zähler mit Reiher / Amsel / Meise), Abend (Protokoll mit Krille und
Jacke), Dehnen (Intervall 5 × 0:45). Bier, Wasser, Mate, Kippe und Kaffee sind
Platzhalter für die Sachen im Protokoll. Alle Zeitleisten-Stufen rechnen aus
demselben Datensatz (Samstag 15 Einträge, Woche 39, Bier im November 20).

## Woher die Entwürfe kommen

Die Leinwand liegt bei Claude (privat, nur für Crisin):
<https://claude.ai/code/artifact/c69d5557-cbad-49a7-8ed3-a123f54e7f1d>.
Die Dateien in `entwuerfe/` sind ein Abzug davon und reichen für die Umsetzung;
bei späteren Design-Runden wird dieser Ordner neu erzeugt.
