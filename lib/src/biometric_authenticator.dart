import 'package:local_auth/local_auth.dart';
import 'package:local_auth_android/local_auth_android.dart';
import 'package:local_auth_darwin/local_auth_darwin.dart';

import 'lock_types.dart';

/// Shows the platform biometric prompt.
///
/// [LocalAuthBiometrics] is the default. Implement this to use another
/// plugin or to fake biometrics in tests.
abstract interface class BiometricAuthenticator {
  /// The biometric the device can use right now, or `null` if none is
  /// available (no hardware, nothing enrolled, or disabled).
  Future<BiometricKind?> availableKind();

  /// Prompts the user with [reason] and reports the outcome.
  Future<BiometricResult> authenticate(String reason);
}

/// A [BiometricAuthenticator] built on the official `local_auth` plugin.
///
/// Biometrics only: the app's own PIN is the fallback, so the device passcode
/// is never offered.
class LocalAuthBiometrics implements BiometricAuthenticator {
  /// Creates an authenticator, optionally around an existing [auth].
  ///
  /// [fallbackTitle] labels the button that leaves the system prompt for the
  /// PIN: the "Enter Password" button iOS shows after a failed attempt, and
  /// the negative button of Android's prompt.
  LocalAuthBiometrics({
    LocalAuthentication? auth,
    this.fallbackTitle = 'Use PIN',
  }) : _auth = auth ?? LocalAuthentication();

  final LocalAuthentication _auth;

  /// Label for the system prompt's way back to the PIN.
  final String fallbackTitle;

  @override
  Future<BiometricKind?> availableKind() async {
    try {
      if (!await _auth.canCheckBiometrics) return null;
      final types = await _auth.getAvailableBiometrics();
      if (types.isEmpty) return null;
      if (types.contains(BiometricType.face)) return BiometricKind.face;
      if (types.contains(BiometricType.fingerprint)) {
        return BiometricKind.fingerprint;
      }
      if (types.contains(BiometricType.iris)) return BiometricKind.iris;
      return BiometricKind.generic;
    } on Object {
      return null;
    }
  }

  @override
  Future<BiometricResult> authenticate(String reason) async {
    try {
      final ok = await _auth.authenticate(
        localizedReason: reason,
        biometricOnly: true,
        authMessages: [
          IOSAuthMessages(localizedFallbackTitle: fallbackTitle),
          AndroidAuthMessages(cancelButton: fallbackTitle),
        ],
      );
      return ok ? BiometricResult.success : BiometricResult.failed;
    } on LocalAuthException catch (e) {
      return switch (e.code) {
        LocalAuthExceptionCode.userCanceled ||
        LocalAuthExceptionCode.systemCanceled ||
        LocalAuthExceptionCode.timeout ||
        LocalAuthExceptionCode.userRequestedFallback ||
        LocalAuthExceptionCode.authInProgress => BiometricResult.cancelled,
        LocalAuthExceptionCode.biometricLockout ||
        LocalAuthExceptionCode.temporaryLockout => BiometricResult.lockedOut,
        LocalAuthExceptionCode.noBiometricsEnrolled ||
        LocalAuthExceptionCode.noBiometricHardware ||
        LocalAuthExceptionCode.noCredentialsSet ||
        LocalAuthExceptionCode.biometricHardwareTemporarilyUnavailable ||
        LocalAuthExceptionCode.uiUnavailable => BiometricResult.unavailable,
        _ => BiometricResult.error,
      };
    } on Object {
      return BiometricResult.error;
    }
  }
}
