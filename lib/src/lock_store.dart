import 'package:secure_vault/secure_vault.dart';

import 'pin_hasher.dart';

/// Everything app_lock persists between launches.
class LockRecord {
  /// Creates a record.
  const LockRecord({
    this.pin,
    this.pinLength = 0,
    this.biometricsEnabled = false,
    this.failedAttempts = 0,
    this.lockedUntil,
  });

  /// The hashed PIN, or `null` when the lock is off.
  final PinHash? pin;

  /// Number of digits in the PIN.
  final int pinLength;

  /// Whether the user opted in to biometric unlock.
  final bool biometricsEnabled;

  /// Wrong PINs in a row since the last successful unlock.
  final int failedAttempts;

  /// PIN entry is blocked until this time.
  final DateTime? lockedUntil;

  /// An empty record: lock off.
  static const empty = LockRecord();

  /// Returns a copy with the given fields replaced. Pass `clearLockout` to
  /// remove [lockedUntil].
  LockRecord copyWith({
    PinHash? pin,
    int? pinLength,
    bool? biometricsEnabled,
    int? failedAttempts,
    DateTime? lockedUntil,
    bool clearLockout = false,
  }) => LockRecord(
    pin: pin ?? this.pin,
    pinLength: pinLength ?? this.pinLength,
    biometricsEnabled: biometricsEnabled ?? this.biometricsEnabled,
    failedAttempts: failedAttempts ?? this.failedAttempts,
    lockedUntil: clearLockout ? null : (lockedUntil ?? this.lockedUntil),
  );

  /// Encodes the record as JSON-compatible values.
  Map<String, Object?> toJson() => {
    if (pin != null) ...{
      'pinHash': pin!.hash,
      'pinSalt': pin!.salt,
      'pinIterations': pin!.iterations,
    },
    'pinLength': pinLength,
    'biometrics': biometricsEnabled,
    'failed': failedAttempts,
    if (lockedUntil != null) 'lockedUntil': lockedUntil!.millisecondsSinceEpoch,
  };

  /// Decodes a record written by [toJson].
  factory LockRecord.fromJson(Map<String, dynamic> json) {
    final hash = json['pinHash'] as String?;
    final lockedUntil = json['lockedUntil'] as int?;
    return LockRecord(
      pin: hash == null
          ? null
          : PinHash(
              hash: hash,
              salt: json['pinSalt'] as String,
              iterations: json['pinIterations'] as int,
            ),
      pinLength: json['pinLength'] as int? ?? 0,
      biometricsEnabled: json['biometrics'] as bool? ?? false,
      failedAttempts: json['failed'] as int? ?? 0,
      lockedUntil: lockedUntil == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(lockedUntil),
    );
  }
}

/// Where app_lock keeps its [LockRecord].
abstract interface class LockStore {
  /// Loads the saved record, or [LockRecord.empty] if none.
  Future<LockRecord> load();

  /// Saves [record], replacing the previous one.
  Future<void> save(LockRecord record);
}

/// The default [LockStore]: an encrypted `secure_vault` whose key lives in the
/// Keychain / Keystore.
class VaultLockStore implements LockStore {
  /// Creates a store backed by the vault called [vaultName].
  VaultLockStore({this.vaultName = 'app_lock'});

  /// Name of the vault file.
  final String vaultName;

  static const _key = 'state';
  Future<SecureVault>? _vault;

  Future<SecureVault> get _open => _vault ??= SecureVault.open(vaultName);

  @override
  Future<LockRecord> load() async {
    final json = (await _open).getMap(_key);
    return json == null ? LockRecord.empty : LockRecord.fromJson(json);
  }

  @override
  Future<void> save(LockRecord record) async =>
      (await _open).setMap(_key, record.toJson());
}

/// A [LockStore] that only lives in memory. Useful for tests.
class MemoryLockStore implements LockStore {
  /// Creates a store, optionally starting from [record].
  MemoryLockStore([this.record = LockRecord.empty]);

  /// The current record.
  LockRecord record;

  @override
  Future<LockRecord> load() async => record;

  @override
  Future<void> save(LockRecord record) async => this.record = record;
}
