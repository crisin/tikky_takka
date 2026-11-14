/// In-app side of the alarms: which tracks ring right now, the permission
/// state and the banners of the tracks screen ([RingingBanner] for tracks
/// of other sets, [AlarmPermissionBanner]).
///
/// The sound and haptics the moment something becomes due are NOT played
/// here: that is the job of `RingMonitor` (features/tracks), which is
/// mounted on the tracks screen and is the only such mechanism in the app.
/// `trackRingingProvider(track.id)` / [TrackRingingPulse] are available to
/// widgets that want to show the ringing state.
library;

export 'alarm_permission.dart';
export 'alert_cue.dart';
export 'ringing_providers.dart';
export 'ringing_widgets.dart';
