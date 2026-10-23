import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'biometric_authenticator.dart';
import 'lock_store.dart';
import 'lock_types.dart';
import 'lockout_policy.dart';
import 'pin_hasher.dart';
import 'privacy_guard.dart';

/// Owns the lock state: whether the app is locked, the PIN, biometrics and
/// lockouts. Hand it to an `AppLock` widget, and use it from settings screens
/// to turn the lock on and off.
///
/// The lock is on once a PIN is set. Biometrics are an optional shortcut on
/// top, and the PIN always works as a fallback.
///
/// ```dart
/// final lock = AppLockController(lockAfter: const Duration(seconds: 30));
///
/// Future<void> main() async {
///   WidgetsFlutterBinding.ensureInitialized();
///   await lock.init(); // before runApp, so the first frame is already locked
///   runApp(MyApp());
/// }
/// ```
class AppLockController extends ChangeNotifier with WidgetsBindingObserver {
  /// Creates a controller.
  ///
  /// - [store] persists the PIN hash, settings and lockout state. Defaults to
  ///   an encrypted [VaultLockStore].
  /// - [biometrics] shows the system prompt. Defaults to
  ///   [LocalAuthBiometrics].
  /// - [lockAfter] is how long the app may sit in the background before it
  ///   locks. [Duration.zero] locks as soon as the app is hidden.
  /// - [lockOnLaunch] locks on a cold start.
  /// - [privacyMode] hides content in the app switcher while the lock is on.
  /// - [biometricReason] is shown in the system prompt where the platform
  ///   supports it.
  AppLockController({
    LockStore? store,
    BiometricAuthenticator? biometrics,
    Duration lockAfter = Duration.zero,
    this.lockOnLaunch = true,
    this.lockoutPolicy = const LockoutPolicy(),
    PrivacyMode privacyMode = PrivacyMode.hideInAppSwitcher,
    this.biometricReason = 'Unlock to continue',
    this.pinHashIterations = 20000,
    @visibleForTesting DateTime Function()? clock,
    @visibleForTesting PrivacyGuard privacyGuard = const PrivacyGuard(),
  }) : _store = store ?? VaultLockStore(),
       _biometrics = biometrics ?? LocalAuthBiometrics(),
       _lockAfter = lockAfter,
       _privacyMode = privacyMode,
       _clock = clock ?? DateTime.now,
       _privacy = privacyGuard;

  final LockStore _store;
  final BiometricAuthenticator _biometrics;
  final DateTime Function() _clock;
  final PrivacyGuard _privacy;

  /// Whether a cold start begins locked.
  final bool lockOnLaunch;

  /// How wrong PINs are throttled.
  final LockoutPolicy lockoutPolicy;

  /// Text for the biometric system prompt.
  final String biometricReason;

  /// PBKDF2 iterations used when a new PIN is hashed.
  final int pinHashIterations;

  LockRecord _record = LockRecord.empty;
  BiometricKind? _biometricKind;
  bool _ready = false;
  bool _locked = false;
  bool _authenticating = false;
  bool _disposed = false;
  DateTime? _hiddenAt;
  Future<void>? _init;
  AppLifecycleListener? _lifecycle;

  // ------------------------------------------------------------------ state

  /// Whether [init] has finished. Until then `AppLock` shows a blank cover so
  /// content never flashes before the lock decision is made.
  bool get isReady => _ready;

  /// Whether the lock screen is showing.
  bool get isLocked => _locked;

  /// Whether the lock is turned on, which is the same as having a PIN.
  bool get isEnabled => _record.pin != null;

  /// Whether a PIN is set.
  bool get hasPin => _record.pin != null;

  /// Digits in the current PIN, or 0 when none is set.
  int get pinLength => _record.pinLength;

  /// Whether the user turned on biometric unlock.
  bool get biometricsEnabled => _record.biometricsEnabled;

  /// The biometric the device offers, or `null` if none is usable.
  BiometricKind? get biometricKind => _biometricKind;

  /// Whether the device has a usable biometric, whether or not it is enabled.
  bool get biometricsAvailable => _biometricKind != null;

