import 'package:flutter_test/flutter_test.dart';
import 'package:tikky_takka/core/domain/domain.dart';
import 'package:tikky_takka/core/repo/repo.dart';
import 'package:tikky_takka/core/services/alarms/alarm_service.dart';
import 'package:tikky_takka/core/services/alarms/alarm_strings.dart';
import 'package:tikky_takka/features/alarms/alarms.dart';
import 'package:tikky_takka/l10n/strings.dart';

import '../../support/test_app.dart';
import '../tracks/tracks_harness.dart';

/// Permissions as a fresh Android 13 install reports them, granted once
/// the user went through the system flow.
class _PermissionAlarmService extends RecordingAlarmService {
  _PermissionAlarmService({this.supported = true});

  final bool supported;
  bool granted = false;
  int requests = 0;

  @override
  Future<AlarmPermissionStatus> permissionStatus() async =>
      AlarmPermissionStatus(
        supported: supported,
        notificationsGranted: granted,
        exactAlarmsGranted: granted,
      );

  @override
  Future<AlarmPermissionStatus> requestPermissions() {
    requests++;
    granted = true;
    return permissionStatus();
  }
}

void main() {
  testWidgets('a track ringing in another set is shown above the lanes and '
      'can be stopped there', (tester) async {
    final h = await TracksHarness.start(tester);
    final container = h.container;
    expect(find.byType(RingingBanner), findsOneWidget);
    expect(find.text(Strings.notifActionDismiss), findsNothing);

    final other = await h.run(
      () => container.read(setRepositoryProvider).createSet(name: 'Küche'),
    );
    final egg = await h.run(
      () => container
          .read(trackRepositoryProvider)
          .createTrack(
            setId: other.id,
            name: 'Eieruhr',
            config: const CountdownConfig(durationMs: 60000),
          ),
    );
    await h.run(() => container.read(trackCommandsProvider).startTrack(egg.id));

    await h.advance(const Duration(seconds: 30));
    expect(find.text('Eieruhr'), findsNothing);
    expect(container.read(ringingCountProvider), 0);

    await h.advance(const Duration(seconds: 35));
    expect(container.read(trackRingingProvider(egg.id)), isTrue);
    expect(find.text('Eieruhr'), findsOneWidget);
    expect(find.textContaining(AlarmStrings.ringing), findsOneWidget);
    // The one in-app ring mechanism fired for it, once.
    expect(h.rings.rung, [egg.id]);

    await h.tap(find.text(Strings.notifActionDismiss));
    expect(await h.snapshot(egg), isNull);
    expect(find.text('Eieruhr'), findsNothing);
    expect(container.read(ringingCountProvider), 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('ringing tracks of the active set are not repeated in the '
      'banner', (tester) async {
    final h = await TracksHarness.start(tester);
    final timer = h.timer;
    await h.tap(h.primary(timer));
    await h.advance(const Duration(minutes: 10, seconds: 2));

    expect(h.container.read(trackRingingProvider(timer.id)), isTrue);
    // Only the lane shows it.
    expect(find.text(Strings.notifActionDismiss), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a missing alarm permission is requested from the banner', (
    tester,
  ) async {
    final alarms = _PermissionAlarmService();
    final app = await TestApp.create(tester, alarmService: alarms);
    await app.pumpApp(tester);

    // The seed set has a timer, so alarms matter.
    expect(find.text(AlarmStrings.permissionBannerTitle), findsOneWidget);
    expect(find.text(AlarmStrings.permissionBannerBody), findsOneWidget);

    await tester.tap(find.text(AlarmStrings.permissionAllow));
    await app.settle(tester);
    expect(alarms.requests, 1);
    expect(find.text(AlarmStrings.permissionBannerTitle), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('no permission banner where alarms are unsupported', (
    tester,
  ) async {
    final app = await TestApp.create(
      tester,
      alarmService: _PermissionAlarmService(supported: false),
    );
    await app.pumpApp(tester);
    expect(find.byType(AlarmPermissionBanner), findsOneWidget);
    expect(find.text(AlarmStrings.permissionBannerTitle), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
