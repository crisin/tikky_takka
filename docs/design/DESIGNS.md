# Designs und Tokens

Maßgeblich sind `tokens.json` (alle Werte) und `entwuerfe/tikky.css` (wie sie
verwendet werden). Diese Datei erklärt das Modell und nennt die Regeln.

## 1. Modell

Übernommen von bitster (`src/theme/look.ts`): **Ein Design ist eine Vorlage
plus die eigenen Änderungen daran.**

- Die sieben Vorlagen sind fest eingebaut und unveränderlich.
- Änderungen liegen je Design getrennt (`looks[designId]`). Neon anpassen
  ändert Kassette nicht.
- „Zurücksetzen“ löscht die Änderungen; die Vorlage scheint wieder durch.
- Ein „eigenes Design“ ist eine Vorlage mit Änderungen unter eigenem Namen.
- Wie heute kann ein Set ein eigenes Design haben („Nur im Set …“).

Nicht pro Design, sondern für die ganze App (gehört dem Menschen, nicht dem
Look): Knopfgröße, Zifferngröße, Dichte, Linkshänder, „Bewegung reduzieren“.

Ein Design besteht aus vier Teilen, die im Editor je einen Reiter haben:

| Reiter | Was er einstellt |
|---|---|
| **Farbe** | Hintergrund, Fläche, Text, Hauptfarbe (`primary`), die zehn Spurfarben; Schalter „Spurfarben ans Design anpassen“ (Idee 23) |
| **Form** | Radien, Randbreite, Schatten bzw. Glühen |
| **Schrift** | Schrift für Text, Titel und Ziffern; Gewicht der Ziffern |
| **Bewegung** | Hintergrund-Effekt, Verhalten laufender Spuren, Tempo, „Beim Erfassen ruhig“ |

## 2. Farbrollen

### Grundfarben

Die bestehenden Felder von `TikkyColors` bleiben. Neu ist nur `warningText`:
Warnfarbe, so weit abgedunkelt bzw. aufgehellt, dass sie als Schrift auf der
schlechtesten getönten Fläche des Designs 4,6:1 erreicht.

`textMuted` ist in jedem Design so gewählt, dass es auch auf getönten Flächen
4,5:1 erreicht. Deshalb weicht es in Schwarz, Dunkel und Hell leicht von den
heutigen Werten ab (z. B. Hell `#64645F` statt `#6F6F6A`).

### Fünf Rollen je Spurfarbe

Heute hat eine Spurfarbe einen Wert. Neu hat sie fünf, alle aus dem einen Wert
gerechnet:

| Rolle | Wofür | Rechnung |
|---|---|---|
| `solid` | Hauptknopf, Lampe, Balken, gewählter Knopf | die Palettenfarbe selbst |
| `tint` | Fläche einer Spur oder eines Felds | `solid` zu 18 % über den Hintergrund gemischt (helle Designs: 14 %) |
| `strong` | Fortschritts-Füllung, Nebenknopf, Label-Felder, gedrücktes Feld | `solid` zu 34 % über den Hintergrund (hell: 28 %) |
| `ink` | Schrift in Spurfarbe auf `tint` und `strong` | `solid`, in 1-%-Schritten Richtung Weiß (dunkle Designs) bzw. Schwarz (helle) gemischt, bis 4,6:1 gegen `strong` erreicht sind |
| `on` | Schrift und Icon auf `solid` | Schwarz oder Weiß, je nachdem, was mehr Kontrast hat |

Gemischt wird linear je Kanal in sRGB (`Color.lerp`). Der Kontrast ist der
WCAG-Wert; `contrastRatio` in `lib/features/settings/contrast.dart` rechnet ihn
bereits.

### Regeln

1. **Spurfarbe nie direkt als Schriftfarbe.** In „Hell“ erreichen neun von
   zehn Palettenfarben auf dem Hintergrund keine 4,5:1 (Orange und Oliv 2,4:1).
   Schrift in Spurfarbe ist immer `ink`.
2. **Auf getönten Flächen kein Nebentext-Grau für Wichtiges.** Nebenzeilen
   einer Spur stehen in `ink`.
3. **Farbe ist nie der einzige Träger.** Jede Spur hat ihren Namen, jeder
   Eintrag sein Wort; laufend / bereit unterscheidet sich auch durch Fläche
   gegen Umriss und volle gegen hohle Lampe.
4. **Warnfarbe kommt nur aus selbst eingestellten Abständen**, `danger` nur vom
   klingelnden Timer und von „Löschen“.
5. **Der Kontrast-Wächter** im Editor prüft nach jeder Änderung alle Paare aus
   der Tabelle unten und nennt das Paar, das durchfällt.

