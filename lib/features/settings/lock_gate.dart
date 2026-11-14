import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../adaptive/adaptive.dart';
import '../../core/services/lock_service.dart';
import '../../core/services/screen_security.dart';
import '../../l10n/strings.dart';
import '../../theme/theme.dart';

/// Additional German texts of the app lock (the shared ones live in
/// `Strings`).
abstract final class LockStrings {
  static const unlockFailed = 'Entsperren nicht bestätigt.';
  static const unlocking = 'Warte auf Bestätigung …';
  static const settingUnchanged =
      'Nicht bestätigt – die App-Sperre bleibt unverändert.';
  static const lockNowHint = 'Gilt ab dem nächsten Öffnen der App.';
  static const checkFailed =
      'Die Gerätesperre konnte nicht geprüft werden. Die App bleibt gesperrt.';
  static const retry = 'Erneut versuchen';
  static const checkFailedTile =
      'Gerätesperre konnte nicht geprüft werden. Tippen, um es erneut zu '
      'versuchen.';
}

/// Wraps the whole app (see `MaterialApp.builder` in app.dart) and hides it
/// behind the device authentication prompt while the app lock is active.
///
/// * Lock off, or the device DEFINITELY cannot authenticate: nothing is
///   ever covered.
/// * Lock on and the device check failed (exception): the app stays
///   covered and offers "Erneut versuchen"; a failed check never unlocks.
/// * Lock on (Android): the window is also marked secure, which keeps the
///   app out of screenshots and the recent-apps overview.
/// * Lock on: the app is covered on launch and after every trip to the
///   background (`AppLifecycleState.paused` / `hidden`) by an opaque screen
///   and the system prompt is shown once; "Entsperren" asks again.
/// * On phones the app is also covered while it is merely inactive (app
///   switcher, system dialogs), without asking again on return.
///
/// [child] stays in the tree while covered (not painted, not focusable, no
/// animations), so navigation state, open sheets and typed text survive a
/// lock.
class LockGate extends ConsumerWidget {
  const LockGate({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) => _LockGateHost(child);
}

class _LockGateHost extends ConsumerStatefulWidget {
  const _LockGateHost(this.child);

  final Widget child;

