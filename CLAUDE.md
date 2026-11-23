<!-- Entwurf vom 14.11.2026, geschrieben aus README.md, docs/ideen/ und docs/design/.
     Vor dem Einchecken gegenlesen und an die eigene Arbeitsweise anpassen. -->

# Tikky Takka – Hinweise für Claude Code

Mehrere Timer gleichzeitig als konfigurierbare Spuren: Stoppuhr, Timer,
Intervall, Zähler, Erinnerung, Protokoll. Flutter, ein Code für iOS, Android,
Web und Windows. Alles bleibt lokal auf dem Gerät.

## Vor größerer Arbeit lesen

1. `README.md` – Funktionen, Starten, Tests, Ordner.
2. `docs/design/README.md` – das beschlossene Design „Pult“, offene Fragen.
3. `docs/design/UMSETZUNG.md` – Arbeitspakete P1–P9 mit betroffenen Dateien.
4. `docs/design/FLOWS.md` und `docs/design/DESIGNS.md` – Regeln je Bildschirm,
   Design-Modell, Tokens.
5. `docs/ideen/BACKLOG.md` – alle Ideen mit Status.
6. `docs/GERAETETEST.md` – was nur auf einem echten Gerät prüfbar ist.

## Regeln

1. **Gespeichert werden nur Ereignisse mit Zeitstempel.** Alle angezeigten
   Werte werden daraus berechnet (`lib/core/engine/`, reine Funktionen). Nichts
   zählt im Hintergrund.
2. **Jede Farbe, jedes Maß, jeder Radius, jede Schrift kommt aus den Tokens**
   (`context.tikky`, `lib/theme/tokens.dart`), nie aus festen Werten im Widget.
3. **Vorlage für die Oberfläche sind die Entwürfe** in `docs/design/entwuerfe/`
   (HTML und `tikky.css` für genaue Werte, PNG für den Eindruck). Was dort
   nicht gezeichnet ist, bleibt wie in der App.
4. **Offene Punkte nicht stillschweigend entscheiden.** `docs/design/README.md`
   führt sie als O1–O7; betrifft ein Paket einen davon, vorher nachfragen.
5. **Muss-Regeln der Oberfläche:** Tippziele mindestens 48, im Tippfeld
   mindestens 72 hoch; Kontrast WCAG AA in jedem Design und mit jeder
   Spurfarbe; Farbe nie als einziger Träger; keine Nachfrage im Erfassungsweg,
   Löschen mit Rückgängig; nichts verdeckt oder verschiebt Felder im Tippfeld;
   Ziffern springen nicht; die App bewertet weder Personen noch Substanzen.
6. **Sprache:** Oberfläche und Dokumente auf Deutsch, kurz. Code, Kommentare
   und Commits auf Englisch.
7. **Gespeicherte Namen nicht umbenennen** (Enum-Namen wie `TimelineMode`,
   Schlüssel in `SettingsKeys`); beim Umbau alte Werte abbilden.

## Befehle

```
flutter pub get
flutter run -d windows
flutter analyze
flutter test
dart run build_runner build --delete-conflicting-outputs   # nach Änderungen an lib/core/db/tables.dart
flutter build web --release --no-web-resources-cdn         # Web-Build nach build/web
dart run tools/web_pwa.dart                                 # danach: Service Worker füllen
```

`flutter analyze` und `flutter test` müssen sauber sein, bevor ein Commit
vorgeschlagen wird.

## Ansehen, was gebaut wurde

Web-Build bei 375 × 812 mit dem passenden Entwurf vergleichen:
`python tools/serve_web.py`, dann `http://localhost:5180`. Gebaut und auf
GitHub Pages gestellt wird bei jedem Push auf `master` (`pages.yml`). Die Entwürfe selbst: `docs/design/entwuerfe/index.html`
im Browser öffnen.
