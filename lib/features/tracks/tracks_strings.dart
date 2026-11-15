/// German UI text of the tracks feature that is not (yet) part of the
/// central `Strings` class. Kept in the same shape so it can be merged into
/// lib/l10n/strings.dart later.
abstract final class TracksStrings {
  // ------------------------------------------------------------ app bar
  static const toggleAllHint = 'Alle Spuren dieses Sets starten oder pausieren';
  static String allStarted(int n) =>
      n == 1 ? '1 Spur gestartet' : '$n Spuren gestartet';
  static String allPaused(int n) =>
      n == 1 ? '1 Spur pausiert' : '$n Spuren pausiert';
  static const nothingToStart = 'Hier gibt es nichts zu starten.';

  // ----------------------------------------------------------------- sets
  static const setsTitle = 'Sets';
  static const setRenamed = 'Set umbenannt';
  static const newSetHint = 'z. B. Küche, Training, Festival';
  static const setOptions = 'Optionen für dieses Set';
  static const emptySetTitle = 'Dieses Set ist noch leer';
  static const createSet = 'Set anlegen';
  static String setTrackCount(int n) => n == 1 ? '1 Spur' : '$n Spuren';

  /// "5 Spuren · 4 aktiv" under the set's name.
  static String setSummary(int tracks, int active) => active == 0
      ? setTrackCount(tracks)
      : '${setTrackCount(tracks)}$separator$active aktiv';
  static const moreMenu = 'Mehr: Einstellungen, Verlauf';
  static String deleteSetQuestion(String name) => '„$name“ löschen?';
  static const deleteSetBody =
      'Alle Spuren dieses Sets und ihr Verlauf werden gelöscht.';
  static String setSelected(String name) => 'Aktives Set: $name';

  // ---------------------------------------------------------------- lanes
  /// "Stoppuhr · exklusiv"
  static const exclusiveTag = 'exklusiv';
  static const autoRestartTag = 'wiederholt';

  /// "bis 21:05"
  static String until(String time) => 'bis $time';

  /// "alle 30 min"
  static String every(String duration) => 'alle $duration';

  /// "8 × 00:30 / 00:10"
  static String intervalProgramme(int rounds, String work, String rest) =>
      '$rounds × $work / $rest';
  static String intervalProgrammeNoRest(int rounds, String work) =>
      '$rounds × $work';

  /// "3× erledigt"
  static String ackCount(int n) => '$n× erledigt';

  /// "Nächste 21:05"
  static String nextDueAt(String time) => 'Nächste $time';

  /// "Fällig seit 21:05"
  static String dueSince(String time) => 'Fällig seit $time';
  static const tapToCount = 'Tippen zum Zählen';
  static const overtimePrefix = '+';
  static const separator = ' · ';

  /// Semantics label of a label button of a counter: "Zählen: Hund".
  static String tickLabel(String label) => 'Zählen: $label';

  /// Text of a label button: "Hund".
  static String labelCount(String label, int count) => '$label  $count';
  static const actionAckEarly = 'Jetzt schon erledigt';

  /// The secondary buttons "+1′", "+10′" and "nächste Runde": the text on
  /// the button and what a screen reader says.
  static const plusMinute = '+1′';
  static const actionPlusMinute = 'eine Minute dazu';
  static const snooze = '+10′';
  static const actionSnooze = 'in 10 Minuten wieder';
  static const actionNextRound = 'nächste Runde';
  static const actionStopSession = 'Sitzung beenden';
  static const actionStopHint = 'Stoppen und sichern';

  /// The undo bar after a lane was stopped.
  static String trackStopped(String name) => '$name gestoppt';
  static String ticksKept(int n) =>
      n == 1 ? '1 Tipp gesichert' : '$n Tipps gesichert';
  static String timeKept(String time) => '$time gesichert';
  static const actionEditTrack = 'Spur bearbeiten';
  static const sessionRestored = 'Sitzung läuft wieder';
  static const lapRecorded = 'Runde gespeichert';

