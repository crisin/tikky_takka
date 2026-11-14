# Tikky Takka

Mehrere Timer gleichzeitig, als konfigurierbare Spuren nebeneinander:
Stoppuhr, Timer (Countdown), Intervall, Zähler, Erinnerung und Protokoll.
Alles bleibt lokal auf dem Gerät – kein Konto, kein Netzwerk.

- **Spuren und Sets:** Spuren lassen sich zu Sets gruppieren, gemeinsam
  starten/pausieren, umsortieren und pro Set anders darstellen.
- **Ereignisprotokoll:** Gespeichert werden nur Ereignisse mit Zeitstempel;
  alle angezeigten Werte werden daraus berechnet. Die App zählt nichts im
  Hintergrund und verliert nichts, wenn sie geschlossen wird.
- **Verlauf und Export:** Sitzungen nach Tagen mit Summen, Filter,
  Tages-/Wochensummen; Export als CSV (Sitzungen, Ereignisse) und als
  JSON-Sicherung mit Import.
- **Alarme:** Benachrichtigungen des Betriebssystems für Timer, Intervalle
  und Erinnerungen, auch wenn die App geschlossen ist.
- **Designs:** Hell, Dunkel, Schwarz, System, Systemfarben (Android 12+) und
  ein Design-Editor mit Vorschau.
- **App-Sperre:** optional per Fingerabdruck, Gesicht oder Geräte-PIN.

## Voraussetzungen (Windows)

1. **Flutter** über [scoop](https://scoop.sh): `scoop install flutter`
   (Projekt läuft mit Flutter 3.47).
2. **Visual Studio Build Tools 2022** mit dem Workload
   „Desktopentwicklung mit C++“ **und** der Einzelkomponente
   **„C++ ATL für neueste v143-Buildtools (x86 und x64)“**. Ohne ATL bricht
   der Build mit `atlbase.h: No such file or directory` ab (das
   Benachrichtigungs-Plugin braucht sie).
3. **Entwicklermodus** einschalten (Einstellungen → System → Für Entwickler),
   damit Flutter symbolische Links für die Plugins anlegen kann.

`flutter doctor` zeigt, ob noch etwas fehlt.

## Starten

```
flutter pub get
flutter run -d windows
```

Tests und statische Prüfung:

```
flutter analyze
flutter test
```

Nach Änderungen am Datenbankschema (`lib/core/db/tables.dart`):

```
dart run build_runner build --delete-conflicting-outputs
```

## Web (auch zum Testen auf iPhone / Android)

```
flutter build web --release
python -m http.server 5180 --bind 0.0.0.0 --directory build/web
```

Dann im Browser `http://localhost:5180` – oder vom Handy im selben WLAN
`http://<IP des PCs>:5180` (IP per `ipconfig`). Beim ersten Start fragt die
Windows-Firewall nach, ob Python im privaten Netz lauschen darf: zulassen.

Die Datenbank läuft im Browser als SQLite-WebAssembly
(`web/sqlite3.wasm`, `web/drift_worker.js`, beide eingecheckt). Nach einem
Update von `drift` bzw. `sqlite3` beide erneuern:

```
dart compile js -O4 -o web/drift_worker.js tools/drift_worker.dart
gh release download sqlite3-<version> -R simolus3/sqlite3.dart -p sqlite3.wasm -D web --clobber
```

Im Web **nicht** verfügbar: Benachrichtigungen/Alarme bei geschlossener
App, App-Sperre, Systemfarben. Daten bleiben pro Browser gespeichert
(privater Modus oder „Websitedaten löschen“ verwirft sie).

## Android (später)

1. [Android Studio](https://developer.android.com/studio) installieren; beim
   ersten Start Android SDK, Plattform-Tools und ein Emulator-Abbild
   einrichten lassen.
2. `flutter doctor --android-licenses` ausführen und die Lizenzen annehmen.
3. Emulator starten oder ein Gerät mit USB-Debugging anschließen, dann
   `flutter run` (oder `flutter run -d <Geräte-ID>`, siehe `flutter devices`).

Die Android-Konfiguration (Berechtigungen, Benachrichtigungs-Receiver,
Desugaring, `FlutterFragmentActivity` für die App-Sperre) ist vorbereitet,
wurde aber noch auf keinem Gerät gebaut. Dasselbe gilt für iOS und macOS
(dafür ist ein Mac mit Xcode nötig).

## Ordner

```
lib/
  main.dart         Start, echte Dienste (productionOverrides)
  app.dart          MaterialApp, Sperre, Navigation, Benachrichtigungs-Aktionen
  app_wiring.dart   Verbindungen zwischen den Features (Einstellungs-Hooks, Export)
  adaptive/         Material-/Cupertino-Widgets je nach Plattform
  core/
    domain/         Spur, Set, Sitzung, Ereignis, Konfiguration
    engine/         reine Funktionen: Ereignisse + Konfiguration + Jetzt → Anzeige
    db/             Drift-Datenbank (SQLite)
    repo/           Repositories, Befehle (Start, Pause, Runde …), Provider
    services/       Alarme, Export, App-Sperre, Haptik, Bildschirm anlassen
  features/
    tracks/         Spuren-Bildschirm, Spur-Editor, Sets, Tastenkürzel
    history/        Verlauf, Filter, Sitzungsdetails, Export-Dialog
    protocol/       Protokoll-Spur, Personen und Substanzen
    alarms/         Klingel-Zustand in der App, Berechtigungs-Hinweis
    settings/       Einstellungen, Design-Editor, Sperrbildschirm
  theme/            Design-Tokens, Vorlagen, Anzeige-Einstellungen
  l10n/             deutsche Texte und Formatierung
test/               Unit- und Widget-Tests (gleiche Struktur wie lib/)
android/ ios/ macos/ windows/   Plattform-Projekte
```

Oberfläche auf Deutsch, Code und Kommentare auf Englisch.
