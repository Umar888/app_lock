import 'package:app_lock/app_lock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';

void main() {
  late MemoryLockStore store;
  late FakeBiometrics biometrics;
  late FakeClock clock;

  AppLockController make() => AppLockController(
    store: store,
    biometrics: biometrics,
    pinHashIterations: 10,
    clock: () => clock.now,
    privacyGuard: FakePrivacy(),
  );

  Future<AppLockController> lockedWithPin(String pin) async {
    final setup = make();
    await setup.init();
    await setup.setPin(pin);
    setup.dispose();
    final controller = make();
    await controller.init();
    return controller;
  }

  Widget app(AppLockController controller, {Widget? home}) => MaterialApp(
    builder: (context, child) => AppLock(controller: controller, child: child!),
    home:
        home ??
        Scaffold(
          body: Center(
            child: ElevatedButton(
              key: const ValueKey('secret_button'),
              onPressed: () {},
              child: const Text('Account balance'),
            ),
          ),
        ),
  );

  Future<void> typePin(WidgetTester tester, String pin) async {
    for (final digit in pin.split('')) {
      await tester.tap(find.byKey(ValueKey('app_lock_key_$digit')));
      await tester.pump();
    }
    // hashing and the shake delay
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
  }

  void phoneScreen(WidgetTester tester) {
    tester.view.physicalSize = const Size(1179, 2556);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
  }

  setUp(() {
    store = MemoryLockStore();
    biometrics = FakeBiometrics(kind: null);
    clock = FakeClock();
  });

  testWidgets('shows the app directly when the lock is off', (tester) async {
    phoneScreen(tester);
    final controller = make();
    addTearDown(controller.dispose);
    await tester.pumpWidget(app(controller));
    await tester.pumpAndSettle();
    expect(find.byType(LockScreen), findsNothing);
    expect(find.text('Account balance'), findsOneWidget);
  });

  testWidgets('the right PIN dismisses the lock screen', (tester) async {
    phoneScreen(tester);
    final controller = await lockedWithPin('1357');
    addTearDown(controller.dispose);
    await tester.pumpWidget(app(controller));
    await tester.pumpAndSettle();
    expect(find.byType(LockScreen), findsOneWidget);
    expect(find.text('Enter PIN'), findsOneWidget);

    await typePin(tester, '1357');
    expect(find.byType(LockScreen), findsNothing);
    expect(controller.isLocked, isFalse);
  });

  testWidgets('the app underneath is not tappable while locked', (
    tester,
  ) async {
    phoneScreen(tester);
    final controller = await lockedWithPin('1357');
    addTearDown(controller.dispose);
    await tester.pumpWidget(app(controller));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('secret_button')).hitTestable(),
      findsNothing,
    );
    await typePin(tester, '1357');
    expect(
      find.byKey(const ValueKey('secret_button')).hitTestable(),
      findsOneWidget,
    );
  });

  testWidgets('a wrong PIN shows the attempts left', (tester) async {
    phoneScreen(tester);
    final controller = await lockedWithPin('1357');
    addTearDown(controller.dispose);
    await tester.pumpWidget(app(controller));
    await tester.pumpAndSettle();
    await typePin(tester, '0000');
    expect(find.text('Wrong PIN. 4 attempts left.'), findsOneWidget);
    expect(find.byType(LockScreen), findsOneWidget);
  });

  testWidgets('five wrong PINs show a countdown and disable the pad', (
    tester,
  ) async {
    phoneScreen(tester);
    final controller = await lockedWithPin('1357');
    addTearDown(controller.dispose);
    await tester.pumpWidget(app(controller));
    await tester.pumpAndSettle();
    for (var i = 0; i < 5; i++) {
      await typePin(tester, '0000');
    }
    expect(find.text('Too many attempts. Try again in 0:30'), findsOneWidget);

    // taps do nothing while locked out
    await tester.tap(find.byKey(const ValueKey('app_lock_key_1')));
    await tester.pump();
    expect(controller.failedAttempts, 5);

    clock.advance(const Duration(seconds: 31));
    await tester.pump(const Duration(milliseconds: 300));
    // let the message cross-fade finish
    await tester.pumpAndSettle();
    expect(find.textContaining('Too many attempts'), findsNothing);
    await typePin(tester, '1357');
    expect(controller.isLocked, isFalse);
  });

  testWidgets('prompts for biometrics on its own when enabled', (tester) async {
    phoneScreen(tester);
    biometrics.kind = BiometricKind.fingerprint;
    final setup = make();
    await setup.init();
    await setup.setPin('1357');
    await setup.setBiometricsEnabled(true);
    setup.dispose();
    final controller = make();
    addTearDown(controller.dispose);
    await controller.init();
    biometrics.prompts = 0;

    await tester.pumpWidget(app(controller));
    await tester.pumpAndSettle();
    expect(biometrics.prompts, 1);
    expect(controller.isLocked, isFalse);
  });

  testWidgets('the biometric button retries after a cancel', (tester) async {
    phoneScreen(tester);
    biometrics.kind = BiometricKind.face;
    final setup = make();
    await setup.init();
    await setup.setPin('1357');
    await setup.setBiometricsEnabled(true);
    setup.dispose();
    final controller = make();
    addTearDown(controller.dispose);
    await controller.init();

    biometrics.next = BiometricResult.cancelled;
    await tester.pumpWidget(app(controller));
    await tester.pumpAndSettle();
    expect(controller.isLocked, isTrue);

    biometrics.next = BiometricResult.success;
    await tester.tap(find.byKey(const ValueKey('app_lock_biometric')));
    await tester.pumpAndSettle();
    expect(controller.isLocked, isFalse);
  });

  testWidgets('locks again when the app goes to the background', (
    tester,
  ) async {
    phoneScreen(tester);
    final controller = await lockedWithPin('1357');
    addTearDown(controller.dispose);
    await tester.pumpWidget(app(controller));
    await tester.pumpAndSettle();
    await typePin(tester, '1357');
    expect(find.byType(LockScreen), findsNothing);

    await goBackground(tester);
    await goForeground(tester);
    await tester.pumpAndSettle();
    expect(find.byType(LockScreen), findsOneWidget);
  });

  group('PIN setup', () {
    Future<void> openSetup(
      WidgetTester tester,
      AppLockController controller,
      List<bool?> result,
    ) async {
      await tester.pumpWidget(
        app(
          controller,
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () async =>
                  result.add(await showPinSetup(context, controller)),
              child: const Text('Set up'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Set up'));
      await tester.pumpAndSettle();
    }

    testWidgets('creates a PIN after a matching confirmation', (tester) async {
      phoneScreen(tester);
      final controller = make();
      addTearDown(controller.dispose);
      final result = <bool?>[];
      await openSetup(tester, controller, result);

      expect(find.text('Create a PIN'), findsOneWidget);
      await tester.tap(find.text('4 digits'));
      await tester.pumpAndSettle();
      await typePin(tester, '9876');
      expect(find.text('Confirm your PIN'), findsOneWidget);
      await typePin(tester, '9876');

      expect(result, [true]);
      expect(controller.hasPin, isTrue);
      expect(controller.pinLength, 4);
      expect((await controller.verifyPin('9876')).isSuccess, isTrue);
    });

    testWidgets('starts over when the confirmation differs', (tester) async {
      phoneScreen(tester);
      final controller = make();
      addTearDown(controller.dispose);
      final result = <bool?>[];
      await openSetup(tester, controller, result);

      await typePin(tester, '111111');
      await typePin(tester, '222222');
      expect(find.text("PINs didn't match. Try again."), findsOneWidget);
      expect(find.text('Create a PIN'), findsOneWidget);
      expect(controller.hasPin, isFalse);

      await tester.tap(find.byKey(const ValueKey('app_lock_setup_cancel')));
      await tester.pumpAndSettle();
      expect(result, [false]);
    });
  });
}
