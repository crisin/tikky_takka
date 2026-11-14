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

## Auf echten Geräten testen

Kurzfassung: GitHub Actions baut die nativen Apps (`.github/workflows/apps.yml`),
ein Mac ist nicht nötig. iOS geht über TestFlight, Android als APK. Was
auf dem Gerät zu prüfen ist: [docs/GERAETETEST.md](docs/GERAETETEST.md).
In der App hilft **Einstellungen → Diagnose** (Berechtigungen, Test-Alarm,
Fehler dieser Sitzung zum Kopieren).

Bei jedem Push auf `master` laufen:

- **CI** (`ci.yml`): `flutter analyze` und `flutter test`.
- **Apps** (`apps.yml`): iOS-Build ohne Signatur (kompiliert es unter
  Xcode?) und ein Android-Release-APK als Artefakt (14 Tage).

### iOS über TestFlight (einmalig einrichten)

1. **Apple Developer Program** beitreten (99 €/Jahr,
   developer.apple.com/programs). Freischaltung dauert ein bis zwei Tage.
2. **Bundle-ID registrieren**: developer.apple.com → Certificates, IDs &
   Profiles → Identifiers → „+“ → App IDs → App, Bundle ID (explizit)
   `dev.tikkytakka.tikkyTakka`. Keine Capabilities nötig.
   Die ID ist danach fest (eine andere ID ist eine andere App); wer eine
   andere will, ändert sie vorher in `ios/Runner.xcodeproj/project.pbxproj`
   und `BUNDLE_ID` in `apps.yml`.
3. **App anlegen**: appstoreconnect.apple.com → Apps → „+“ → Neue App
   (iOS, Name „Tikky Takka“, Sprache Deutsch, Bundle-ID von oben, SKU z. B.
   `tikkytakka`).
4. **API-Key**: App Store Connect → Benutzer und Zugriff → Integrationen →
   App Store Connect API → Team-Schlüssel „+“, Zugriff **App Manager**.
   Die `.p8`-Datei lässt sich nur einmal herunterladen. Notieren:
   Issuer ID und Key ID.
5. **Secrets im Repo setzen** (Git Bash, im Projektordner; die Werte
   landen nur bei GitHub, nicht im Repo):

   ```bash
   gh secret set APP_STORE_CONNECT_ISSUER_ID --body "<Issuer ID>"
   gh secret set APP_STORE_CONNECT_KEY_IDENTIFIER --body "<Key ID>"
   gh secret set APP_STORE_CONNECT_PRIVATE_KEY < ~/Downloads/AuthKey_<Key ID>.p8
   ```

   Dazu ein eigener Schlüssel für das Verteilungszertifikat (einmal
   erzeugen, gut aufheben, dann löschen):

   ```bash
   ssh-keygen -t rsa -b 2048 -m PEM -N "" -f ~/tikky_cert_key
   gh secret set CERTIFICATE_PRIVATE_KEY < ~/tikky_cert_key
   ```

6. **Build starten**: GitHub → Actions → „Apps“ → „Run workflow“
   (testflight angehakt), oder `gh workflow run apps.yml`. Der erste Lauf
   legt Zertifikat und Provisioning-Profil selbst an. Nach dem Upload
   braucht Apple 5–30 Minuten zur Verarbeitung.
7. **Tester**: App Store Connect → App → TestFlight → Interne Tests →
   Gruppe anlegen, sich selbst hinzufügen. Auf dem iPhone die App
   **TestFlight** installieren, Einladung annehmen, installieren. Neue
   Builds kommen dann automatisch.

Hinweise:

- Interne Tester (bis 100 Leute mit Zugang zum App-Store-Connect-Team)
  brauchen keine Prüfung durch Apple. Externe Tester per Link gehen erst
  nach einer Beta-Prüfung.
- Die Build-Nummer ist die Laufnummer des Workflows, die Version kommt aus
  `pubspec.yaml`. Version und Build stehen in der App unter Diagnose.
- TestFlight sammelt Abstürze und Feedback (Screenshot machen → „Beta-
  Feedback senden“) in App Store Connect.
- Ein TestFlight-Build läuft 90 Tage.

### Android

**Schnell, ohne SDK:** das APK aus dem letzten „Apps“-Lauf laden
(GitHub → Actions → Lauf → Artifacts), aufs Handy schicken, installieren
(„Aus unbekannten Quellen“ erlauben). Ohne eigenen Schlüssel ist es mit
einem Wegwerf-Schlüssel signiert: ein späteres APK mit anderem Schlüssel
lässt sich nur nach Deinstallation installieren (Daten weg).

**Eigener Upload-Schlüssel** (einmal, gut aufheben – ohne ihn keine
Updates):

```bash
keytool -genkey -v -keystore ~/tikky-upload.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

(`keytool` liegt bei Android Studio unter `jbr/bin`.) Für lokale Builds
`android/key.properties` anlegen (steht in `.gitignore`):

```
storeFile=C:/Users/<du>/tikky-upload.jks
storePassword=…
keyAlias=upload
keyPassword=…
```

Für die Builds bei GitHub:

```bash
base64 -w0 ~/tikky-upload.jks | gh secret set ANDROID_KEYSTORE_BASE64
gh secret set ANDROID_KEYSTORE_PASSWORD
gh secret set ANDROID_KEY_ALIAS --body upload
gh secret set ANDROID_KEY_PASSWORD
```

**Entwickeln am Gerät** (Hot Reload):

1. [Android Studio](https://developer.android.com/studio) installieren; beim
   ersten Start Android SDK, Plattform-Tools und ein Emulator-Abbild
   einrichten lassen.
2. `flutter doctor --android-licenses` ausführen und die Lizenzen annehmen.
3. Am Handy Entwickleroptionen und USB-Debugging einschalten, anschließen,
   dann `flutter run` (oder `flutter run -d <Geräte-ID>`, siehe
   `flutter devices`).

### App-Icon

Alle Icons (iOS, Android inkl. adaptiv/monochrom, macOS, Web, Windows)
werden aus einer Zeichnung erzeugt:

```bash
flutter test tools/app_icon/render_app_icons_test.dart
```

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
