import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'lock_types.dart';

/// Talks to the native side that hides content in the app switcher.
class PrivacyGuard {
  /// Creates a guard on the default channel.
  const PrivacyGuard();

  static const _channel = MethodChannel('app_lock/privacy');

  /// Applies [mode] to the app window.
  Future<void> setMode(PrivacyMode mode) =>
      _invoke('setMode', {'mode': mode.name});

  /// Temporarily stops covering the app, for example while the biometric
  /// prompt makes it inactive.
  Future<void> setSuspended(bool suspended) =>
      _invoke('setSuspended', {'suspended': suspended});

  Future<void> _invoke(String method, Map<String, Object> args) async {
    try {
      await _channel.invokeMethod<void>(method, args);
    } on MissingPluginException {
      // no native side on this platform or in unit tests
    } on PlatformException catch (e) {
      debugPrint('app_lock: $method failed: ${e.message}');
    }
  }
}
