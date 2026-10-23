import 'package:app_lock/app_lock.dart';
import 'package:flutter/material.dart';
import 'package:rolling_digits/rolling_digits.dart';

final lock = AppLockController(biometricReason: 'Unlock Vault Bank');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // before runApp, so a locked app is locked on its very first frame
  await lock.init();

  // flutter run --dart-define=DEMO=locked (or secure) starts with PIN 1357
  // already set, handy for screenshots and checking the privacy flags
  const demo = String.fromEnvironment('DEMO');
  if (demo.isNotEmpty) {
    if (!lock.hasPin) await lock.setPin('1357');
    if (demo == 'secure') lock.privacyMode = PrivacyMode.secure;
    lock.lock();
  }
  runApp(const BankApp());
}

class BankApp extends StatelessWidget {
  const BankApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'app_lock demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: const Color(0xFF5B3DF5)),
      darkTheme: ThemeData(
        colorSchemeSeed: const Color(0xFF5B3DF5),
        brightness: Brightness.dark,
      ),
      builder: (context, child) => AppLock(controller: lock, child: child!),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const _BalanceCard(),
            const SizedBox(height: 24),
            Text('Security', style: text.titleMedium),
            const SizedBox(height: 8),
            const _LockSettings(),
            const SizedBox(height: 24),
            Text('Recent activity', style: text.titleMedium),
            const SizedBox(height: 8),
            const _Activity(),
          ],
        ),
      ),
    );
  }
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 28),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF3A2BD8), Color(0xFF5B3DF5), Color(0xFF9B5CF6)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.shield_rounded, color: Colors.white),
              const SizedBox(width: 8),
              Text(
                'VAULT BANK',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.6,
                ),
              ),
              const Spacer(),
              ListenableBuilder(
                listenable: lock,
                builder: (context, _) => Icon(
                  lock.isEnabled ? Icons.lock_rounded : Icons.lock_open_rounded,
                  color: Colors.white70,
                  size: 20,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            'Available balance',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.75)),
          ),
          const SizedBox(height: 4),
          const FittedBox(
            fit: BoxFit.scaleDown,
            child: RollingDigits(
              value: 48213.57,
              fractionDigits: 2,
              groupSeparator: ',',
              prefix: r'$',
              animateOnFirstBuild: true,
              blur: 2,
              style: TextStyle(
                color: Colors.white,
                fontSize: 44,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LockSettings extends StatelessWidget {
  const _LockSettings();

  Future<void> _toggleLock(BuildContext context, bool on) async {
    if (on) {
      await showPinSetup(context, lock);
    } else {
      await lock.disable();
    }
  }

  Future<void> _toggleBiometrics(BuildContext context, bool on) async {
    final result = await lock.setBiometricsEnabled(on);
    if (!context.mounted || result == BiometricResult.success) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Biometrics not enabled: ${result.name}')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: lock,
      builder: (context, _) {
        final kind = lock.biometricKind;
        return Card(
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              SwitchListTile(
                key: const ValueKey('toggle_lock'),
                secondary: const Icon(Icons.pin_rounded),
                title: const Text('App lock'),
                subtitle: Text(
                  lock.isEnabled
                      ? '${lock.pinLength}-digit PIN'
                      : 'Require a PIN to open the app',
                ),
                value: lock.isEnabled,
                onChanged: (on) => _toggleLock(context, on),
              ),
              SwitchListTile(
                key: const ValueKey('toggle_biometrics'),
                secondary: Icon(
                  kind == null ? Icons.fingerprint : biometricIcon(kind),
                ),
                title: Text(switch (kind) {
                  BiometricKind.face => 'Unlock with Face ID',
                  BiometricKind.fingerprint => 'Unlock with fingerprint',
                  _ => 'Unlock with biometrics',
                }),
                subtitle: Text(
                  kind == null
                      ? 'Not available on this device'
                      : 'PIN still works as a fallback',
                ),
                value: lock.biometricsEnabled,
                onChanged: lock.isEnabled && kind != null
                    ? (on) => _toggleBiometrics(context, on)
                    : null,
              ),
              ListTile(
                leading: const Icon(Icons.timer_outlined),
                title: const Text('Lock after'),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Wrap(
                    spacing: 6,
                    children: [
                      for (final (label, duration) in const [
                        ('Immediately', Duration.zero),
                        ('30 s', Duration(seconds: 30)),
                        ('1 min', Duration(minutes: 1)),
                        ('5 min', Duration(minutes: 5)),
                      ])
                        ChoiceChip(
                          label: Text(label),
                          selected: lock.lockAfter == duration,
                          onSelected: lock.isEnabled
                              ? (_) => lock.lockAfter = duration
                              : null,
                        ),
                    ],
                  ),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.visibility_off_outlined),
                title: const Text('App switcher privacy'),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: SegmentedButton<PrivacyMode>(
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(
                        value: PrivacyMode.none,
                        label: Text('Off'),
                      ),
                      ButtonSegment(
                        value: PrivacyMode.hideInAppSwitcher,
                        label: Text('Hide'),
                      ),
                      ButtonSegment(
                        value: PrivacyMode.secure,
                        label: Text('Secure'),
                      ),
                    ],
                    selected: {lock.privacyMode},
                    onSelectionChanged: (value) =>
                        lock.privacyMode = value.first,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    key: const ValueKey('lock_now'),
                    onPressed: lock.isEnabled ? lock.lock : null,
                    icon: const Icon(Icons.lock_rounded),
                    label: const Text('Lock now'),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Activity extends StatelessWidget {
  const _Activity();

  static const _items = [
    ('Coffee Lab', 'Food & drink', -4.80),
    ('Salary', 'Income', 3250.00),
    ('Metro card', 'Transport', -25.00),
    ('Bookstore', 'Shopping', -18.40),
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Column(
        children: [
          for (final (name, category, amount) in _items)
            ListTile(
              leading: CircleAvatar(
                backgroundColor: scheme.primaryContainer,
                child: Icon(
                  amount > 0 ? Icons.south_west : Icons.north_east,
                  color: scheme.onPrimaryContainer,
                  size: 18,
                ),
              ),
              title: Text(name),
              subtitle: Text(category),
              trailing: Text(
                '${amount > 0 ? '+' : '-'}\$${amount.abs().toStringAsFixed(2)}',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: amount > 0 ? Colors.green.shade600 : null,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
