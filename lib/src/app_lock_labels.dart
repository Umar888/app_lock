import 'lock_types.dart';

/// Every string the built-in screens show. Override any of them to translate
/// or reword.
class AppLockLabels {
  /// Creates labels, defaulting to English.
  const AppLockLabels({
    this.enterPin = 'Enter PIN',
    this.unlockSubtitle = 'Enter your PIN to unlock',
    this.wrongPin = _wrongPin,
    this.lockedOut = _lockedOut,
    this.useBiometrics = _useBiometrics,
    this.delete = 'Delete',
    this.createPin = 'Create a PIN',
    this.createPinSubtitle = 'You will use it to unlock the app',
    this.confirmPin = 'Confirm your PIN',
    this.confirmPinSubtitle = 'Enter it once more',
    this.pinMismatch = "PINs didn't match. Try again.",
    this.pinLengthOption = _pinLengthOption,
    this.cancel = 'Cancel',
  });

  /// Lock screen title.
  final String enterPin;

  /// Lock screen subtitle.
  final String unlockSubtitle;

  /// Shown after a wrong PIN, given the attempts left before a lockout.
  final String Function(int attemptsRemaining) wrongPin;

  /// Shown while PIN entry is blocked, given the time left.
  final String Function(Duration remaining) lockedOut;

  /// Semantics label for the biometric button.
  final String Function(BiometricKind kind) useBiometrics;

  /// Semantics label for the delete key.
  final String delete;

  /// PIN setup: first step title.
  final String createPin;

  /// PIN setup: first step subtitle.
  final String createPinSubtitle;

  /// PIN setup: confirmation step title.
  final String confirmPin;

  /// PIN setup: confirmation step subtitle.
  final String confirmPinSubtitle;

  /// PIN setup: shown when the confirmation differs.
  final String pinMismatch;

  /// PIN setup: label for the PIN length choice.
  final String Function(int digits) pinLengthOption;

  /// PIN setup: close button.
  final String cancel;
}

String _wrongPin(int attemptsRemaining) => attemptsRemaining == 1
    ? 'Wrong PIN. 1 attempt left before a timeout.'
    : 'Wrong PIN. $attemptsRemaining attempts left.';

String _lockedOut(Duration remaining) {
  final total =
      remaining.inSeconds + (remaining.inMilliseconds % 1000 > 0 ? 1 : 0);
  final minutes = total ~/ 60;
  final seconds = (total % 60).toString().padLeft(2, '0');
  return 'Too many attempts. Try again in $minutes:$seconds';
}

String _useBiometrics(BiometricKind kind) => switch (kind) {
  BiometricKind.face => 'Unlock with face',
  BiometricKind.fingerprint => 'Unlock with fingerprint',
  BiometricKind.iris => 'Unlock with iris',
  BiometricKind.generic => 'Unlock with biometrics',
};

String _pinLengthOption(int digits) => '$digits digits';
