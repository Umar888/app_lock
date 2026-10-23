import 'package:app_lock/app_lock.dart';
import 'package:app_lock_example/main.dart' as app;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

// drives the real UI against the real Keychain / Keystore backed store.
// --dart-define=SLOW=true paces it for screen recordings
const _slow = bool.fromEnvironment('SLOW');

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<void> beat(WidgetTester tester, [int ms = 120]) async {
    await tester.pump(Duration(milliseconds: _slow ? ms * 4 : ms));
  }

  // PIN hashing runs on a background isolate, so wait for the state rather
  // than for idle frames
  Future<void> pumpUntil(WidgetTester tester, bool Function() done) async {
    for (var i = 0; i < 200 && !done(); i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.pumpAndSettle();
    expect(done(), isTrue);
  }

  Future<void> typePin(WidgetTester tester, String pin) async {
    for (final digit in pin.split('')) {
      await tester.tap(find.byKey(ValueKey('app_lock_key_$digit')));
      await beat(tester);
    }
    await tester.pumpAndSettle();
  }

  testWidgets('set up a PIN, lock, fail once, unlock, relock on background', (
    tester,
  ) async {
    await app.main();
    await app.lock.disable();
    await tester.pumpAndSettle();
    await beat(tester, 400);

    // turn the lock on through the setup flow
    await tester.tap(find.byKey(const ValueKey('toggle_lock')));
    await tester.pumpAndSettle();
    expect(find.text('Create a PIN'), findsOneWidget);
    await tester.tap(find.text('4 digits'));
    await tester.pumpAndSettle();
    await typePin(tester, '1357');
    await typePin(tester, '1357');
    await pumpUntil(tester, () => app.lock.isEnabled);
    expect(find.text('4-digit PIN'), findsOneWidget);
    await beat(tester, 400);

    // lock now, then a wrong PIN
    await tester.tap(find.byKey(const ValueKey('lock_now')));
    await tester.pumpAndSettle();
    expect(find.byType(LockScreen), findsOneWidget);
    await beat(tester, 400);
    await typePin(tester, '2468');
    await pumpUntil(
      tester,
      () => find.text('Wrong PIN. 4 attempts left.').evaluate().isNotEmpty,
    );
    await beat(tester, 400);

    // the right one
    await typePin(tester, '1357');
    await pumpUntil(tester, () => !app.lock.isLocked);
    expect(find.byType(LockScreen), findsNothing);
    await beat(tester, 400);

    // backgrounding locks again (lockAfter defaults to immediately)
    for (final state in [
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
      AppLifecycleState.hidden,
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ]) {
      tester.binding.handleAppLifecycleStateChanged(state);
    }
    await tester.pumpAndSettle();
    expect(find.byType(LockScreen), findsOneWidget);
    await typePin(tester, '1357');
    await pumpUntil(tester, () => !app.lock.isLocked);

    await app.lock.disable();
    await tester.pumpAndSettle();
  });
}