### Grundfarben

| Token | Schwarz | Dunkel | Hell | Neon | Kassette | Arcade | Lava |
|---|---|---|---|---|---|---|---|
| `background` | `#000000` | `#151517` | `#F6F6F4` | `#06030F` | `#EDE0C4` | `#0B0B24` | `#170A2C` |
| `surface` | `#141416` | `#1E1E21` | `#FFFFFF` | `#120A26` | `#F7EEDA` | `#16163F` | `#24133F` |
| `text` | `#F2F2F2` | `#F0F0EC` | `#1A1A18` | `#F6F1FF` | `#2A1A0E` | `#F4F4FF` | `#FFF5FB` |
| `textMuted` | `#8B8B91` | `#9D9DA3` | `#64645F` | `#A99BCB` | `#685444` | `#A3A3DC` | `#BFAAD9` |
| `border` | `#26262A` | `#34343A` | `#DEDEDA` | `#2C2050` | `#C9B58C` | `#34347A` | `#3D2766` |
| `primary` | `#FFFFFF` | `#F2F2EE` | `#1F1F1D` | `#2EF2FF` | `#2A1A0E` | `#FFE14D` | `#FFF5FB` |
| `onPrimary` | `#000000` | `#151517` | `#FFFFFF` | `#001316` | `#F7EEDA` | `#1A1400` | `#170A2C` |
| `danger` | `#FF6B6E` | `#FF6B6E` | `#D13438` | `#FF4D6D` | `#C2371B` | `#FF4D4D` | `#FF6B8B` |
| `warning` | `#FFB454` | `#FFB454` | `#C77700` | `#FFC53D` | `#B86A00` | `#FFB020` | `#FFC46B` |
| `warningText` | `#FFB454` | `#FFB454` | `#8D5400` | `#FFC53D` | `#7F4900` | `#FFB020` | `#FFC46B` |

### Form und Schrift

| Token | Schwarz | Dunkel | Hell | Neon | Kassette | Arcade | Lava |
|---|---|---|---|---|---|---|---|
| Schrift Text | System | System | System | System | System | System | Fredoka |
| Schrift Titel | System | System | System | System | Space Mono | Silkscreen | Fredoka |
| Schrift Ziffern | Martian Mono | Martian Mono | Martian Mono | Martian Mono | Space Mono | Silkscreen | Fredoka |
| Ziffern groß | 32px | 32px | 32px | 32px | 30px | 28px | 34px |
| Ziffern Gewicht | 500 | 500 | 500 | 500 | 700 | 400 | 600 |
| Radius Spur | 20px | 20px | 20px | 14px | 10px | 0px | 28px |
| Radius Feld | 22px | 22px | 22px | 16px | 12px | 0px | 32px |
| Radius klein | 14px | 14px | 14px | 10px | 8px | 0px | 18px |
| Radius Knopf | 50% | 50% | 50% | 50% | 12px | 0px | 50% |
| Radius Pille | 999px | 999px | 999px | 999px | 12px | 0px | 999px |
| Rand | 0px | 0px | 0px | 1.5px | 2px | 2px | 0px |

### Spurfarben mit Rollen (Design „Schwarz“ und „Hell“; alle sieben stehen in `tokens.json`)

**Schwarz**

| Farbe | solid | tint | strong | ink | on |
|---|---|---|---|---|---|
| Blau | `#6EA8FF` | `#141E2E` | `#253957` | `#6EA8FF` | `#000000` |
| Rot | `#FF7A7F` | `#2E1617` | `#57292B` | `#FF7A7F` | `#000000` |
| Grün | `#5BD19B` | `#10261C` | `#1F4735` | `#5BD19B` | `#000000` |
| Orange | `#FFB454` | `#2E200F` | `#573D1D` | `#FFB454` | `#000000` |
| Violett | `#BF8CF2` | `#22192C` | `#413052` | `#BF8CF2` | `#000000` |
| Türkis | `#4FD1DC` | `#0E2628` | `#1B474B` | `#4FD1DC` | `#000000` |
| Rosa | `#F27CC4` | `#2C1623` | `#522A43` | `#F27CC4` | `#000000` |
| Braun | `#C9A46B` | `#241E13` | `#443824` | `#C9A46B` | `#000000` |
| Schiefer | `#9AA5B1` | `#1C1E20` | `#34383C` | `#9AA5B1` | `#000000` |
| Oliv | `#E2CF45` | `#29250C` | `#4D4617` | `#E2CF45` | `#000000` |

**Hell**

