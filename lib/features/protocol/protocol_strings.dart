/// German UI texts of the protocol feature that are not part of the shared
/// `Strings` class. Same rules: no user-facing literal inside a widget.
///
/// The wording is deliberately neutral: the app records what the user
/// enters and never rates, recommends or warns about amounts or intervals.
abstract final class ProtocolStrings {
  // ------------------------------------------------------------- general
  /// The short note shown wherever persons, substances or entries are
  /// managed.
  static const neutralNote =
      'Die App zeichnet nur auf, was du einträgst. Sie gibt keine Mengen, '
      'Abstände oder Empfehlungen vor.';

  static String entryCount(int n) => n == 1 ? '1 Eintrag' : '$n Einträge';

  // ---------------------------------------------------------------- lane
  /// "Alex · gerade eben"
  static String personJustNow(String person) => '$person · gerade eben';

  /// "Wasser: frühestens wieder in 2 h 18 min"
  static String lockoutFor(String substance, String duration) =>
      '$substance: frühestens wieder in $duration';

  // ----------------------------------------------------- one-tap capture
  static const whoAreYou = 'Wer bist du?';
  static const others = 'Andere';
  static const showOthers = 'Andere Personen anzeigen';

  /// Semantics of a person card.
  static String choosePerson(String person) => '$person auswählen';
  static const backToPersons = 'Zurück zur Personenwahl';

  /// "Jacke · GBL eingetragen"
  static String captured(String person, String substance) =>
      '$person · $substance eingetragen';
  static const details = 'Details';

  /// The person's count of a substance in the current session: "3×".
  static String timesCount(int n) => '$n×';

  /// Semantics of a one-tap substance button. [remaining] is only passed
  /// while a lockout the user set is still running.
  static String captureLabel(String substance, int count, String? remaining) =>
      [
        '$substance eintragen',
        'bisher $count in dieser Sitzung',
        if (remaining != null) 'frühestens wieder in $remaining',
      ].join(', ');

  // --------------------------------------------------------------- scene
  static const scene = 'Szene';
  static const sceneEdit = 'Szene bearbeiten';
  static const sceneWho = 'Wer ist dabei?';
  static const sceneWhat = 'Was ist heute dran?';
  static const sceneClear = 'Szene leeren';
  static const sceneHint =
      'Die Szene gilt für dieses Set. Was du hier antippst, steht bei der '
      'Erfassung vorn; alles andere bleibt über + erreichbar.';

  /// Title of the scene editor: "Szene · Festival".
  static String sceneOf(String setName) => '$scene · $setName';

  /// A chosen substance with its place in the scene: "1 · GBL".
  static String sceneOrdered(int position, String name) => '$position · $name';
  static const showEntries = 'Einträge anzeigen';
  static const finishSession = 'Sitzung beenden';
  static const sessionFinished = 'Protokoll-Sitzung beendet';
  static const tapToAdd = 'Tippe auf +, um den ersten Eintrag festzuhalten.';

  // --------------------------------------------------------- entry sheet
  static const newPersonHint = 'Name der neuen Person';
  static const newSubstanceHint = 'Name der neuen Substanz';
  static const confirmAdd = 'Übernehmen';
  static const cancelAdd = 'Verwerfen';
  static const addPersonShort = 'Person';
  static const addSubstanceShort = 'Substanz';
  static const recentAmounts = 'Zuletzt eingetragen';
  static const optional = 'optional';
  static const timeNow = 'Jetzt';
  static const timeEarlier = '5 min früher';
  static const timePick = 'Uhrzeit wählen';
  static const entryUpdated = 'Eintrag geändert';
  static const manage = 'Listen verwalten';

  /// Step of the "5 min früher" button, in minutes.
  static const timeStepMinutes = 5;

  /// "21:05 · vor 10 min"
  static String timeWithAgo(String time, String ago) => '$time · $ago';

  // ------------------------------------------------------ session screen
  static const sessionTitle = 'Einträge';
  static const noOpenSessionTitle = 'Keine offene Sitzung';
  static const noOpenSessionBody =
      'Mit dem nächsten Eintrag beginnt eine neue Sitzung.';
  static const sessionEmptyBody =
      'In dieser Sitzung gibt es noch keinen Eintrag.';
  static String sessionSince(String dateTime) => 'Sitzung seit $dateTime';
  static const deleteEntry = 'Eintrag löschen';

  /// Between two entries of the session list (newest first).
  static String gapEarlier(String duration) => '$duration früher';
  static const editEntry = 'Eintrag bearbeiten';

  // ------------------------------------------------- persons / substances
  static const peopleTitle = 'Personen und Substanzen';
  static const personsEmptyTitle = 'Noch keine Personen';
  static const personsEmptyBody =
      'Lege an, für wen du Einträge festhalten möchtest.';
  static const substancesEmptyTitle = 'Noch keine Substanzen';
  static const substancesEmptyBody =
      'Lege an, was du festhalten möchtest. Die Liste ist anfangs leer.';
  static const newPerson = 'Neue Person';
  static const newSubstance = 'Neue Substanz';
  static const editPerson = 'Person bearbeiten';
  static const editSubstance = 'Substanz bearbeiten';
  static const remove = 'Aus der Liste entfernen';
  static const removedSection = 'Entfernt';
  static const removedHint =
      'Entfernte Namen bleiben in alten Einträgen lesbar.';
  static const deleteForever = 'Endgültig löschen';
  static const personRemoved = 'Person entfernt';
  static const substanceRemoved = 'Substanz entfernt';
  static const personDeleted = 'Person gelöscht';
  static const substanceDeleted = 'Substanz gelöscht';
  static const personSaved = 'Person gespeichert';
  static const substanceSaved = 'Substanz gespeichert';
  static const lockoutSet = 'Mindestabstand festlegen';
  static const lockoutClear = 'Mindestabstand entfernen';
  static const noteHint = 'Eigene Notiz';
  static String colorNumber(int n) => 'Farbe $n';
}
