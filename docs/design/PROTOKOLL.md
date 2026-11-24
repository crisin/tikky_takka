# Protokoll – neues Bedienkonzept

Stand: 24.11.2026. P1–P6 sind entschieden (Abschnitt 12).
Ersetzt die Abschnitte 1.2 (Protokoll-Spur), 2.1–2.7 und 3.1 (Karten) in
`FLOWS.md`. Das Aussehen (Design „Pult“, Tokens) bleibt; neu ist nur, was wo
liegt und wie man hinkommt.

Vorgabe: Bestehende Daten und gespeicherte Namen müssen nicht erhalten
bleiben. Für manche ist das Protokoll der einzige Grund, die App zu öffnen.

## 1. Wofür das Protokoll da ist

Fünf Aufgaben, nach Häufigkeit:

| Nr. | Aufgabe | Lage |
|---|---|---|
| A1 | **Eintragen:** „Krille, Bier, jetzt“ | dunkel, laut, eine Hand, nicht nüchtern, Handy geht reihum |
| A2 | **Nachsehen:** wie lange ist es her, läuft noch ein Abstand | ein Blick, ohne Tippen |
| A3 | **Richten:** falsche Person, vergessen, falsche Zeit | direkt danach oder später |
| A4 | **Zurückblicken:** der Abend, die Woche, der Monat | in Ruhe |
| A5 | **Einrichten:** wer ist dabei, was ist dran | vorher, oder wenn jemand dazukommt |

Heute liegen A1 und A2 in verschiedenen Reitern (Tippfeld und Zeitleiste →
Jetzt), und die Personen gibt es dreimal: als Spur, als Felder im Tippfeld,
als Karten in der Zeitleiste.

## 2. Grundsätze

1. **Ein Brett für Eintragen und Nachsehen.** Wo man die Person antippt,
   steht auch, wie lange es her ist.
2. **Immer derselbe Weg: Wer → Was.** Zwei Tipps, bei jeder Gruppengröße
   gleich, mit großen Feldern.
3. **Jedes Feld hat seinen festen Platz.** Die Sachen stehen für alle
   Personen in derselben Reihenfolge („Bier ist immer oben links“). Nichts
   sortiert sich während des Abends um.
4. **Erst eintragen, dann verfeinern.** Zeit, Menge, Notiz, andere Person
   kommen nachträglich über „Ändern“. Es gibt kein Formular für neue Einträge.
5. **Rückgängig statt Nachfrage**, und der letzte Eintrag bleibt immer
   erreichbar – auch nach den 10 Sekunden.
6. **Kein Text im Erfassungsweg.** Tippen auf der Tastatur gibt es nur beim
   Einrichten und unter „Anderes“.
7. **Die App zählt und zeigt, sie bewertet und sperrt nicht.** Ein Abstand
   ist immer der selbst eingestellte.

## 3. Das Modell: flach

```
Person ─┐
        ├─ Eintrag (Zeit, dazu wahlweise Menge und Notiz)
Sache  ─┘

Set = Spuren (Stoppuhr, Timer …) + Szene (welche Personen und Sachen
      auf dem Brett liegen)
```

- **Protokoll ist keine Spurart mehr.** Die sechste Art entfällt; es bleiben
  fünf Arten von Spuren.
- **Es gibt keine Sitzung.** „Heute Abend“ ist der Tag nach „Tag beginnt um“
  (06:00). Niemand muss etwas beenden.
- **Ein Eintrag gehört zu Person und Sache, nicht zu einem Set.** Ein Abstand
  läuft deshalb weiter, wenn man das Set wechselt.
- **Jeder Eintrag hat eine Person.** „Ohne Person“ entfällt. Wer allein
  protokolliert, hat genau eine Person; dann entfällt die Frage „Wer“ überall.
- **Alte Protokoll-Einträge werden verworfen**, nicht umgeschrieben.
- Gespeichert wird weiter nur das Ereignis mit Zeitstempel; alles Angezeigte
  wird daraus berechnet.

## 4. Das Brett (im Reiter „Tippfeld“)

Eine Kachel je Person, zwei Spalten, die Kacheln teilen sich die Höhe. Die
Kachel zeigt den Stand und ist zugleich der Knopf für „Was?“.

```
┌─────────────────────────────────────────┐
│ Krille · Bier         23:41 · jetzt     │  feste Leiste, 56
│                   [Ändern] [Rückgängig] │
├─────────────────────────────────────────┤
│ [Alles] [Bier] [Wasser] [Kippe] [Mate]  │  Filter, 48
│ ┌──────────────────┐┌─────────────────┐ │
│ │ (K) Krille       ││ (J) Jacke       │ │
│ │ 26:14            ││ 34 min          │ │  Kacheln, mind. 72 hoch
│ │ seit Bier        ││ Kippe: Abstand  │ │
│ └──────────────────┘└─────────────────┘ │
│                                         │
│ ── übrige Spuren (Zähler, Timer) ────── │
└─────────────────────────────────────────┘
 [ Spuren | Tippfeld | Zeitleiste ]   ( + )
```