| Farbe | solid | tint | strong | ink | on |
|---|---|---|---|---|---|
| Blau | `#2F6FED` | `#DAE3F3` | `#BED0F2` | `#2352AF` | `#000000` |
| Rot | `#E5484D` | `#F4DEDD` | `#F1C5C5` | `#9C3134` | `#000000` |
| Grün | `#2E9E6B` | `#DAEAE1` | `#BEDDCE` | `#1E6847` | `#000000` |
| Orange | `#E38B14` | `#F3E7D5` | `#F1D8B5` | `#88530C` | `#000000` |
| Violett | `#8E4EC6` | `#E7DEEE` | `#D9C7E7` | `#703E9C` | `#FFFFFF` |
| Türkis | `#0E9AA7` | `#D6E9E9` | `#B5DCDE` | `#09646D` | `#000000` |
| Rosa | `#D6409F` | `#F2DDE8` | `#EDC3DC` | `#962D6F` | `#000000` |
| Braun | `#8D6E3F` | `#E7E3DB` | `#D9D0C1` | `#6B5430` | `#FFFFFF` |
| Schiefer | `#6E7781` | `#E3E4E4` | `#D0D2D4` | `#525961` | `#000000` |
| Oliv | `#B7A200` | `#EDEAD2` | `#E4DEB0` | `#6C6000` | `#000000` |

### Gerechnete Kontraste (schlechtester Fall je Design)

| Design | Text auf Hintergrund | Nebentext auf getönter Fläche | Spurfarben-Rollen (Minimum) | Warntext auf getönter Fläche | auf `primary` | auf `danger` |
|---|---|---|---|---|---|---|
| Schwarz | 18.8 | 4.5 | 4.7 | 8.7 | 21.0 | 7.6 |
| Dunkel | 16.0 | 4.5 | 4.6 | 6.9 | 16.2 | 7.6 |
| Hell | 16.1 | 4.6 | 4.6 | 4.7 | 16.5 | 4.9 |
| Neon | 18.4 | 5.3 | 4.6 | 8.6 | 13.8 | 6.5 |
| Kassette | 12.8 | 4.5 | 4.6 | 4.7 | 14.5 | 5.4 |
| Arcade | 17.7 | 5.1 | 4.6 | 6.7 | 14.1 | 6.4 |
| Lava | 17.7 | 6.2 | 4.6 | 8.3 | 17.7 | 7.7 |

## 3. Die sieben Designs

| Design | Charakter | Besonderheiten über die Tokens hinaus | Bewegung |
|---|---|---|---|
| **Schwarz** | Standard, reines Schwarz für OLED | – | Lampe laufender Spuren pulsiert (2 s) |
| **Dunkel** | wie Schwarz auf Dunkelgrau | – | wie Schwarz |
| **Hell** | wie Schwarz auf hellem Grund | – | wie Schwarz |
| **Neon** | fast schwarzes Violett, türkise Hauptfarbe | Spuren und Felder mit 1,5-px-Rand und Glühen in Spurfarbe; Ziffern glühen; feine Rasterlinien im Hintergrund | laufende Spuren „atmen“ (Glühen 20 → 30 px, 2,6 s) |
| **Kassette** | Creme und Dunkelbraun, harte Kanten | 2-px-Rand in Textfarbe, harter Schatten nach unten (3 px), 7-px-Streifen in Spurfarbe am oberen Rand jeder Spur; Fortschritt schräg gestreift | in laufenden Spuren dreht sich eine Bandspule (4 s je Umdrehung) |
| **Arcade** | Nachtblau, gelbe Hauptfarbe, Pixelschrift | alle Radien 0; 2-px-Rand und versetzter Schatten (4 px) in Spurfarbe; Titel und Namen in Großbuchstaben; Rasterzeilen im Hintergrund | Lampe blinkt hart (1 s, zwei Stufen) |
| **Lava** | dunkles Violett, runde Schrift, große Radien | drei unscharfe Farbflecken hinter einem Schleier in Hintergrundfarbe (55 % deckend) | Flecken treiben langsam (16 / 21 / 26 s, hin und zurück) |

Was „Besonderheiten“ in Flutter heißt: Rand, Schatten, Glühen und Streifen sind
Teil der Flächen-Dekoration (`surfaceDecoration`) und damit über ein paar
zusätzliche Token steuerbar. Spule, Rasterlinien und Lava-Flecken sind eigene
kleine Widgets hinter bzw. in der Spur. Genaue Werte stehen am Ende von
`entwuerfe/tikky.css` in den Blöcken `.th-neon`, `.th-kassette`, `.th-arcade`
und `.th-lava`.

### Schriften

