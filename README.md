# app_lock

An all-in-one app lock for Flutter. Biometrics with a PIN fallback, lockout
after wrong attempts, lock on background or after a timeout, and content
hidden in the app switcher, behind a polished lock screen.

![app_lock demo](https://raw.githubusercontent.com/Umar888/app_lock/main/doc/demo.gif)

## Why

Locking an app properly usually means stitching together `local_auth`, a
lock-screen package, an app-switcher privacy package and your own PIN
storage, then handling the edge cases yourself. app_lock does it in one
controller and one widget:

- **Biometrics with a PIN fallback.** Face ID, Touch ID and fingerprint
  through the official `local_auth`. The PIN always works when biometrics
  fail or aren't set up.
- **Lockout that survives restarts.** Wrong PINs escalate into timeouts
  (30 s, 1 min, 5 min, ...), and the count is stored, so killing the app
  doesn't reset it.
- **Lock when it matters.** On launch, as soon as the app is hidden, or
  after a grace period you choose. The Face ID prompt itself never triggers
  a lock.
- **App switcher privacy.** iOS covers the window with a blur. Android 13+
  hides the recents thumbnail while still allowing screenshots, and a strict
  mode blocks screenshots and screen recording too.
- **Secure storage.** The PIN is hashed with PBKDF2-HMAC-SHA256 on a
  background isolate and kept in an encrypted
  [secure_vault](https://pub.dev/packages/secure_vault), whose key lives in
  the Keychain / Keystore.
- **Hard to get around.** While locked, the app underneath can't be tapped,
  focused or read by screen readers, its animations pause, and Android's
  back button does nothing.
- **A lock screen worth showing.** It has a blurred backdrop and PIN dots
  that shake on a wrong entry. It prompts for biometrics on its own and
  counts down during a lockout. Every string can be translated, and you can
  replace the whole screen.

## Setup

```sh
flutter pub add app_lock
```

**iOS:** add a Face ID usage string to `ios/Runner/Info.plist`:

```xml
<key>NSFaceIDUsageDescription</key>
<string>Unlock the app with Face ID.</string>
```

**Android:** `local_auth` needs a `FragmentActivity`. In `MainActivity.kt`:

```kotlin
import io.flutter.embedding.android.FlutterFragmentActivity

class MainActivity : FlutterFragmentActivity()
```

## Usage

```dart
import 'package:app_lock/app_lock.dart';

final lock = AppLockController(lockAfter: const Duration(seconds: 30));

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await lock.init(); // before runApp: locked from the very first frame
  runApp(
    MaterialApp(
      builder: (context, child) => AppLock(controller: lock, child: child!),
      home: const HomePage(),
    ),
  );
}
```

Turn it on from your settings screen:

```dart
// PIN setup: create + confirm, 4 or 6 digits
await showPinSetup(context, lock);

// optional biometrics; shows the prompt once and only enables on success
final result = await lock.setBiometricsEnabled(true);

// turn the lock off again
await lock.disable();

// lock right away, e.g. from a "Lock now" button
lock.lock();
```

The lock is on once a PIN is set. `lock.isEnabled`, `lock.biometricsEnabled`,
`lock.biometricKind` and the rest are all observable, because the controller
is a `ChangeNotifier`.

## Options

```dart
AppLockController(
  lockAfter: Duration.zero,          // grace period in the background
  lockOnLaunch: true,                // start locked on a cold start
  privacyMode: PrivacyMode.hideInAppSwitcher, // or .none / .secure
  lockoutPolicy: const LockoutPolicy(
    freeAttempts: 5,
    lockouts: [Duration(seconds: 30), Duration(minutes: 1), Duration(minutes: 5)],
  ),
  biometricReason: 'Unlock to continue',
  store: VaultLockStore(),           // or your own LockStore
  biometrics: LocalAuthBiometrics(), // or your own BiometricAuthenticator
);
```

| Privacy mode | iOS | Android 13+ | Android 12 and older |
| --- | --- | --- | --- |
| `none` | live snapshot | live snapshot | live snapshot |
| `hideInAppSwitcher` (default) | blurred | blank thumbnail, screenshots allowed | `FLAG_SECURE` |
| `secure` | blurred | `FLAG_SECURE`: no screenshots or recording | `FLAG_SECURE` |

iOS doesn't let apps block screenshots, so `secure` behaves like
`hideInAppSwitcher` there.

### Custom lock screen

```dart
AppLock(
  controller: lock,
  lockScreenBuilder: (context, controller) => MyLockScreen(controller),
  child: child!,
)
```

Build it with `controller.unlockWithPin(pin)`, which returns a `PinResult`
with attempts left and any lockout. Also available are
`controller.unlockWithBiometrics()`, `controller.lockoutRemaining`, and the
`PinPad` and `PinDots` widgets this package uses.

### Translations

```dart
AppLock(
  controller: lock,
  labels: AppLockLabels(
    enterPin: 'PIN eingeben',
    wrongPin: (left) => 'Falsche PIN. Noch $left Versuche.',
    lockedOut: (time) => 'Zu viele Versuche. Warte ${time.inSeconds} s.',
  ),
  child: child!,
)
```

## Security notes

- The PIN is never stored, only a salted PBKDF2-HMAC-SHA256 hash, and that
  hash sits inside an AES-256-GCM encrypted vault whose key is held by the
  Keychain / Keystore.
- Lockouts use the device clock. Someone who can change the clock can
  shorten a lockout, but every wrong attempt still counts and lockouts keep
  escalating.
- app_lock protects the app's UI. It doesn't encrypt your own data; use
  [secure_vault](https://pub.dev/packages/secure_vault) for that.

## Example

`example/` is a small banking app. It shows PIN setup, biometrics, the lock
timeout, privacy modes and a "Lock now" button. It also contains an
integration test that drives the real lock screen.