- **Kachel:** Kürzel, Name, groß die Zeit seit dem maßgeblichen Eintrag
  („26:14 seit Bier“). Maßgeblich ist die Sache mit laufendem eigenem
  Abstand, sonst der letzte Eintrag. Läuft ein Abstand, steht dort „noch
  34 min“ in Warnfarbe. Das ist die Karte aus „Jetzt“ – sie zieht hierher um.
- **Tipp auf die Kachel** öffnet „Was?“ dieser Person (Abschnitt 5).
- **Reihenfolge:** die Personen der Szene in der Reihenfolge der Szene. Die
  Kacheln wechseln ihren Platz nicht.
- **Eine Person:** kein Brett; das Tippfeld zeigt gleich ihre Sachen.
- Sets mit Spuren und Szene zeigen unter den Personen die übrigen Felder
  (Zähler, Timer) wie bisher. Sets ohne Szene sehen aus wie heute.

### Filter

Eine Reihe Knöpfe über den Kacheln: **Alles** und die Sachen der Szene. Die
Reihe steht immer da und scrollt bei vielen Sachen seitlich.

- **Mit „Bier“:** jede Kachel zeigt den Stand nur für Bier – Zeit seit dem
  letzten Bier, Anzahl heute, laufender Abstand für Bier. Wer heute noch
  keins hatte, zeigt „–“.
- Der Filter ändert, was die Kacheln **zeigen**, nicht ihren Platz.
- Derselbe Filter gilt in der Zeitleiste weiter (dort gibt es die Reihe im
  Monat schon als „Was zählen“). Wechselt man den Reiter, bleibt er stehen.
- Ein Tipp auf die Kachel öffnet auch bei gesetztem Filter „Was?“. Der
  Filter trägt nie etwas ein.

## 5. Was?

Die Seite einer Person, wie `FLOWS.md` 2.2: bis zu fünf Sachen plus
„Anderes“, 2 × 3, je etwa 175 hoch. Ein Tipp trägt ein.

- **Felder:** die Sachen der Szene in der Reihenfolge der Szene – für alle
  Personen dieselben, am selben Platz. Die eigene Top-5 je Person entfällt.
- **Feld:** Name groß, klein die Anzahl heute (nur mit dem Schalter aus O5).
  Läuft für diese Person ein Abstand, steht „Abstand: noch 34 min“ in
  Warnfarbe mit Balken. Das Feld bleibt antippbar.
- **Kopf:** Zurück, Kürzel, Name. Darunter eine Zeile „zuletzt Bier · vor
  26 min ›“; ein Tipp darauf öffnet „Ändern“ für diesen Eintrag. So bleibt
  der letzte Eintrag erreichbar, wenn die Leiste weg ist.
- **Nach dem Tipp:** das Feld zeigt etwa 900 ms „✓ eingetragen“, die Leiste
  oben nennt Person und Sache, dann geht es zurück zum Brett. In dieser Zeit
  löst dasselbe Feld nicht noch einmal aus (Schutz vor Doppeltipp).
- **Langer Druck auf ein Feld:** trägt ein und öffnet sofort „Ändern“ (für
  „vor 10 Minuten“ oder eine Menge). Zusatzweg, niemand muss ihn kennen.

## 6. Ändern (das eine Eintragsblatt)

Unverändert nach `FLOWS.md` 2.4 / 2.5 / 3.5, aber der einzige Weg zu allem,
was über „jetzt, diese Person, diese Sache“ hinausgeht:

- **Wann?** Jetzt · −5 · −10 · −30 min · Uhr (frisch) bzw. −5 / −1 / +1 / +5
  (später).
- **Wie viel?** die eigenen früheren Mengen dieser Sache, dazu Freitext.
- **Wer, Was, Notiz** als zugeklappte Zeilen.
- **Löschen** (mit Rückgängig), **Nochmal jetzt**, **Fertig**.

Erreichbar aus: Leiste nach dem Tipp, Zeile „zuletzt …“ auf „Was?“, langer
Druck auf ein Feld, jedem Eintrag in der Zeitleiste.

## 7. Anderes

Eine Seite je Person: alle übrigen Sachen als Felder (88 hoch), zuerst die,
die diese Person am häufigsten hatte. Ein Tipp trägt ein. Darunter „Steht
nicht da? Neu anlegen“ mit Namensfeld.

Eine Sache, die über „Anderes“ eingetragen wird, kommt **nicht** von selbst
auf „Was?“ oder in den Filter. Dort ändert nur die Szene etwas.

## 8. Szene (einrichten)

Ein Blatt, erreichbar über den Set-Titel („Sets und Szene“) – und nur dort.

- **Wer ist dabei?** und **Was ist dran?** als Knöpfe zum An- und Abwählen.
  Die Reihenfolge des Antippens ist die Reihenfolge auf dem Brett und auf
  „Was?“.
