import '../../../l10n/strings.dart';

/// German texts of the alarm feature that are not part of the shared
/// `Strings` class (notification bodies, channel names, permission UI).
abstract final class AlarmStrings {
  // ------------------------------------------------- notification bodies
  static String modeAndDuration(String mode, String duration) =>
      '$mode · $duration';
  static const nextCycleRunning = 'Der nächste Durchlauf läuft.';
  static String roundOf(int round, int rounds) => 'Runde $round von $rounds';
  static String restFor(String duration) => 'Pause · $duration';
  static String roundsDone(int rounds, String total) =>
      rounds == 1 ? '1 Runde · $total' : '$rounds Runden · $total';
  static String reminderEvery(String interval) => 'Erinnerung · alle $interval';
  static String overdueSince(String duration) => 'Seit $duration fällig';

  /// Body of the last notification of a plan that was cut off at the cap.
  static const openAppForMore =
      'Letzter geplanter Alarm – Tikky Takka öffnen, damit weitere '
      'Alarme kommen.';

  /// Name of the test alarm of the diagnostics page.
  static const testAlarmName = 'Test-Alarm';

  // ----------------------------------------------------- Android channels
  static const channelSoundAndVibration =
      '${Strings.notifChannelName} (Ton und Vibration)';
  static const channelSoundOnly = '${Strings.notifChannelName} (nur Ton)';
  static const channelVibrationOnly =
      '${Strings.notifChannelName} (nur Vibration)';
  static const channelSilent = '${Strings.notifChannelName} (lautlos)';

  // ------------------------------------------------------- in-app ringing
  static const ringing = 'Klingelt';
  static const reminderDue = 'Fällig';
  static String ringingSince(String duration) => 'Klingelt seit $duration';
  static String dueSince(String duration) => 'Fällig seit $duration';
  static String ringingCount(int count) =>
      count == 1 ? '1 Spur klingelt' : '$count Spuren klingeln';
  static const semanticsRinging = 'Alarm aktiv';

  // ----------------------------------------------------------- permission
  static const permissionBannerTitle = 'Alarme im Hintergrund';
  static const permissionBannerBody =
      'Ohne Benachrichtigungen klingeln Timer und Erinnerungen nur, '
      'solange die App offen ist.';
  static const permissionBannerExactBody =
      'Ohne genaue Alarme können Benachrichtigungen einige Minuten '
      'verspätet kommen.';
  static const permissionAllow = 'Erlauben';
}
