import 'dart:async';

import 'package:app_lock/app_lock.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';

void main() {
  late MemoryLockStore store;
  late FakeBiometrics biometrics;
  late FakePrivacy privacy;
  late FakeClock clock;

  AppLockController make({
    Duration lockAfter = Duration.zero,
    bool lockOnLaunch = true,
  }) => AppLockController(
    store: store,
    biometrics: biometrics,
    lockAfter: lockAfter,
    lockOnLaunch: lockOnLaunch,
    pinHashIterations: 10,
    clock: () => clock.now,
    privacyGuard: privacy,
  );

  Future<AppLockController> withPin(
    WidgetTester tester, {
    Duration lockAfter = Duration.zero,
  }) async {
    final setup = make();
    await setup.init();
    await setup.setPin('2468');
    setup.dispose();
    final controller = make(lockAfter: lockAfter);
    addTearDown(controller.dispose);
    await controller.init();
    return controller;
  }

  setUp(() {
    store = MemoryLockStore();
    biometrics = FakeBiometrics();
    privacy = FakePrivacy();
    clock = FakeClock();
  });

  testWidgets('starts unlocked and off without a PIN', (tester) async {
    final controller = make();
    addTearDown(controller.dispose);
    await controller.init();
    expect(controller.isReady, isTrue);
    expect(controller.isEnabled, isFalse);
    expect(controller.isLocked, isFalse);
    expect(privacy.modes.last, PrivacyMode.none);
    controller.lock();
    expect(controller.isLocked, isFalse);
  });

  testWidgets('setting a PIN turns the lock and privacy on', (tester) async {
    final controller = make();
    addTearDown(controller.dispose);
    await controller.init();
    await controller.setPin('1234');
    expect(controller.isEnabled, isTrue);
    expect(controller.pinLength, 4);
    expect(controller.isLocked, isFalse);
    expect(privacy.modes.last, PrivacyMode.hideInAppSwitcher);
    expect(() => controller.setPin('12'), throwsArgumentError);
    expect(() => controller.setPin('12ab'), throwsArgumentError);
  });

  testWidgets('a cold start with a PIN is locked', (tester) async {
    final controller = await withPin(tester);
    expect(controller.isLocked, isTrue);
  });

  testWidgets('lockOnLaunch false starts unlocked', (tester) async {
    final setup = make();
    await setup.init();
    await setup.setPin('2468');
    setup.dispose();
    final controller = make(lockOnLaunch: false);
    addTearDown(controller.dispose);
    await controller.init();
    expect(controller.isLocked, isFalse);
  });

  testWidgets('the right PIN unlocks, the wrong one does not', (tester) async {
    final controller = await withPin(tester);
    final wrong = await controller.unlockWithPin('0000');
    expect(wrong.status, PinStatus.wrong);
    expect(wrong.attemptsRemaining, 4);
    expect(controller.isLocked, isTrue);

    final right = await controller.unlockWithPin('2468');
    expect(right.isSuccess, isTrue);
    expect(controller.isLocked, isFalse);
    expect(controller.failedAttempts, 0);
  });

  testWidgets('wrong PINs escalate into lockouts that survive restarts', (
    tester,
  ) async {
    var controller = await withPin(tester);
    for (var i = 0; i < 4; i++) {
      expect((await controller.unlockWithPin('0000')).status, PinStatus.wrong);
    }
    final fifth = await controller.unlockWithPin('0000');
    expect(fifth.status, PinStatus.lockedOut);
    expect(fifth.lockedOutFor, const Duration(seconds: 30));

    // even the right PIN is refused during a lockout
    final blocked = await controller.unlockWithPin('2468');
    expect(blocked.status, PinStatus.lockedOut);
    expect(controller.isLocked, isTrue);

    // a restart keeps the count (the first instance is disposed by its
    // teardown)
    controller = make();
    addTearDown(controller.dispose);
    await controller.init();
    expect(controller.lockoutRemaining, const Duration(seconds: 30));

    clock.advance(const Duration(seconds: 31));
    expect(controller.lockoutRemaining, isNull);
    final sixth = await controller.unlockWithPin('1111');
    expect(sixth.lockedOutFor, const Duration(minutes: 1));

    clock.advance(const Duration(minutes: 2));
    expect((await controller.unlockWithPin('2468')).isSuccess, isTrue);
    expect(controller.failedAttempts, 0);
  });

  testWidgets('verifyPin checks without unlocking', (tester) async {
    final controller = await withPin(tester);
    expect((await controller.verifyPin('2468')).isSuccess, isTrue);
    expect(controller.isLocked, isTrue);
    expect((await controller.verifyPin('0000')).status, PinStatus.wrong);
    expect(controller.failedAttempts, 1);
  });

  group('biometrics', () {
    testWidgets('enabling requires a successful prompt', (tester) async {
      final controller = make();
      addTearDown(controller.dispose);
      await controller.init();
      expect(() => controller.setBiometricsEnabled(true), throwsStateError);
      await controller.setPin('2468');

      biometrics.next = BiometricResult.cancelled;
      expect(
        await controller.setBiometricsEnabled(true),
        BiometricResult.cancelled,
      );
      expect(controller.biometricsEnabled, isFalse);

      biometrics.next = BiometricResult.success;
      expect(
        await controller.setBiometricsEnabled(true),
        BiometricResult.success,
      );
      expect(controller.biometricsEnabled, isTrue);
      expect(privacy.suspensions, [true, false, true, false]);
    });

    testWidgets('unlock works and clears a PIN lockout', (tester) async {
      final controller = await withPin(tester);
      biometrics.next = BiometricResult.success;
      await controller.setBiometricsEnabled(true);
      for (var i = 0; i < 5; i++) {
        await controller.unlockWithPin('0000');
      }
      expect(controller.lockoutRemaining, isNotNull);

      biometrics.next = BiometricResult.failed;
      expect(await controller.unlockWithBiometrics(), BiometricResult.failed);
      expect(controller.isLocked, isTrue);

      biometrics.next = BiometricResult.success;
      expect(await controller.unlockWithBiometrics(), BiometricResult.success);
      expect(controller.isLocked, isFalse);
      expect(controller.lockoutRemaining, isNull);
    });

    testWidgets('unavailable when not enabled or not supported', (
      tester,
    ) async {
      final controller = await withPin(tester);
      expect(
        await controller.unlockWithBiometrics(),
        BiometricResult.unavailable,
      );
      biometrics.kind = null;
      await controller.refreshBiometrics();
      expect(
        await controller.setBiometricsEnabled(true),
        BiometricResult.unavailable,
      );
      expect(biometrics.prompts, 0);
    });
  });

  group('lifecycle', () {
    testWidgets('locks as soon as the app is hidden by default', (
      tester,
    ) async {
      final controller = await withPin(tester);
      await controller.unlockWithPin('2468');
      await goBackground(tester);
      expect(controller.isLocked, isTrue);
    });

    testWidgets('lockAfter allows a short trip away', (tester) async {
      final controller = await withPin(
        tester,
        lockAfter: const Duration(seconds: 30),
      );
      await controller.unlockWithPin('2468');

      await goBackground(tester);
      expect(controller.isLocked, isFalse);
      clock.advance(const Duration(seconds: 10));
      await goForeground(tester);
      expect(controller.isLocked, isFalse);

      await goBackground(tester);
      clock.advance(const Duration(seconds: 31));
      await goForeground(tester);
      expect(controller.isLocked, isTrue);
    });

    testWidgets('the biometric prompt never triggers a lock', (tester) async {
      final controller = await withPin(tester);
      biometrics.next = BiometricResult.success;
      await controller.setBiometricsEnabled(true);
      await controller.unlockWithPin('2468');
      controller.lock();

      final prompt = biometrics.pending = Completer<BiometricResult>();
      final result = controller.unlockWithBiometrics();
      await tester.pump();
      // leaving while the prompt is up must not arm the background timer
      await goBackground(tester);
      await goForeground(tester);
      prompt.complete(BiometricResult.success);
      expect(await result, BiometricResult.success);
      expect(controller.isLocked, isFalse);
    });

    testWidgets('back is swallowed only while locked', (tester) async {
      final controller = await withPin(tester);
      expect(await controller.didPopRoute(), isTrue);
      await controller.unlockWithPin('2468');
      expect(await controller.didPopRoute(), isFalse);
    });

    testWidgets('disable removes the PIN and unlocks', (tester) async {
      final controller = await withPin(tester);
      await controller.disable();
      expect(controller.isEnabled, isFalse);
      expect(controller.isLocked, isFalse);
      expect(privacy.modes.last, PrivacyMode.none);
      expect(store.record.pin, isNull);
    });
  });
}