- **„+ Neu“** am Ende jeder Reihe: Name tippen, fertig. Die Farbe kommt aus
  der Palette.
- **Langer Druck auf einen Knopf:** Name, Farbe, bei Sachen der eigene
  Abstand; „Entfernen“ mit Rückgängig.
- Die eigene Verwaltungsseite in den Einstellungen entfällt. Entfernte
  Personen und Sachen bleiben in alten Einträgen lesbar.

## 9. Der erste Start

Der leere Start zeigt zwei Wege statt sechs Arten:

1. **Protokoll:** „Wer ist dabei?“ → Namen tippen → „Was ist dran?“ → Brett.
   Ziel: erster Eintrag nach unter einer Minute.
2. **Spur anlegen:** die fünf Arten wie heute.

Wer nur das Protokoll nutzt, sieht danach beim Öffnen immer das Brett: die
App merkt sich je Set den zuletzt offenen Reiter.

## 10. Zeitleiste

Bleibt, mit drei Änderungen:

- **„Jetzt“ verliert die Karten** (sie sind das Brett) und zeigt nur noch den
  Streifen. Ein Tipp auf den Namen im Streifen springt zum Brett.
- **Abend, Woche und Monat** rechnen über den Tag statt über Sitzungen.
  „Abend → Kompakt“ ist die Liste aller Einträge; die Eintragsliste der
  Sitzung entfällt.
- **Der Filter des Bretts gilt in allen vier Stufen.**

## 11. Was wegfällt

| Heute | Danach |
|---|---|
| Spurart „Protokoll“, Protokoll-Spur im Reiter „Spuren“ | – |
| Sitzung, „Sitzung beenden“, Eintragsliste der Sitzung | Tag; Abend → Kompakt |
| Formular „Neuer Eintrag“ | Tipp, dann „Ändern“ |
| „Ohne Person“ | genau eine Person |
| eigene Top-5 je Person, Platzhalten der Knöpfe | Reihenfolge der Szene |
| Szene-Blatt und Szene in „Sets und Szene“ | nur „Sets und Szene“ |
| Verwaltung „Personen und Sachen“ in den Einstellungen | in der Szene |
| Karten in „Jetzt“ | Kacheln auf dem Brett |

Bildschirme fürs Protokoll danach: Brett, Was?, Anderes, Ändern, Szene.

## 12. Entscheidungen

| Nr. | Frage | Entschieden (24.11.2026) |
|---|---|---|
| P1 | Felder direkt auf dem Brett oder immer erst Person, dann Sache? | **immer zwei Tipps** |
| P2 | Einträge gehören zur Person oder zum Set? | **zur Person** |
| P3 | Brett im Reiter „Tippfeld“ oder eigener Reiter? | **im Tippfeld** |
| P4 | Alte Protokoll-Einträge verwerfen oder umschreiben? | **verwerfen** |
| P5 | Sachen für alle gleich oder je Person eigene? | **für alle gleich, dazu ein Filter für die Ansicht** |
| P6 | Tipp auf eine Kachel bei gesetztem Filter: „Was?“ öffnen oder die gefilterte Sache direkt eintragen? | **weiter „Was?“** |

O5 (Anzahl auf den Feldern) und O6 (Ampel) aus `README.md` bleiben, wie sie
sind.

## 13. Nicht geprüft

Das Konzept ist auf dem Papier entstanden. Offen ist vor allem: wie viele
Kacheln bei 375 × 812 mit großer Zeit lesbar bleiben, ob die Filter-Reihe
über den Kacheln im Dunkeln versehentlich getroffen wird, und ob „–“ bei
gesetztem Filter verstanden wird. Das zeigt erst ein Entwurf in `entwuerfe/`
und ein Abend am Gerät.

## 14. Woher die Grundsätze kommen

- Dosis-Logger (DoseLog, Secure Dose Log): „wie lange her“ als größte Zahl
  der Karte, zwei Tipps pro Eintrag, ein Eintrag wird nie gesperrt, keine
  Bewertung, ein Abend statt Sitzungen.
- Baby-Tracker: höchstens zwei Tipps, große Felder für eine Hand, Zeit
  nachträglich mit −5 / −1 / +1 / +5, jeder Eintrag bleibt änderbar.
- Ein-Tipp-Logger: erst speichern, dann anreichern; Rückgängig und „letzten
  Eintrag ändern“ immer erreichbar; höchstens drei Entscheidungen je Eintrag.
- Nielsen Norman Group: Nachfragen nur bei nicht umkehrbaren Schritten,
  sonst Rückgängig.
- „The user is drunk“: wenige Wege, große Ziele, klare Rückmeldung nach jeder
  Aktion.
- Geteilte Geräte: die aktive Person ist immer sichtbar, nie stiller Wechsel.

Das sind überwiegend Herstellerseiten und Blogs, keine Studien. Eine
Untersuchung dazu, wie gut Abstands-Anzeigen im Rausch funktionieren, habe
ich nicht gefunden.
