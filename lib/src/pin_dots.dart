import 'dart:math' as math;

import 'package:flutter/material.dart';

/// A row of dots showing how many PIN digits have been entered. Call
/// [PinDotsState.shake] through a `GlobalKey` to signal a wrong PIN.
class PinDots extends StatefulWidget {
  /// Creates the dots.
  const PinDots({
    super.key,
    required this.length,
    required this.filled,
    this.error = false,
  });

  /// Total digits.
  final int length;

  /// Digits entered so far.
  final int filled;

  /// Draws the dots in the error color.
  final bool error;

  @override
  State<PinDots> createState() => PinDotsState();
}

/// State for [PinDots], exposing [shake].
class PinDotsState extends State<PinDots> with SingleTickerProviderStateMixin {
  late final AnimationController _shake = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 450),
  );

  /// Shakes the row sideways, like a wrong passcode on iOS.
  void shake() => _shake.forward(from: 0);

  @override
  void dispose() {
    _shake.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final active = widget.error ? scheme.error : scheme.primary;
    return AnimatedBuilder(
      animation: _shake,
      builder: (context, child) {
        // damped sine: a few quick swings that settle
        final t = _shake.value;
        final dx = math.sin(t * math.pi * 6) * 14 * (1 - t);
        return Transform.translate(offset: Offset(dx, 0), child: child);
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < widget.length; i++)
            AnimatedContainer(
              key: ValueKey('app_lock_dot_$i'),
              duration: const Duration(milliseconds: 160),
              curve: Curves.easeOut,
              margin: const EdgeInsets.symmetric(horizontal: 9),
              width: i < widget.filled ? 16 : 14,
              height: i < widget.filled ? 16 : 14,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: i < widget.filled ? active : Colors.transparent,
                border: Border.all(
                  color: i < widget.filled ? active : scheme.outline,
                  width: 1.6,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