  /// Semantics summary of a lane: "Stoppuhr, Stoppuhr, Läuft, 02:03".
  static String laneSemantics(
    String name,
    String mode,
    String status,
    String value,
  ) => '$name, $mode, $status, $value';

  // --------------------------------------------------------------- editor
  static const sectionGeneral = 'Allgemein';
  static const sectionMode = 'Einstellungen';
  static const sectionAlarm = 'Alarm';
  static const sectionManage = 'Verwalten';
  static const createTrack = 'Anlegen';
  static const trackNameHint = 'z. B. Nudeln, Arbeit, Vögel';
  static const paletteColor = 'Farbe aus der Palette';
  static String paletteColorN(int n) => 'Palettenfarbe $n';
  static const customColorHint = 'Eigene Farbe wählen';
  static const hue = 'Farbton';
  static const saturation = 'Sättigung';
  static const brightness = 'Helligkeit';
  static const hexInvalid = 'Bitte als RRGGBB eingeben.';
  static const roundsFewer = 'Weniger Runden';
  static const roundsMore = 'Mehr Runden';
  static const noLabels = 'Ohne Labels zählt ein einzelner Knopf.';
  static String removeLabel(String label) => '„$label“ entfernen';
  static const labelName = 'Name des Labels';
  static const modeChangeStopsSession =
      'Die laufende Sitzung wird beendet, wenn du die Art änderst.';
  static const duplicateTrack = 'Spur duplizieren';
  static const trackDuplicated = 'Spur dupliziert';
  static const trackMoved = 'Spur verschoben';
  static String trackMovedTo(String set) => 'Nach „$set“ verschoben';
  static const trackCreated = 'Spur angelegt';
  static const noOtherSet = 'Es gibt kein anderes Set.';
  static const restOff = 'Keine Pause';

  // ------------------------------------------------------------- archive
  static String archivedTracks(int n) =>
      n == 1 ? '1 archivierte Spur' : '$n archivierte Spuren';
  static const restoreTrackTitle = 'Spur wiederherstellen';
  static const trackRestored = 'Spur wiederhergestellt';

  // ------------------------------------------------------------ shortcuts
  static const shortcutsHint =
      'Tasten: 1–9 Spur umschalten, Leertaste alle, N neue Spur';

  // ---------------------------------------------------------- view switch
  static const viewSwitch = 'Ansicht der Spuren';
  static const viewLanes = 'Spuren';
  static const viewPad = 'Tippfeld';
  static const viewTimeline = 'Zeitleiste';

  // ------------------------------------------------------------- tap pad
  static const padReady = 'Bereit';
  static const padUndoIdle = 'Die letzte Erfassung steht hier, mit Rückgängig.';
  static const padWhatTitle = 'Was hattest du?';
  static const padWhatHint = 'Ein Tipp trägt ein, mit der Uhrzeit von jetzt.';
  static const padOtherTitle = 'Was anderes?';
  static const padOtherHint = 'Auch hier: ein Tipp trägt ein.';
  static const padCaptured = 'eingetragen';
  static const padEdit = 'Ändern';
  static const padEditSemantics = 'Diesen Eintrag ändern: Zeit, Menge, Notiz';
  static const padNow = 'jetzt';
  static const padBack = 'Zurück';
  static const padOtherSemantics = 'Etwas anderes eintragen';
  static const padNewLabel = 'Steht nicht da? Neu anlegen';
  static const padNewHint = 'Name';
  static const padNewSave = 'Eintragen';
  static const padNewNote =
      'Farbe und eigener Abstand lassen sich später einstellen.';

  /// "×3" on a field.
  static String padCount(int n) => '×$n';

  /// "23:41 · jetzt", "23:36 · vor 5 min" under the last action.
  static String padWhen(String time, String relative) => '$time · $relative';

  /// "Kippe · vor 8 min" on a person field.
  static String padPersonLast(String substance, String ago) =>
      '$substance · $ago';

