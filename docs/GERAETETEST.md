# Gerätetest

Was nur auf einem echten Gerät mit der nativen App (TestFlight / APK)
geprüft werden kann. Das Web deckt Layout und Bedienung ab, aber keine
Alarme, keine App-Sperre, kein Teilen-Menü.

Vor jedem Durchgang: **Einstellungen → Diagnose** öffnen und prüfen, ob
Build-Nummer und Plattform stimmen. Fällt etwas auf: dort „Bericht
kopieren“ und in den Chat / ins Backlog einfügen. Auf iOS zusätzlich per
Screenshot → „Beta-Feedback senden“ (landet in App Store Connect).

## 1. Erster Start

- [ ] Startbildschirm passt zum Hell-/Dunkelmodus (kein weißer Blitz im
      Dunkelmodus).
- [ ] App-Icon auf dem Homescreen, Name „Tikky Takka“ nicht abgeschnitten.
- [ ] Keine Abfrage von Berechtigungen beim Start (erst beim ersten Timer).

## 2. Alarme (wichtigster Teil)

Je Fall: Timer starten, dann wie angegeben verlassen.

- [ ] Diagnose → „Test-Alarm in 10 Sekunden“, App sofort in den
      Hintergrund: Alarm kommt mit Ton.
- [ ] Dasselbe mit gesperrtem Bildschirm.
- [ ] Dasselbe nach Wegwischen der App aus der App-Übersicht.
- [ ] Beim ersten Timer fragt die App nach Benachrichtigungen; nach
      „Erlauben“ steht in Diagnose „Erlaubt: Ja“.
- [ ] Countdown (1 min) läuft bei geschlossener App ab → Benachrichtigung;
      „Stopp“ in der Benachrichtigung stoppt die Spur.
- [ ] Intervall (z. B. 20 s / 10 s, 3 Runden) im Hintergrund: jede Phase
      meldet sich.
- [ ] Erinnerung: „Erledigt“ in der Benachrichtigung quittiert.
- [ ] Tippen auf eine Benachrichtigung öffnet die App beim richtigen Set.
- [ ] Viele Spuren gleichzeitig (iOS hält höchstens 64 Benachrichtigungen):
      sechs Intervall-Spuren starten, App schließen – die ersten Alarme
      kommen, die letzte geplante sagt „Tikky Takka öffnen …“.
- [ ] Ton / Vibration je Spur ausgeschaltet → Benachrichtigung ohne Ton.
- [ ] Fokus / Nicht stören an: Verhalten notieren (Timer gelten nicht als
      „zeitkritisch“).
- [ ] Android: nach Neustart des Handys kommen geplante Alarme trotzdem.

## 3. App-Sperre

- [ ] Einstellungen → App-Sperre einschalten: Face ID / Fingerabdruck
      wird abgefragt (iOS: Face-ID-Hinweistext erscheint beim ersten Mal).
- [ ] App kurz verlassen und zurück: Sperre erscheint, Inhalt ist in der
      App-Übersicht nicht zu sehen.
- [ ] Mit eingeschalteter Sperre: Benachrichtigungen zeigen auf dem
      Sperrbildschirm keine Spurnamen.
- [ ] Face ID abbrechen → Geräte-Code als Ausweg.

## 4. Daten

- [ ] Verlauf → Export CSV: Teilen-Menü erscheint, „In Dateien sichern“
      klappt, Datei öffnet in Numbers / Sheets mit Umlauten korrekt.
- [ ] JSON-Sicherung exportieren, App löschen, neu installieren, Import
      über die Dateien-App: alles wieder da.
- [ ] Daten überleben ein Update über TestFlight (neuen Build
      installieren).

## 5. iOS-Eigenheiten

- [ ] Große Titel bei Verlauf / Einstellungen klappen beim Scrollen ein;
      Wischen vom linken Rand geht zurück.
- [ ] Notch / Dynamic Island und Home-Indikator verdecken nichts
      (Querformat auch).
- [ ] Einstellungen → Bedienungshilfen → Größerer Text: größte Stufe,
      nichts läuft über.
- [ ] Bildschirm bleibt an, wenn die Einstellung dafür aktiv ist.
- [ ] Zeitzone wechseln (Einstellungen → Allgemein → Datum & Uhrzeit):
      laufende Timer stimmen, Hinweis erscheint.
- [ ] Tastatur verdeckt keine Eingabefelder (Spur-Editor, Notiz im
      Protokoll).
- [ ] Haptik bei Start / Stopp spürbar.

## 6. Android-Eigenheiten

- [ ] Android 13+: Abfrage für Benachrichtigungen beim ersten Timer.
- [ ] Systemfarben (Material You) unter Einstellungen → Darstellung.
- [ ] Themed Icons (Android 13+, Homescreen-Einstellung): Icon wird
      einfarbig dargestellt.
- [ ] Zurück-Geste schließt Sheets, bevor sie die App verlässt.
- [ ] Mit App-Sperre: Screenshots sind blockiert.
