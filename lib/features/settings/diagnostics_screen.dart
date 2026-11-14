import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../adaptive/adaptive.dart';
import '../../core/services/alarms/alarms.dart';
import '../../core/services/diagnostics_log.dart';
import '../../core/services/lock_service.dart';
import '../../l10n/formatters.dart';
import '../../theme/theme.dart';
import 'settings_strings.dart';
import 'widgets/setting_rows.dart';
import 'widgets/settings_icons.dart';

/// Build number and commit, set by the CI build
/// (`--dart-define=BUILD_NUMBER=… --dart-define=GIT_SHA=…`).
const _buildNumber = String.fromEnvironment('BUILD_NUMBER');
const _gitSha = String.fromEnvironment('GIT_SHA');

/// Keys for tests.
abstract final class DiagnosticsKeys {
  static const testAlarm = ValueKey('diagnostics.testAlarm');
  static const copy = ValueKey('diagnostics.copy');
  static const clear = ValueKey('diagnostics.clear');
  static const noErrors = ValueKey('diagnostics.noErrors');
}

/// "Diagnose" in the settings: what a tester on a real device needs
/// without a debug console. Build and platform, the notification
/// permissions, a test alarm that rings with the app closed, and the
/// errors of this app run (copyable as a plain-text report).
class DiagnosticsScreen extends ConsumerStatefulWidget {
  const DiagnosticsScreen({required this.version, super.key});

  final String version;

  @override
  ConsumerState<DiagnosticsScreen> createState() => _DiagnosticsScreenState();
}

