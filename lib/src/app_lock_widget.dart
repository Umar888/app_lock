import 'package:flutter/material.dart';

import 'app_lock_controller.dart';
import 'app_lock_labels.dart';
import 'lock_screen.dart';

/// Builds a custom lock screen.
typedef LockScreenBuilder =
    Widget Function(BuildContext context, AppLockController controller);

/// Puts a lock screen over the whole app while [controller] is locked.
///
/// Place it in `MaterialApp.builder` so it sits above every route:
///
/// ```dart
/// MaterialApp(
///   builder: (context, child) => AppLock(controller: lock, child: child!),
///   home: const HomePage(),
/// )
/// ```
///
/// The app stays mounted underneath, so its state survives locking. While
/// locked it can't be tapped, focused or read by screen readers, its
/// animations pause, and Android's back button does nothing.
class AppLock extends StatefulWidget {
  /// Creates the lock.
  const AppLock({
    super.key,
    required this.controller,
    required this.child,
    this.lockScreenBuilder,
    this.labels = const AppLockLabels(),
    this.blurBackground = true,
    this.transitionDuration = const Duration(milliseconds: 280),
  });

  /// The lock state to follow.
  final AppLockController controller;

  /// The app.
  final Widget child;

  /// Replaces the built-in [LockScreen].
  final LockScreenBuilder? lockScreenBuilder;

  /// Strings for the built-in lock screen.
  final AppLockLabels labels;

  /// Blurs the app behind the built-in lock screen instead of hiding it.
  final bool blurBackground;

  /// How long the lock screen takes to fade in and out.
  final Duration transitionDuration;

  @override
  State<AppLock> createState() => _AppLockState();
}

class _AppLockState extends State<AppLock> {
  @override
  void initState() {
    super.initState();
    widget.controller.init();
  }

  @override
  void didUpdateWidget(AppLock oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) widget.controller.init();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, child) {
        final controller = widget.controller;
        final ready = controller.isReady;
        final covered = !ready || controller.isLocked;
        return Stack(
          children: [
            ExcludeSemantics(
              excluding: covered,
              child: ExcludeFocus(
                excluding: covered,
                child: AbsorbPointer(
                  absorbing: covered,
                  child: TickerMode(enabled: !covered, child: child!),
                ),
              ),
            ),
            // until init finishes we don't know yet whether to lock, so keep
            // the content hidden instead of flashing it
            if (!ready)
              Positioned.fill(
                child: ColoredBox(color: Theme.of(context).colorScheme.surface),
              ),
            Positioned.fill(
              child: AnimatedSwitcher(
                duration: widget.transitionDuration,
                switchInCurve: Curves.easeOut,
                switchOutCurve: Curves.easeIn,
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: ScaleTransition(
                    scale: Tween(begin: 1.04, end: 1.0).animate(animation),
                    child: child,
                  ),
                ),
                child: ready && controller.isLocked
                    ? KeyedSubtree(
                        key: const ValueKey('app_lock_screen'),
                        // AppLock sits above the app's Navigator, so give the
                        // lock screen its own Overlay for tooltips and menus
                        child: Overlay.wrap(
                          child:
                              widget.lockScreenBuilder?.call(
                                context,
                                controller,
                              ) ??
                              LockScreen(
                                controller: controller,
                                labels: widget.labels,
                                blurBackground: widget.blurBackground,
                              ),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ),
          ],
        );
      },
      child: widget.child,
    );
  }
}
