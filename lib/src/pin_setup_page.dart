import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_lock_controller.dart';
import 'app_lock_labels.dart';
import 'pin_dots.dart';
import 'pin_pad.dart';

/// Opens the PIN setup flow (create, then confirm) and saves the new PIN on
/// [controller]. Returns `true` if a PIN was set, `false` if cancelled.
Future<bool> showPinSetup(
  BuildContext context,
  AppLockController controller, {
  AppLockLabels labels = const AppLockLabels(),
  int pinLength = 6,
  bool allowLengthChoice = true,
}) async {
  final pin = await Navigator.of(context).push<String>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => PinSetupPage(
        labels: labels,
        pinLength: pinLength,
        allowLengthChoice: allowLengthChoice,
      ),
    ),
  );
  if (pin == null) return false;
  await controller.setPin(pin);
  return true;
}

/// A two-step page to create a PIN: enter it, then confirm it. Pops with the
/// PIN as a `String`, or `null` if cancelled.
class PinSetupPage extends StatefulWidget {
  /// Creates the page.
  const PinSetupPage({
    super.key,
    this.labels = const AppLockLabels(),
    this.pinLength = 6,
    this.allowLengthChoice = true,
  }) : assert(pinLength >= 4 && pinLength <= 8);

  /// Strings shown on screen.
  final AppLockLabels labels;

  /// Starting PIN length.
  final int pinLength;

  /// Lets the user switch between 4 and 6 digits before entering the PIN.
  final bool allowLengthChoice;

  @override
  State<PinSetupPage> createState() => _PinSetupPageState();
}

class _PinSetupPageState extends State<PinSetupPage> {
  final _dots = GlobalKey<PinDotsState>();
  late int _length = widget.pinLength;
  String _first = '';
  String _entered = '';
  bool _confirming = false;
  bool _mismatch = false;

  Future<void> _onDigit(String digit) async {
    if (_entered.length >= _length) return;
    setState(() {
      _entered += digit;
      _mismatch = false;
    });
    if (_entered.length < _length) return;

    // let the last dot fill in before moving on
    await Future<void>.delayed(const Duration(milliseconds: 150));
    if (!mounted) return;
    if (!_confirming) {
      setState(() {
        _first = _entered;
        _entered = '';
        _confirming = true;
      });
      return;
    }
    if (_entered == _first) {
      Navigator.of(context).pop(_entered);
      return;
    }
    HapticFeedback.heavyImpact();
    _dots.currentState?.shake();
    await Future<void>.delayed(const Duration(milliseconds: 350));
    if (!mounted) return;
    setState(() {
      _mismatch = true;
      _confirming = false;
      _first = '';
      _entered = '';
    });
  }

  void _onDelete() {
    if (_entered.isEmpty) return;
    setState(() => _entered = _entered.substring(0, _entered.length - 1));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final labels = widget.labels;
    final subtitle = _mismatch
        ? labels.pinMismatch
        : (_confirming ? labels.confirmPinSubtitle : labels.createPinSubtitle);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          key: const ValueKey('app_lock_setup_cancel'),
          tooltip: labels.cancel,
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              children: [
                const SizedBox(height: 12),
                Text(
                  _confirming ? labels.confirmPin : labels.createPin,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: _mismatch
                        ? theme.colorScheme.error
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 28),
                PinDots(
                  key: _dots,
                  length: _length,
                  filled: _entered.length,
                  error: _mismatch,
                ),
                if (widget.allowLengthChoice && !_confirming) ...[
                  const SizedBox(height: 20),
                  SegmentedButton<int>(
                    key: const ValueKey('app_lock_setup_length'),
                    showSelectedIcon: false,
                    segments: [
                      for (final digits in const [4, 6])
                        ButtonSegment(
                          value: digits,
                          label: Text(labels.pinLengthOption(digits)),
                        ),
                    ],
                    selected: {_length},
                    onSelectionChanged: (value) => setState(() {
                      _length = value.first;
                      _entered = '';
                    }),
                  ),
                ],
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(32, 24, 32, 24),
              child: PinPad(
                onDigit: _onDigit,
                onDelete: _onDelete,
                deleteLabel: labels.delete,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
