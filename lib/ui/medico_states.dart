import 'package:flutter/material.dart';

import '../shared/reduced_motion.dart';
import '../theme/app_tokens.dart';
import '../theme/theme_context.dart';
import 'medico_button.dart';

/// What a screen shows when it has nothing to show.
///
/// PRODUCT.md, principle 3: never a dead end. An empty list is not an error
/// and it is not a shrug — it says what would be here, and offers the one
/// action that would put something here.
class MedicoEmptyState extends StatelessWidget {
  const MedicoEmptyState({
    super.key,
    required this.title,
    required this.message,
    this.icon = Icons.inbox_outlined,
    this.actionLabel,
    this.onAction,
    this.compact = false,
  });

  /// Something could not be fetched.
  ///
  /// Empty and broken are different facts and a patient should be able to tell
  /// them apart: an empty list means "you have none of these", a failure means
  /// "we could not find out". [message] is the server's own words — it already
  /// says what happened — and the retry is the action principle 3 requires.
  const MedicoEmptyState.failure({
    super.key,
    required this.title,
    required this.message,
    required VoidCallback this.onAction,
    this.actionLabel = 'Try again',
    this.compact = true,
  }) : icon = Icons.cloud_off_rounded;

  final String title;
  final String message;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  /// For an empty state inside a card rather than on a whole screen.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final text = context.text;

    return Semantics(
      container: true,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: Insets.xl,
          vertical: compact ? Insets.lg : Insets.xxl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: compact ? 48 : 64,
              height: compact ? 48 : 64,
              decoration: BoxDecoration(
                color: c.surfaceSunken,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: compact ? IconSize.lg : IconSize.xl,
                // Decorative: the title and message say everything this says.
                color: c.inkMuted,
                semanticLabel: null,
              ),
            ),
            SizedBox(height: compact ? Insets.sm : Insets.md),
            Semantics(
              header: true,
              child: Text(
                title,
                textAlign: TextAlign.center,
                style: compact ? text.titleSmall : text.titleMedium,
              ),
            ),
            const SizedBox(height: Insets.xxs),
            Text(
              message,
              textAlign: TextAlign.center,
              style: text.bodyMedium?.copyWith(color: c.inkMuted),
            ),
            if (actionLabel != null && onAction != null) ...[
              SizedBox(height: compact ? Insets.md : Insets.lg),
              MedicoButton(
                label: actionLabel!,
                onPressed: onAction,
                size: MedicoButtonSize.medium,
                expand: false,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// A placeholder shaped like the thing that is loading.
///
/// Two rules keep this from becoming decoration. It is only used where the
/// real content's shape is known, so nothing jumps when the data lands. And
/// the shimmer stops entirely under reduced motion — a patient who has asked
/// the OS to stop animating things should not get a pulsing screen while they
/// wait.
class MedicoSkeleton extends StatefulWidget {
  const MedicoSkeleton({
    super.key,
    required this.width,
    required this.height,
    this.radius = Radii.smAll,
  });

  /// A line of text at a given type size, with the right height and radius.
  const MedicoSkeleton.line({
    super.key,
    required this.width,
    this.height = 13,
  }) : radius = const BorderRadius.all(Radius.circular(4));

  const MedicoSkeleton.circle({super.key, required double size})
      : width = size,
        height = size,
        radius = const BorderRadius.all(Radius.circular(999));

  final double width;
  final double height;
  final BorderRadius radius;

  @override
  State<MedicoSkeleton> createState() => _MedicoSkeletonState();
}

class _MedicoSkeletonState extends State<MedicoSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (context.prefersReducedMotion) {
      _controller.stop();
      _controller.value = 0;
    } else if (!_controller.isAnimating) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return ExcludeSemantics(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return Container(
            width: widget.width,
            height: widget.height,
            decoration: BoxDecoration(
              color: Color.lerp(
                c.skeletonBase,
                c.skeletonHighlight,
                _controller.value * 0.6,
              ),
              borderRadius: widget.radius,
            ),
          );
        },
      ),
    );
  }
}

/// Wraps a loading region so assistive technology says "Loading" once, instead
/// of narrating a wall of grey rectangles.
class MedicoLoadingRegion extends StatelessWidget {
  const MedicoLoadingRegion({
    super.key,
    required this.child,
    this.label = 'Loading',
  });

  final Widget child;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      liveRegion: true,
      excludeSemantics: true,
      child: child,
    );
  }
}
