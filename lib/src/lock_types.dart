/// Outcome of a biometric unlock attempt.
enum BiometricResult {
  /// The user was recognised.
  success,

  /// The biometric did not match.
  failed,

  /// The user dismissed the prompt, chose the PIN, or the system cancelled it.
  cancelled,

  /// Too many failed biometric attempts; the OS has locked biometrics.
  lockedOut,

  /// No biometric hardware, nothing enrolled, or biometrics are turned off.
  unavailable,

  /// Any other platform error.
  error,
}

/// The kind of biometric the device offers, used to pick icons and labels.
enum BiometricKind {
  /// Face ID or Android face unlock.
  face,

  /// Touch ID or a fingerprint sensor.
  fingerprint,

  /// Iris scanner.
  iris,

  /// A biometric the platform does not describe further.
  generic,
}

/// How the app's content is protected while it is in the background.
enum PrivacyMode {
  /// No protection. The app switcher shows a live snapshot.
  none,

  /// Hide the content in the app switcher.
  ///
  /// iOS covers the window with a blur while the app is inactive. Android 13+
  /// hides the recents thumbnail while still allowing screenshots, and older
  /// Android versions fall back to `FLAG_SECURE`.
  hideInAppSwitcher,

  /// Like [hideInAppSwitcher], and on Android also block screenshots and
  /// screen recording with `FLAG_SECURE`. iOS cannot block screenshots, so it
  /// behaves like [hideInAppSwitcher] there.
  secure,
}

/// Whether a PIN attempt worked.
enum PinStatus {
  /// The PIN was correct and the app is unlocked.
  success,

  /// The PIN was wrong.
  wrong,

  /// Too many wrong attempts; PIN entry is blocked for a while.
  lockedOut,
}

/// The result of `AppLockController.unlockWithPin`.
class PinResult {
  /// Creates a result.
  const PinResult(this.status, {this.attemptsRemaining, this.lockedOutFor});

  /// What happened.
  final PinStatus status;

  /// Wrong attempts left before the next lockout, when known.
  final int? attemptsRemaining;

  /// How long PIN entry is blocked, for [PinStatus.lockedOut] or when this
  /// wrong attempt triggered a lockout.
  final Duration? lockedOutFor;

  /// Whether the app was unlocked.
  bool get isSuccess => status == PinStatus.success;
}