  /// Semantics of a capture field: "Bier, 3 Mal, Abstand: noch 34 min".
  static String padSubstanceSemantics(
    String name, {
    int? count,
    String? lockout,
    bool captured = false,
  }) => [
    name,
    if (count != null) '$count Mal',
    if (captured) 'gerade eingetragen',
    ?lockout,
  ].join(', ');
  static const padUndone = 'Zurückgenommen';
  static const padTapToStart = 'Tippen zum Starten';
  static const padTapForLap = 'Tippen für eine Runde';
  static const padTapToResume = 'Pausiert · tippen zum Fortsetzen';
  static const padTapToDismiss = 'Fertig · tippen zum Ausschalten';
  static const padTapToAck = 'Fällig · tippen für erledigt';
  static const padMore = 'Anderes';
  static const padMoreEntry = 'Eintrag';
  static const padMoreSymbol = '+';
  static const padBackToPad = 'Zurück zum Tippfeld';

  /// "Jacke: was?"
  static String padPersonTitle(String person) => '$person: was?';

  /// Undo bar: "Reiher · 14:02:11".
  static String padLastAction(String what, String time) => '$what · $time';

  /// What a tap did, for the undo bar.
  static String padStarted(String track) => '$track gestartet';
  static String padResumed(String track) => '$track fortgesetzt';
  static String padDismissed(String track) => '$track ausgeschaltet';
  static String padAcked(String track) => '$track erledigt';
  static String padLap(String track, int n) => '$track · Runde $n';

  /// "Jacke · GBL"
  static String padEntry(String person, String substance) =>
      '$person · $substance';

  /// "Runde 3 · vor 12 s"
  static String padLapSince(int lap, String ago) => 'Runde $lap · $ago';

  /// A lockout the user set, on a substance button of the pad.
  static String padLockout(String duration) => 'Abstand: noch $duration';

  /// Semantics of a pad button: "Vögel: Reiher, 3".
  static String padButtonSemantics(String track, String title, String value) =>
      track == title ? '$title, $value' : '$track: $title, $value';

  /// Semantics of a person button of the pad.
  static String padPersonSemantics(String track, String person) =>
      '$track: $person auswählen';
  static String padMoreSemantics(String track) =>
      '$track: Eintrag mit allen Angaben';

  // ------------------------------------------------------------ timeline
  static const scopeOpen = 'Laufende Sitzungen';
  static const scopeToday = 'Heute';
  static const scopeLast24h = 'Letzte 24 h';
  static const scopeLabel = 'Zeitraum';
  static const modeStrip = 'Streifen';

  /// The list mode of the timeline (it was called "Zeitleiste" before the
  /// strip existed).
  static const modeTimeline = 'Liste';
  static const modeSummary = 'Zusammenfassung';
  static const modeSwitch = 'Darstellung der Zeitleiste';
  static const timelineNewestFirst = 'Neueste zuerst';
  static const timelineOldestFirst = 'Älteste zuerst';
  static const timelineShowLifecycle = 'Start und Stopp';
  static const timelineEmptyTitle = 'Hier ist noch nichts passiert';
  static const timelineEmptyOpen =
      'Sobald eine Spur läuft oder etwas gezählt wird, steht es hier.';
  static const timelineEmptyRange =
      'In diesem Zeitraum gibt es keine Einträge.';
  static const timelineAllHidden =
      'Alle Einträge sind ausgeblendet. Ändere die Filter oben.';
  static const stripNothingRunning = 'Gerade läuft kein Timer.';
  static const stripLabel = 'Laufende Timer';

  /// "12 min später" (oldest first) / "12 min früher" (newest first).
  static String gapLater(String duration) => '$duration später';
  static String gapEarlier(String duration) => '$duration früher';

  /// "Reiher · 3": a counted label with its running count.
  static String timelineTick(String label, int n) => '$label · $n';

  /// "Tipp 5": a tick without a label.
  static String timelineTickPlain(int n) => 'Tipp $n';

  /// "Runde 3 · 01:23.4"
  static String timelineLap(int n, String duration) => 'Runde $n · $duration';
  static const timelineAck = 'Erledigt';

  /// "Erledigt · 2 min nach Fälligkeit"
  static String timelineAckDelayed(String delay) =>
      'Erledigt · $delay nach Fälligkeit';
  static const timelineStarted = 'Gestartet';
  static const timelinePaused = 'Pausiert';
  static const timelineResumed = 'Fortgesetzt';
  static const timelineStopped = 'Beendet';

