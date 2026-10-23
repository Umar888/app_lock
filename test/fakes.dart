import 'dart:async';

import 'package:app_lock/app_lock.dart';
import 'package:app_lock/src/privacy_guard.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeBiometrics implements BiometricAuthenticator {
  FakeBiometrics({this.kind = BiometricKind.face});

  BiometricKind? kind;
  BiometricResult next = BiometricResult.success;
  Completer<BiometricResult>? pending;
  int prompts = 0;

  @override
  Future<BiometricKind?> availableKind() async => kind;

  @override
  Future<BiometricResult> authenticate(String reason) {
    prompts++;
    return pending?.future ?? Future.value(next);
  }
}

class FakePrivacy extends PrivacyGuard {
  final modes = <PrivacyMode>[];
  final suspensions = <bool>[];

  @override
  Future<void> setMode(PrivacyMode mode) async => modes.add(mode);

  @override
  Future<void> setSuspended(bool suspended) async => suspensions.add(suspended);
}

class FakeClock {
  DateTime now = DateTime(2026, 1, 1, 12);

  void advance(Duration by) => now = now.add(by);
}

/// Walks the app lifecycle through valid transitions, as the engine does.
Future<void> goBackground(WidgetTester tester) async {
  for (final state in [
    AppLifecycleState.inactive,
    AppLifecycleState.hidden,
    AppLifecycleState.paused,
  ]) {
    tester.binding.handleAppLifecycleStateChanged(state);
  }
  await tester.pump();
}

Future<void> goForeground(WidgetTester tester) async {
  for (final state in [
    AppLifecycleState.hidden,
    AppLifecycleState.inactive,
    AppLifecycleState.resumed,
  ]) {
    tester.binding.handleAppLifecycleStateChanged(state);
  }
  await tester.pump();
}
