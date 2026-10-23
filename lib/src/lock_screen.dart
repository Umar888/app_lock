import 'dart:async';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_lock_controller.dart';
import 'app_lock_labels.dart';
import 'lock_types.dart';
import 'pin_dots.dart';
import 'pin_pad.dart';

/// The built-in lock screen: PIN dots, a number pad and a biometric button.
///
/// Prompts for biometrics on its own as soon as the app is in the
/// foreground, shakes on a wrong PIN, and counts down during a lockout.
class LockScreen extends StatefulWidget {
  /// Creates the lock screen.
  const LockScreen({
    super.key,
    required this.controller,
    this.labels = const AppLockLabels(),
    this.blurBackground = true,
    this.header,
  });

  /// The controller to unlock.
  final AppLockController controller;

  /// Strings shown on screen.
  final AppLockLabels labels;

  /// Blurs the app behind the lock screen instead of hiding it completely.
  final bool blurBackground;

  /// Replaces the lock icon at the top, for example with your app logo.
  final Widget? header;

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  final _dots = GlobalKey<PinDotsState>();
  String _entered = '';
  String? _error;
  bool _checking = false;
  Timer? _ticker;
  late final AppLifecycleListener _lifecycle;
  bool _promptOnResume = false;

  AppLockController get _controller => widget.controller;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onControllerChanged);
    _syncTicker();
    // the Face ID prompt only makes the app inactive, so prompting again on
    // every resume would loop after a cancel. only re-prompt after a real
    // trip to the background (onShow), once the app is active again
    _lifecycle = AppLifecycleListener(
      onShow: () => _promptOnResume = true,
      onResume: () {
        if (!_promptOnResume) return;
        _promptOnResume = false;
        _biometrics();
      },
    );
    if (_controller.canUseBiometrics) _promptWhenVisible();
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    _ticker?.cancel();
    _lifecycle.dispose();
    super.dispose();
  }

  void _onControllerChanged() {
    _syncTicker();
    setState(() {});
  }

  // a lock taken while hidden builds this screen before the app is active,
  // and the system prompt can't show until it is
  void _promptWhenVisible() {
    final state = WidgetsBinding.instance.lifecycleState;
    // null means the engine hasn't reported a state yet, which only happens
    // before the first frame of a foreground launch
    if (state == null || state == AppLifecycleState.resumed) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _biometrics());
      return;
    }
    _promptOnResume = true;
  }

  void _syncTicker() {
    final locked = _controller.lockoutRemaining != null;
    if (locked && _ticker == null) {
      _ticker = Timer.periodic(const Duration(milliseconds: 250), (_) {
        if (_controller.lockoutRemaining == null) {
          _ticker?.cancel();
          _ticker = null;
          _error = null;
        }
        setState(() {});
      });
    } else if (!locked && _ticker != null) {
      _ticker?.cancel();
      _ticker = null;
    }
  }

  Future<void> _biometrics() async {
    if (!mounted ||
        !_controller.isLocked ||
        !_controller.canUseBiometrics ||
        _controller.isAuthenticating) {
      return;
    }
    final result = await _controller.unlockWithBiometrics();
    if (!mounted) return;
    if (result == BiometricResult.failed) {
      HapticFeedback.heavyImpact();
      _dots.currentState?.shake();
    }
  }

  Future<void> _onDigit(String digit) async {
    if (_checking || _entered.length >= _controller.pinLength) return;
    setState(() {
      _entered += digit;
      _error = null;
    });
    if (_entered.length < _controller.pinLength) return;

    setState(() => _checking = true);
    final result = await _controller.unlockWithPin(_entered);
    if (!mounted || result.isSuccess) return;
    HapticFeedback.heavyImpact();
    _dots.currentState?.shake();
    // let the full row of dots shake before it empties
    await Future<void>.delayed(const Duration(milliseconds: 350));
    if (!mounted) return;
    setState(() {
      _checking = false;
      _entered = '';
      _error = result.status == PinStatus.wrong
          ? widget.labels.wrongPin(result.attemptsRemaining ?? 0)
          : null;
    });
  }

  void _onDelete() {
    if (_checking || _entered.isEmpty) return;
    setState(() => _entered = _entered.substring(0, _entered.length - 1));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final lockout = _controller.lockoutRemaining;
    final kind = _controller.biometricKind;
    final message = lockout != null
        ? widget.labels.lockedOut(lockout)
        : _error ?? widget.labels.unlockSubtitle;

    Widget background = ColoredBox(color: scheme.surface);
    if (widget.blurBackground) {
      background = BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 32, sigmaY: 32),
        child: ColoredBox(color: scheme.surface.withValues(alpha: 0.72)),
      );
    }

    return Material(
      type: MaterialType.transparency,
      child: Stack(
        fit: StackFit.expand,
        children: [
          background,
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const SizedBox(height: 40),
                      Column(
                        children: [
                          widget.header ??
                              _LockBadge(locked: _controller.isLocked),
                          const SizedBox(height: 24),
                          Text(
                            widget.labels.enterPin,
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 200),
                            child: Text(
                              message,
                              key: ValueKey(
                                lockout == null ? message : 'lockout',
                              ),
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: _error != null || lockout != null
                                    ? scheme.error
                                    : scheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                          const SizedBox(height: 28),
                          PinDots(
                            key: _dots,
                            length: _controller.pinLength,
                            filled: _entered.length,
                            error: _error != null,
                          ),
                        ],
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(32, 32, 32, 24),
                        child: PinPad(
                          enabled: lockout == null && !_checking,
                          onDigit: _onDigit,
                          onDelete: _onDelete,
                          deleteLabel: widget.labels.delete,
                          leading: _controller.canUseBiometrics && kind != null
                              ? IconButton(
                                  key: const ValueKey('app_lock_biometric'),
                                  tooltip: widget.labels.useBiometrics(kind),
                                  iconSize: 34,
                                  color: scheme.primary,
                                  onPressed: _controller.isAuthenticating
                                      ? null
                                      : _biometrics,
                                  icon: Icon(biometricIcon(kind)),
                                )
                              : null,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The icon used for a biometric kind.
IconData biometricIcon(BiometricKind kind) => switch (kind) {
  BiometricKind.face => Icons.face_retouching_natural,
  BiometricKind.fingerprint => Icons.fingerprint,
  BiometricKind.iris => Icons.remove_red_eye_outlined,
  BiometricKind.generic => Icons.fingerprint,
};

class _LockBadge extends StatelessWidget {
  const _LockBadge({required this.locked});

  final bool locked;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 76,
      height: 76,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [scheme.primary, scheme.tertiary],
        ),
        boxShadow: [
          BoxShadow(
            color: scheme.primary.withValues(alpha: 0.35),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        transitionBuilder: (child, animation) =>
            ScaleTransition(scale: animation, child: child),
        child: Icon(
          locked ? Icons.lock_rounded : Icons.lock_open_rounded,
          key: ValueKey(locked),
          color: scheme.onPrimary,
          size: 34,
        ),
      ),
    );
  }
}