  /// "+1′" / "+10′": "1 min später"
  static String timelineExtended(String duration) => '$duration später';
  static const timelineSkipped = 'Nächste Runde';

  /// Semantics of a timeline row: "14:02:11, Vögel, Reiher · 3".
  static String timelineRowSemantics(String time, String track, String text) =>
      '$time, $track, $text';

  // --------------------------------------------------------------- strip
  static const stripZoomIn = 'Vergrößern';
  static const stripZoomOut = 'Verkleinern';
  static const stripFit = 'Alles zeigen';
  static const stripNow = 'Jetzt';
  static const stripControls = 'Ausschnitt der Streifenansicht';
  static const stripSessionTitle = 'Sitzung';
  static const stripRunning = 'läuft';

  /// Read by screen readers for the whole strip.
  static String stripSemantics(int lanes, int events) =>
      'Streifenansicht, Zeit von links nach rechts. '
      '${lanes == 1 ? '1 Zeile' : '$lanes Zeilen'}, '
      '${stripCluster(events)}. '
      'Die Ansicht „$modeTimeline“ zeigt dieselben Einträge als Text.';

  /// "12 Einträge": markers that are too close to draw one by one.
  static String stripCluster(int n) => n == 1 ? '1 Eintrag' : '$n Einträge';

  /// "12 Einträge, 14:02 – 14:09, tippen zum Vergrößern"
  static String stripClusterSemantics(int n, String from, String to) =>
      '${stripCluster(n)}, ${summaryFirstLast(from, to)}, '
      'tippen zum Vergrößern';

  /// Hover text of a marker: "14:02:11 · Reiher · 3".
  static String stripMarkerTip(String time, String text) => '$time · $text';

  /// Hover text of a session bar: "Stoppuhr · 14:02 – 14:40".
  static String stripBarTip(String track, String start, String end) =>
      '$track · $start – $end';

  /// Semantics of the name of a lane: "Zelt, Jacke".
  static String stripSubLane(String track, String title) => '$track, $title';

  /// Screen reader text of the timer of a substance lane.
  static String stripTimerSemantics(String elapsed) => 'seit $elapsed';

  /// Detail of an entry on a substance lane: time since the one before.
  static String stripSincePrevious(String gap) => '$gap nach dem vorherigen';

  // -------------------------------------------------------- event editor
  static const eventEditTitle = 'Ereignis bearbeiten';
  static const eventTime = 'Zeitpunkt';
  static const eventMinuteEarlier = '1 min früher';
  static const eventMinuteLater = '1 min später';
  static const eventPickTime = 'Uhrzeit wählen';
  static const eventLabel = 'Label';
  static const eventNoLabel = 'Ohne Label';
  static const eventLabelHint = 'z. B. Bergauf';
  static const eventNoteHint = 'Eigene Notiz';
  static const eventUpdated = 'Ereignis geändert';

  // ------------------------------------------------------------- summary
  static const sortByCount = 'Nach Anzahl';
  static const sortByLast = 'Nach letzter Zeit';
  static const sortLabel = 'Sortierung';
  static const summaryEmptyTitle = 'Noch nichts zusammenzufassen';
  static const summaryNoLabel = 'Ohne Label';
  static const summaryNetTime = 'Netto';

  /// "12×"
  static String summaryCount(int n) => '$n×';

  /// "14:02 – 15:40"
  static String summaryFirstLast(String first, String last) =>
      first == last ? first : '$first – $last';

  /// "alle 4 min" - the average gap between two taps of a label.
  static String summaryAvgGap(String duration) => 'im Schnitt alle $duration';

  /// "3 Runden"
  static String summaryLaps(int n) => n == 1 ? '1 Runde' : '$n Runden';

  /// "Zelt · Jacke"
  static String summaryPersonGroup(String track, String person) =>
      '$track · $person';

  /// "24 gesamt"
  static String summaryTotal(int n) => '$n gesamt';
}
