/// How wrong PIN attempts are throttled.
///
/// The first [freeAttempts] wrong PINs only show an error. Every wrong PIN
/// after that blocks entry for the next duration in [lockouts], and the last
/// duration repeats. A correct PIN or biometric unlock resets the count.
///
/// The count survives app restarts, so killing the app does not reset it.
class LockoutPolicy {
  /// Creates a policy.
  const LockoutPolicy({
    this.freeAttempts = 5,
    this.lockouts = const [
      Duration(seconds: 30),
      Duration(minutes: 1),
      Duration(minutes: 5),
      Duration(minutes: 15),
      Duration(hours: 1),
    ],
  }) : assert(freeAttempts > 0);

  /// Wrong PINs allowed before the first lockout.
  final int freeAttempts;

  /// Lockout lengths for each wrong PIN past [freeAttempts]. The last one
  /// repeats. Empty means wrong PINs never lock.
  final List<Duration> lockouts;

  /// The lockout to apply after [failedAttempts] wrong PINs in a row, or
  /// `null` if none.
  Duration? lockoutAfter(int failedAttempts) {
    if (failedAttempts < freeAttempts || lockouts.isEmpty) return null;
    final index = failedAttempts - freeAttempts;
    return lockouts[index < lockouts.length ? index : lockouts.length - 1];
  }

  /// Wrong PINs left before the next lockout kicks in.
  int attemptsBeforeLockout(int failedAttempts) =>
      failedAttempts < freeAttempts ? freeAttempts - failedAttempts : 1;
}