  @override
  ConsumerState<_LockGateHost> createState() => _LockGateHostState();
}

class _LockGateHostState extends ConsumerState<_LockGateHost>
    with WidgetsBindingObserver {
  /// Authentication is required before the app is shown again.
  bool _locked = false;

  /// The app is inactive (phones only): covered, but no authentication.
  bool _shielded = false;

  /// Show the system prompt automatically as soon as possible. Set on
  /// launch and on backgrounding, cleared by the first attempt, so a
  /// cancelled prompt never comes back on its own.
  bool _autoPrompt = false;

  /// The last attempt was cancelled or failed.
  bool _failed = false;

  bool get _enabled => ref.read(appLockEnabledProvider);

  /// `null` while the device check is still running or after it failed.
  bool? get _supported => _definite(ref.read(lockSupportedProvider));

  /// Only a completed check counts; an error is "unknown", never `false`.
  static bool? _definite(AsyncValue<bool> check) =>
      check.hasError ? null : check.value;

  /// Runs the device check again after it failed.
  void _retryCheck() {
    _autoPrompt = _locked;
    ref.invalidate(lockSupportedProvider);
  }

  /// Covering the app while inactive only makes sense where "inactive"
  /// means app switcher or a system overlay; on desktop it is just a
  /// window without keyboard focus.
  bool get _shieldWhenInactive =>
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _locked = _enabled;
    _autoPrompt = _locked;

    ref.listenManual<bool>(appLockEnabledProvider, (previous, enabled) {
      // Switching the lock on does not lock the running app; switching it
      // off releases a lock at once.
      if (!enabled && (_locked || _shielded)) {
        setState(() {
          _locked = false;
          _shielded = false;
          _failed = false;
        });
      }
    });
    ref.listenManual<AsyncValue<bool>>(
      lockSupportedProvider,
      (previous, next) => _maybePrompt(),
      fireImmediately: true,
    );
    ref.listenManual<bool>(
      appLockEnabledProvider,
      (previous, enabled) =>
          unawaited(ref.read(screenSecurityProvider).setSecure(enabled)),
      fireImmediately: true,
    );
    ref.listenManual<LockPromptState>(lockPromptProvider, (previous, next) {
      if (!mounted) return;
      final passed = next.successes > (previous?.successes ?? 0);
      final missed = next.failures > (previous?.failures ?? 0);
      if (passed) {
        // Any passed prompt unlocks, whoever asked for it.
        setState(() {
          _locked = false;
          _failed = false;
          _autoPrompt = false;
        });
      } else if (missed && _locked) {
        setState(() => _failed = true);
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        if (_shielded) setState(() => _shielded = false);
        // A failed device check gets another chance on every return.
        if (_enabled &&
            _locked &&
            ref.read(lockSupportedProvider).hasError &&
            !ref.read(lockSupportedProvider).isLoading) {
          _retryCheck();
        }
        _maybePrompt();
      case AppLifecycleState.inactive:
        if (_enabled && _shieldWhenInactive && !_shielded) {
          setState(() => _shielded = true);
        }
      case AppLifecycleState.hidden || AppLifecycleState.paused:
        if (!_enabled || _supported == false) return;
        // A prompt that is on screen right now keeps running (the plugin
        // retries it on return); only ask again when there is none.
        final promptActive = ref.read(lockPromptProvider).active;
        setState(() {
          _locked = true;
          _failed = false;
          _autoPrompt = !promptActive;
        });
      case AppLifecycleState.detached:
        break;
    }
  }

  /// Shows the system prompt once, when the app is locked, in the
  /// foreground and the device is known to support authentication.
  void _maybePrompt() {
    if (!mounted || !_locked || !_autoPrompt) return;
    if (!_enabled || _supported != true) return;
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    if (lifecycle != null && lifecycle != AppLifecycleState.resumed) return;
    _autoPrompt = false;
    // Not synchronously: this may run while the widget tree is building,
    // where provider state must not change.
    scheduleMicrotask(_unlock);
  }

  Future<void> _unlock() async {
    if (!mounted || ref.read(lockPromptProvider).active) return;
    if (_failed) setState(() => _failed = false);
    // The result arrives through the lockPromptProvider listener.
    await ref
        .read(lockPromptProvider.notifier)
        .authenticate(reason: Strings.appLockReason);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = ref.watch(appLockEnabledProvider);
    final check = ref.watch(lockSupportedProvider);
    final supported = _definite(check);
    final checkFailed = check.hasError && !check.isLoading;
    final prompting = ref.watch(lockPromptProvider.select((s) => s.active));
    // While the device check is still running - or when it failed - the
    // app stays covered: it must not flash its content on launch, and an
    // exception must never open a locked app. Only a definite "this device
    // cannot authenticate" disables the gate.
    final active = enabled && supported != false;
    final covered = active && (_locked || _shielded);

    return Stack(
      alignment: Alignment.topLeft,
      fit: StackFit.expand,
      children: [
        // Always at the same place in the tree, so the navigator below
        // keeps its state across locking and unlocking.
        Offstage(
          offstage: covered,
          child: TickerMode(
            enabled: !covered,
            child: ExcludeFocus(excluding: covered, child: widget.child),
          ),
        ),
        if (covered)
          _LockScreen(
            // Only a real lock offers "Entsperren"; the inactive shield
            // goes away by itself.
            showUnlock: _locked,
            canUnlock: supported == true && !prompting,
            prompting: prompting,
            failed: _failed,
            onUnlock: _unlock,
            checkFailed: checkFailed,
            onRetryCheck: _retryCheck,
          ),
      ],
    );
  }
}

/// The opaque screen shown instead of the app while it is locked.
class _LockScreen extends StatelessWidget {
  const _LockScreen({
    required this.showUnlock,
    required this.canUnlock,
    required this.prompting,
    required this.failed,
    required this.onUnlock,
    required this.checkFailed,
    required this.onRetryCheck,
  });

  /// The device check threw: offer to run it again instead of unlocking.
  final bool checkFailed;
  final VoidCallback onRetryCheck;

  final bool showUnlock;
  final bool canUnlock;
  final bool prompting;
  final bool failed;
  final VoidCallback onUnlock;

  @override
  Widget build(BuildContext context) {
    final t = context.tikky;
    return Material(
      color: t.colors.background,
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(t.space.xl),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: t.sizes.sheetMaxWidth),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    AdaptiveIcons.lock(context),
                    size: t.sizes.iconXl,
                    color: t.colors.textMuted,
                  ),
                  SizedBox(height: t.space.lg),
                  Text(
                    Strings.appName,
                    style: t.text.title,
                    textAlign: TextAlign.center,
                  ),
                  if (showUnlock) ...[
                    SizedBox(height: t.space.xs),
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        checkFailed
                            ? LockStrings.checkFailed
                            : prompting
                            ? LockStrings.unlocking
                            : failed
                            ? LockStrings.unlockFailed
                            : Strings.appLocked,
                        style: t.text.bodyMuted,
                        textAlign: TextAlign.center,
                      ),
                    ),
                    SizedBox(height: t.space.xl),
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: t.sizes.bigTapTarget,
                      ),
                      child: checkFailed
                          ? AdaptiveFilledButton(
                              label: LockStrings.retry,
                              icon: AdaptiveIcons.lock(context),
                              onPressed: onRetryCheck,
                            )
                          : AdaptiveFilledButton(
                              label: Strings.unlock,
                              icon: AdaptiveIcons.lock(context),
                              onPressed: canUnlock ? onUnlock : null,
                            ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The "App-Sperre" row for the settings screen: a switch that turns the
/// lock on or off after the user passed the device authentication once (so
/// a lock that cannot be opened is never switched on, and nobody else can
/// switch it off).
///
/// On devices that cannot authenticate the row is shown disabled with
/// "Auf diesem Gerät nicht verfügbar", or not at all with
/// [hideWhenUnsupported].
///
/// Place it inside an `AdaptiveSection`:
///
/// ```dart
/// AdaptiveSection(
///   header: Strings.settingsPrivacy,
///   children: const [AppLockTile()],
/// )
/// ```
class AppLockTile extends ConsumerWidget {
  const AppLockTile({this.hideWhenUnsupported = false, super.key});

  /// Build nothing instead of a disabled row when the device cannot
  /// authenticate.
  final bool hideWhenUnsupported;

  Future<void> _toggle(
    BuildContext context,
    WidgetRef ref, {
    required bool enable,
  }) async {
    final prompt = ref.read(lockPromptProvider.notifier);
    final setting = ref.read(appLockEnabledProvider.notifier);
    final ok = await prompt.authenticate(reason: Strings.appLockReason);
    if (ok) {
      await setting.set(enable);
      if (enable && context.mounted) {
        showInfoSnackBar(context, LockStrings.lockNowHint);
      }
    } else if (context.mounted) {
      showInfoSnackBar(context, LockStrings.settingUnchanged);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tikky;
    final enabled = ref.watch(appLockEnabledProvider);
    final check = ref.watch(lockSupportedProvider);
    // A failed check is "unknown" (row disabled), not "unsupported".
    final supported = check.hasError ? null : check.value;
    final prompting = ref.watch(lockPromptProvider.select((s) => s.active));
    final leading = Icon(
      AdaptiveIcons.lock(context),
      size: t.sizes.iconMd,
      color: t.colors.textMuted,
    );

    if (supported == false) {
      if (hideWhenUnsupported) return const SizedBox.shrink();
      return AdaptiveSwitchTile(
        title: Strings.appLock,
        subtitle: Strings.appLockUnavailable,
        leading: leading,
        value: false,
        onChanged: null,
      );
    }
    if (check.hasError && !check.isLoading) {
      // Unknown, not "unsupported": the switch keeps showing the stored
      // setting and a tap runs the device check again.
      return AdaptiveSwitchTile(
        title: Strings.appLock,
        subtitle: LockStrings.checkFailedTile,
        leading: leading,
        value: enabled,
        onChanged: (_) => ref.invalidate(lockSupportedProvider),
      );
    }
    return AdaptiveSwitchTile(
      title: Strings.appLock,
      subtitle: Strings.appLockHint,
      leading: leading,
      value: enabled,
      // Disabled while the device check or a prompt is running.
      onChanged: supported == null || prompting
          ? null
          : (value) => _toggle(context, ref, enable: value),
    );
  }
}