  /// Whether the lock screen should offer biometrics right now.
  bool get canUseBiometrics =>
      isEnabled && biometricsEnabled && biometricsAvailable;

  /// Whether a biometric prompt is on screen.
  bool get isAuthenticating => _authenticating;

  /// Wrong PINs in a row since the last successful unlock.
  int get failedAttempts => _record.failedAttempts;

  /// Wrong PINs left before the next lockout.
  int get attemptsBeforeLockout =>
      lockoutPolicy.attemptsBeforeLockout(_record.failedAttempts);

  /// Time left before PIN entry is allowed again, or `null` if not locked
  /// out.
  Duration? get lockoutRemaining {
    final until = _record.lockedUntil;
    if (until == null) return null;
    final left = until.difference(_clock());
    return left > Duration.zero ? left : null;
  }

  /// How long the app may stay in the background before it locks.
  Duration get lockAfter => _lockAfter;
  Duration _lockAfter;
  set lockAfter(Duration value) {
    if (value == _lockAfter) return;
    _lockAfter = value;
    notifyListeners();
  }

  /// How content is hidden in the app switcher while the lock is on.
  PrivacyMode get privacyMode => _privacyMode;
  PrivacyMode _privacyMode;
  set privacyMode(PrivacyMode value) {
    if (value == _privacyMode) return;
    _privacyMode = value;
    _applyPrivacy();
    notifyListeners();
  }

  // ------------------------------------------------------------- lifecycle

  /// Loads the saved state, checks biometrics and starts watching the app
  /// lifecycle. Safe to call more than once.
  ///
  /// Call it before `runApp` so a locked app is locked on its first frame,
  /// and so Android's back button is caught before the app's navigator.
  Future<void> init() => _init ??= _load();

  Future<void> _load() async {
    final binding = WidgetsFlutterBinding.ensureInitialized();
    // registered before the app's own observer, so a locked app swallows the
    // back button instead of popping routes hidden under the lock screen
    binding.addObserver(this);
    _lifecycle = AppLifecycleListener(onHide: _onHide, onShow: _onShow);

    _record = await _store.load();
    _biometricKind = await _biometrics.availableKind();
    if (_disposed) return;
    _locked = isEnabled && lockOnLaunch;
    _ready = true;
    await _applyPrivacy();
    notifyListeners();
  }

  void _onHide() {
    // the biometric prompt only makes the app inactive, but leaving the app
    // while it's up shouldn't start the background timer either
    if (!isEnabled || _authenticating) return;
    _hiddenAt = _clock();
    if (_lockAfter == Duration.zero) lock();
  }

  void _onShow() {
    final hiddenAt = _hiddenAt;
    _hiddenAt = null;
    if (hiddenAt == null || _locked || !isEnabled) return;
    if (_clock().difference(hiddenAt) >= _lockAfter) lock();
  }

  @override
  Future<bool> didPopRoute() async => _locked;

  @override
  bool handleStartBackGesture(PredictiveBackEvent backEvent) => _locked;

  // ---------------------------------------------------------------- locking

  /// Locks the app now. Does nothing while the lock is off.
  void lock() {
    if (!isEnabled || _locked) return;
    _locked = true;
    // a focused text field under the lock screen would still get keystrokes
    FocusManager.instance.primaryFocus?.unfocus();
    notifyListeners();
  }

  /// Tries to unlock with [pin], counting wrong attempts towards a lockout.
  Future<PinResult> unlockWithPin(String pin) async {
    final result = await _checkPin(pin);
    if (result.isSuccess) _unlock();
    return result;
  }

  /// Checks [pin] without changing the lock state, for example before
  /// letting the user change or remove it. Wrong attempts still count
  /// towards a lockout, so a settings screen can't be used to brute force the
  /// PIN.
  Future<PinResult> verifyPin(String pin) => _checkPin(pin);

