import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A 3x4 number pad. The bottom-left slot holds [leading], typically a
/// biometric button, and the bottom-right slot a delete key.
class PinPad extends StatelessWidget {
  /// Creates the pad.
  const PinPad({
    super.key,
    required this.onDigit,
    required this.onDelete,
    this.leading,
    this.enabled = true,
    this.deleteLabel = 'Delete',
  });

  /// Called with each digit tapped.
  final ValueChanged<String> onDigit;

  /// Called when delete is tapped.
  final VoidCallback onDelete;

  /// Widget for the bottom-left slot.
  final Widget? leading;

  /// Whether keys respond to taps.
  final bool enabled;

  /// Semantics label for the delete key.
  final String deleteLabel;

  @override
  Widget build(BuildContext context) {
    Widget digit(String d) => _Key(
      key: ValueKey('app_lock_key_$d'),
      enabled: enabled,
      onTap: () => onDigit(d),
      child: Text(
        d,
        style: Theme.of(
          context,
        ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w500),
      ),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final row in const [
          ['1', '2', '3'],
          ['4', '5', '6'],
          ['7', '8', '9'],
        ])
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [for (final d in row) digit(d)],
          ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            SizedBox.square(dimension: _Key.size, child: leading),
            digit('0'),
            _Key(
              key: const ValueKey('app_lock_delete'),
              enabled: enabled,
              filled: false,
              onTap: onDelete,
              semanticLabel: deleteLabel,
              child: const Icon(Icons.backspace_outlined, size: 26),
            ),
          ],
        ),
      ],
    );
  }
}

class _Key extends StatelessWidget {
  const _Key({
    super.key,
    required this.child,
    required this.onTap,
    required this.enabled,
    this.filled = true,
    this.semanticLabel,
  });

  static const size = 78.0;

  final Widget child;
  final VoidCallback onTap;
  final bool enabled;
  final bool filled;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Semantics(
        button: true,
        label: semanticLabel,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 200),
          opacity: enabled ? 1 : 0.35,
          child: Material(
            color: filled
                ? scheme.onSurface.withValues(alpha: 0.07)
                : Colors.transparent,
            shape: const CircleBorder(),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: enabled
                  ? () {
                      HapticFeedback.selectionClick();
                      onTap();
                    }
                  : null,
              child: SizedBox.square(
                dimension: size,
                child: Center(child: child),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