| Design | Text | Titel | Ziffern |
|---|---|---|---|
| Schwarz, Dunkel, Hell, Neon | System | System | Martian Mono 500, 32 px, Laufweite −0,05 em |
| Kassette | System | Space Mono 700 | Space Mono 700, 30 px |
| Arcade | System | Silkscreen 400, Großbuchstaben | Silkscreen 400, 28 px |
| Lava | Fredoka | Fredoka 700 | Fredoka 600, 34 px |

Die Ziffern sind mit 32 px kleiner als die heutigen 44 px, weil die
Ziffernschriften breiter laufen und neben der Zeit zwei Knöpfe stehen. Im Fokus
(1.5) sind es 56 px. „Zifferngröße“ aus den Einstellungen skaliert weiter.

Offen (O4): Die Schriften müssen als Dateien gebündelt werden, samt Lizenztext.
Ob sie Tabellenziffern haben, ist nicht geprüft; bei den beiden Mono-Schriften
sind alle Zeichen gleich breit, bei Silkscreen und Fredoka muss es getestet
werden. Springen die Ziffern, bekommt das Design eine andere Ziffernschrift.

## 4. Bewegung

- **Flächen bleiben deckend.** Text steht nie direkt auf bewegtem Hintergrund;
  dazwischen liegt immer eine Fläche oder der Schleier (Regel aus bitster).
- **Ziffern bewegen sich nie.** Kein Effekt verschiebt, skaliert oder blendet
  Ziffern; Glühen ist ein Schatten hinter ruhender Schrift.
- **Beim Erfassen ruhig:** im Tippfeld und auf „Was?“ steht der Hintergrund
  still. Einstellbar je Design, Standard an.
- **„Bewegung reduzieren“ des Systems** schaltet alles ab; dazu ein Schalter in
  der App. In den Entwürfen ist das der Schalter „Bewegung“.
- **Tempo und Stärke** sind Regler je Design (0–100 %). 0 % Tempo = Stillstand.
- **Bestehende Zeiten bleiben:** 120 / 200 / 320 ms mit `easeOutCubic` für
  Übergänge, 600 ms Blinken beim Klingeln, 180 ms Aufleuchten nach einem Tipp,
  900 ms Bestätigung beim Erfassen, 10 s Rückgängig-Leiste.

## 5. Maße, die sich gegenüber heute ändern

| Token (`lib/theme/tokens.dart`) | heute | neu | Anmerkung |
|---|---|---|---|
| `colorBar` | 4 | entfällt | die Fläche trägt die Farbe |
| `progressBar` | 3 | entfällt in der Spur | Fortschritt ist die Füllung; 4 px bleibt für den Abstand-Balken auf Feldern |
| `laneMinHeight` | 84 | 101 laufend, 66 bereit | ergibt sich aus Innenabstand 12 und Zeilen 17 / 38 / 16 |
| `primaryButton` | 56 | 60 (48 bei bereiter Spur) | |
| `secondaryButton` | 40 | 48 | sichtbar 48, nicht nur als Trefferfläche |
| `digitsLarge` | 44 | 32 (je Design 28–34); Fokus 56 | siehe Schriften |
| `digitsMedium` | 24 | 22 | Zeit auf Feldern und bereiten Spuren |
| Radius Spur | 12 (Basis) | 20 | je Design 0–28 |
| Radius Feld | 12 | 22 | je Design 0–32 |
| Radius klein | 6 | 14 | Label-Felder, Kacheln, Eingabefelder |
| Radius Blatt | 18 | 28 | |
| Abstand zwischen Spuren | 8 | 8 | unverändert |
| Seitenrand | 16 | 12 für Spuren und Felder, 16 für Kopf und Blätter | |
| `padButtonMinHeight` | 72 | 72 | unverändert; gezeichnet 143–175 |
| `undoBarHeight` | 56 | 56 | unverändert |
| untere Leiste | Systemleiste | Pille 56 + Plus 56, Abstand unten 30 | |
| Streifen `gutter` / `gutterNarrow` | 184 / 124 | 0 | Namen stehen über der Spur |
| Streifen `subLane` | 44 | 40 | 14 Beschriftung + 26 Punkte |
| Streifen Faltenbreite | – | 24 | neu |
| Streifen `followAnchor` | 0,82 | 0,85 | |
| `tileMinHeight` u. a. für breite Layouts | – | unverändert | Tablet und Desktop sind nicht gezeichnet |

Unverändert: Abstandsskala 2 / 4 / 8 / 12 / 16 / 24 / 32 / 48, Dichte-Faktoren,
`minTapTarget` 48, Textgrößen 17 / 16 / 15 / 13 für Fließtext. Neu genutzt
werden 14 (Name der Spur, Knöpfe in Reihen) und 11–12 (Beschriftung im
Streifen).