class _DiagnosticsScreenState extends ConsumerState<DiagnosticsScreen> {
  AlarmPermissionStatus? _alarms;
  bool? _lockSupported;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final alarms = await ref.read(alarmServiceProvider).permissionStatus();
    final lock = await ref.read(lockServiceProvider).isSupported();
    if (!mounted) return;
    setState(() {
      _alarms = alarms;
      _lockSupported = lock;
    });
  }

  Future<void> _request() async {
    final status = await ref.read(alarmServiceProvider).requestPermissions();
    if (!mounted) return;
    setState(() => _alarms = status);
  }

  Future<void> _testAlarm() async {
    await ref
        .read(alarmServiceProvider)
        .scheduleTestAlarm(const Duration(seconds: 10));
    if (!mounted) return;
    showInfoSnackBar(context, SettingsStrings.diagTestAlarmSet);
    await _refresh();
  }

  String get _build => _buildNumber.isEmpty
      ? SettingsStrings.diagBuildLocal
      : _gitSha.isEmpty
      ? _buildNumber
      : '$_buildNumber (${_gitSha.substring(0, _gitSha.length.clamp(0, 7))})';

  String get _mode => kReleaseMode
      ? 'Release'
      : kProfileMode
      ? 'Profile'
      : 'Debug';

  String get _platform => kIsWeb
      ? 'Web (${defaultTargetPlatform.name})'
      : defaultTargetPlatform.name;

  static String _yesNo(bool? value) => switch (value) {
    null => '…',
    true => SettingsStrings.diagYes,
    false => SettingsStrings.diagNo,
  };

  String _report(List<DiagnosticsEntry> errors) {
    final alarms = _alarms;
    final b = StringBuffer()
      ..writeln('Tikky Takka ${widget.version}')
      ..writeln('${SettingsStrings.diagBuild}: $_build')
      ..writeln('${SettingsStrings.diagMode}: $_mode')
      ..writeln('${SettingsStrings.diagPlatform}: $_platform')
      ..writeln(
        '${SettingsStrings.diagNotifications}: '
        '${SettingsStrings.diagSupported} ${_yesNo(alarms?.supported)}, '
        '${SettingsStrings.diagAllowed} '
        '${_yesNo(alarms?.notificationsGranted)}, '
        '${SettingsStrings.diagExact} ${_yesNo(alarms?.exactAlarmsGranted)}',
      )
      ..writeln('${SettingsStrings.diagAppLock}: ${_yesNo(_lockSupported)}')
      ..writeln();
    if (errors.isEmpty) b.writeln(SettingsStrings.diagNoErrors);
    for (final e in errors) {
      b
        ..writeln('[${Fmt.dateTime(e.at)}] ${e.source}: ${e.message}')
        ..writeln(e.stack?.trim() ?? '')
        ..writeln();
    }
    return b.toString();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tikky;
    final log = ref.watch(diagnosticsLogProvider);
    final alarms = _alarms;
    return AdaptivePageScaffold(
      title: const Text(SettingsStrings.diagnostics),
      body: ListenableBuilder(
        listenable: log,
        builder: (context, _) {
          final errors = log.entries.reversed.toList();
          return SettingsBody(
            children: [
              AdaptiveSection(
                header: SettingsStrings.diagApp,
                children: [
                  AdaptiveTile(
                    title: SettingsStrings.diagBuild,
                    value: '${widget.version} · $_build',
                  ),
                  AdaptiveTile(title: SettingsStrings.diagMode, value: _mode),
                  AdaptiveTile(
                    title: SettingsStrings.diagPlatform,
                    value: _platform,
                  ),
                  AdaptiveTile(
                    title: SettingsStrings.diagAppLock,
                    value: _yesNo(_lockSupported),
                  ),
                ],
              ),
              AdaptiveSection(
                header: SettingsStrings.diagNotifications,
                children: [
                  AdaptiveTile(
                    title: SettingsStrings.diagSupported,
                    value: _yesNo(alarms?.supported),
                  ),
                  AdaptiveTile(
                    title: SettingsStrings.diagAllowed,
                    value: _yesNo(alarms?.notificationsGranted),
                  ),
                  AdaptiveTile(
                    title: SettingsStrings.diagExact,
                    value: _yesNo(alarms?.exactAlarmsGranted),
                  ),
                  if (alarms != null && alarms.supported && !alarms.allGranted)
                    AdaptiveTile(
                      leading: Icon(SettingsIcons.notifications(context)),
                      title: SettingsStrings.diagRequest,
                      onTap: _request,
                    ),
                  AdaptiveTile(
                    key: DiagnosticsKeys.testAlarm,
                    leading: Icon(SettingsIcons.alarmTest(context)),
                    title: SettingsStrings.diagTestAlarm,
                    subtitle: SettingsStrings.diagTestAlarmHint,
                    onTap: alarms?.supported == true ? _testAlarm : null,
                  ),
                ],
              ),
              AdaptiveSection(
                header: SettingsStrings.diagErrors,
                footer: SettingsStrings.diagErrorsFooter,
                children: [
                  AdaptiveTile(
                    key: DiagnosticsKeys.copy,
                    leading: Icon(SettingsIcons.copy(context)),
                    title: SettingsStrings.diagCopy,
                    onTap: () async {
                      await Clipboard.setData(
                        ClipboardData(text: _report(log.entries)),
                      );
                      if (!context.mounted) return;
                      showInfoSnackBar(context, SettingsStrings.diagCopied);
                    },
                  ),
                  if (errors.isEmpty)
                    const AdaptiveTile(
                      key: DiagnosticsKeys.noErrors,
                      title: SettingsStrings.diagNoErrors,
                    )
                  else ...[
                    for (final e in errors)
                      Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: t.space.lg,
                          vertical: t.space.sm,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${Fmt.dateTime(e.at)} · ${e.source}',
                              style: t.text.caption,
                            ),
                            Text(
                              e.message,
                              style: t.text.body,
                              maxLines: 4,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    AdaptiveTile(
                      key: DiagnosticsKeys.clear,
                      title: SettingsStrings.diagClear,
                      destructive: true,
                      onTap: log.clear,
                    ),
                  ],
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}
