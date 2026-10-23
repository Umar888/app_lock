/// An all-in-one app lock for Flutter: biometrics with a PIN fallback,
/// lockout after wrong attempts, lock on background or timeout, and content
/// hidden in the app switcher.
library;

export 'src/app_lock_controller.dart';
export 'src/app_lock_labels.dart';
export 'src/app_lock_widget.dart';
export 'src/biometric_authenticator.dart';
export 'src/lock_screen.dart' show LockScreen, biometricIcon;
export 'src/lock_store.dart';
export 'src/lock_types.dart';
export 'src/lockout_policy.dart';
export 'src/pin_dots.dart';
export 'src/pin_hasher.dart' show PinHash;
export 'src/pin_pad.dart';
export 'src/pin_setup_page.dart';