  Future<PinResult> _checkPin(String pin) async {
    final hash = _record.pin;
    if (hash == null) throw StateError('no PIN is set');

    final blocked = lockoutRemaining;
    if (blocked != null) {
      return PinResult(PinStatus.lockedOut, lockedOutFor: blocked);
    }

    if (await hash.verify(pin)) {
      await _resetFailures();
      return const PinResult(PinStatus.success);
    }

    final failed = _record.failedAttempts + 1;
    final lockout = lockoutPolicy.lockoutAfter(failed);
    _record = _record.copyWith(
      failedAttempts: failed,
      lockedUntil: lockout == null ? null : _clock().add(lockout),
    );
    await _store.save(_record);
    notifyListeners();
    return PinResult(
      lockout == null ? PinStatus.wrong : PinStatus.lockedOut,
      attemptsRemaining: lockoutPolicy.attemptsBeforeLockout(failed),
      lockedOutFor: lockout,
    );
  }

  /// Shows the biometric prompt and unlocks on success.
  ///
  /// Works during a PIN lockout too, since it is a separate factor that the
  /// OS throttles on its own.
  Future<BiometricResult> unlockWithBiometrics() async {
    if (!canUseBiometrics) return BiometricResult.unavailable;
    final result = await _prompt();
    if (result == BiometricResult.success) {
      await _resetFailures();
      _unlock();
    }
    return result;
  }

  Future<BiometricResult> _prompt() async {
    if (_authenticating) return BiometricResult.cancelled;
    _authenticating = true;
    notifyListeners();
    await _privacy.setSuspended(true);
    try {
      return await _biometrics.authenticate(biometricReason);
    } finally {
      _authenticating = false;
      await _privacy.setSuspended(false);
      if (!_disposed) notifyListeners();
    }
  }

  void _unlock() {
    _locked = false;
    _hiddenAt = null;
    notifyListeners();
  }

  Future<void> _resetFailures() async {
    if (_record.failedAttempts == 0 && _record.lockedUntil == null) return;
    _record = _record.copyWith(failedAttempts: 0, clearLockout: true);
    await _store.save(_record);
  }

  // ---------------------------------------------------------------- settings

  /// Sets or replaces the PIN, which turns the lock on. [pin] must be 4 to 8
  /// digits. Doesn't lock the app; call [lock] for that.
  ///
  /// To change an existing PIN, confirm the old one with [verifyPin] first.
  Future<void> setPin(String pin) async {
    if (!RegExp(r'^\d{4,8}$').hasMatch(pin)) {
      throw ArgumentError.value('****', 'pin', 'must be 4 to 8 digits');
    }
    final wasEnabled = isEnabled;
    _record = _record.copyWith(
      pin: await PinHash.create(pin, iterations: pinHashIterations),
      pinLength: pin.length,
      failedAttempts: 0,
      clearLockout: true,
    );
    await _store.save(_record);
    if (!wasEnabled) await _applyPrivacy();
    notifyListeners();
  }

  /// Turns biometric unlock on or off. Turning it on shows the prompt once
  /// to confirm it works, and only enables it on success.
  Future<BiometricResult> setBiometricsEnabled(bool enabled) async {
    if (!enabled) {
      _record = _record.copyWith(biometricsEnabled: false);
      await _store.save(_record);
      notifyListeners();
      return BiometricResult.success;
    }
    if (!isEnabled) throw StateError('set a PIN before enabling biometrics');
    _biometricKind = await _biometrics.availableKind();
    if (_biometricKind == null) return BiometricResult.unavailable;
    final result = await _prompt();
    if (result == BiometricResult.success) {
      _record = _record.copyWith(biometricsEnabled: true);
      await _store.save(_record);
      notifyListeners();
    }
    return result;
  }

  /// Removes the PIN and biometrics, turning the lock off and unlocking.
  Future<void> disable() async {
    _record = LockRecord.empty;
    await _store.save(_record);
    _locked = false;
    _hiddenAt = null;
    await _applyPrivacy();
    notifyListeners();
  }

  /// Re-checks which biometric the device offers, for example after the user
  /// returns from system settings.
  Future<void> refreshBiometrics() async {
    _biometricKind = await _biometrics.availableKind();
    notifyListeners();
  }

  Future<void> _applyPrivacy() =>
      _privacy.setMode(isEnabled ? _privacyMode : PrivacyMode.none);

  @override
  void dispose() {
    _disposed = true;
    _lifecycle?.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
