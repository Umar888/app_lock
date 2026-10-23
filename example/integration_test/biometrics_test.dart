import 'package:app_lock/app_lock.dart';
import 'package:app_lock_example/main.dart' as app;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

// Runs against the real platform biometric stack. It prints a BIO_WAIT
// marker whenever the system prompt should be up, and a host script answers
// by sending match / no-match to the simulator or emulator sensor.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpUntil(
    WidgetTester tester,
    bool Function() done, {
    Duration timeout = const Duration(seconds: 30),
  }) async {
    final end = DateTime.now().add(timeout);
    while (!done() && DateTime.now().isBefore(end)) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.pumpAndSettle();
    expect(done(), isTrue);
  }

  void marker(String step) => debugPrint('BIO_WAIT:$step');

  testWidgets('real biometrics: enable, fail then match, leave and return', (
    tester,
  ) async {
    await app.main();
    final lock = app.lock;
    await lock.disable();
    await lock.setPin('1357');
    await lock.refreshBiometrics();
    await tester.pumpAndSettle();
    debugPrint('BIO_INFO:kind=${lock.biometricKind}');
    expect(lock.biometricKind, isNotNull);

    // 1. enabling shows the prompt once; the host answers with a match
    marker('enable_match');
    final enabled = await lock.setBiometricsEnabled(true);
    debugPrint('BIO_INFO:enable=$enabled');
    expect(enabled, BiometricResult.success);
    expect(lock.biometricsEnabled, isTrue);

    // 2. the lock screen prompts on its own; host sends a no-match, then a
    // match on the retry
    lock.lock();
    await tester.pump();
    marker('unlock_nomatch_then_match');
    await pumpUntil(tester, () => !lock.isLocked);
    debugPrint('BIO_INFO:unlocked_with_biometrics');

    // 3. the user leaves while the prompt is up. iOS cancels it, and coming
    // back must show a fresh prompt instead of a dead lock screen
    lock.lock();
    await tester.pump();
    marker('leave_during_prompt');
    await pumpUntil(
      tester,
      () => !lock.isLocked,
      timeout: const Duration(seconds: 60),
    );
    debugPrint('BIO_INFO:unlocked_after_returning');

    await lock.disable();
    await tester.pumpAndSettle();
  });
}
