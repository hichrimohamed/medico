import 'package:flutter/material.dart';

import '../../../../shared/reduced_motion.dart';
import '../../../../ui/ui.dart';
import '../../data/doctor.dart';

/// The week of open slots on the featured card.
///
/// Every colour here is a white overlay on the card's blue. The overlays stop
/// at 12% because past that, white text on the resulting blue drops below
/// 4.5:1 — the band would look softer and read worse.
class AvailabilityStrip extends StatelessWidget {
  const AvailabilityStrip({
    super.key,
    required this.weekStart,
    required this.selectedDay,
    required this.openSlots,
    required this.onDaySelected,
    required this.onWeekChanged,
  });

  final DateTime weekStart;
  final DateTime selectedDay;
  final int openSlots;
  final ValueChanged<DateTime> onDaySelected;

  /// -1 for the previous week, 1 for the next.
  final ValueChanged<int> onWeekChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final days = List<DateTime>.generate(
      7,
      (index) => DateTime(weekStart.year, weekStart.month, weekStart.day + index),
    );
    final month = kMonthNames[weekStart.month - 1];

    return LayoutBuilder(
      builder: (context, constraints) {
        // The month is always abbreviated: spelled out, it squeezed the
        // heading into an ellipsis on every phone width. Below `tight` even
        // the short form does not share a line, so the two stack.
        final tight = constraints.maxWidth < 300;
        final label = '${month.substring(0, 3)} ${weekStart.year}';

        return Container(
          padding: const EdgeInsets.all(Insets.sm),
          decoration: BoxDecoration(
            color: c.brand.onSolid.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(Radii.lg),
          ),
          child: Column(
            children: [
              if (tight) ...[
                Row(children: [Expanded(child: _Heading(openSlots: openSlots))]),
                const SizedBox(height: Insets.xxs),
                _MonthStepper(
                  label: label,
                  onWeekChanged: onWeekChanged,
                  expanded: true,
                ),
              ] else
                Row(
                  children: [
                    Flexible(child: _Heading(openSlots: openSlots)),
                    const SizedBox(width: Insets.xs),
                    _MonthStepper(label: label, onWeekChanged: onWeekChanged),
                  ],
                ),
              const SizedBox(height: Insets.xs + 2),
              Row(
                children: [
                  for (final day in days)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: _DayChip(
                          day: day,
                          selected: _sameDay(day, selectedDay),
                          onTap: () => onDaySelected(day),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

class _Heading extends StatelessWidget {
  const _Heading({required this.openSlots});

  final int openSlots;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: 'Availability',
            style: context.text.labelMedium?.copyWith(color: c.brand.onSolid),
          ),
          TextSpan(
            text: '  ·  $openSlots slots',
            style: context.text.bodySmall?.copyWith(color: c.onBrandMuted),
          ),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

class _MonthStepper extends StatelessWidget {
  const _MonthStepper({
    required this.label,
    required this.onWeekChanged,
    this.expanded = false,
  });

  final String label;
  final ValueChanged<int> onWeekChanged;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final text = Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.center,
      style: context.text.labelSmall
          ?.copyWith(color: context.colors.brand.onSolid),
    );

    return Row(
      mainAxisSize: expanded ? MainAxisSize.max : MainAxisSize.min,
      children: [
        _WeekArrow(
          icon: Icons.chevron_left_rounded,
          label: 'Previous week',
          onPressed: () => onWeekChanged(-1),
        ),
        if (expanded) Expanded(child: text) else Flexible(child: text),
        _WeekArrow(
          icon: Icons.chevron_right_rounded,
          label: 'Next week',
          onPressed: () => onWeekChanged(1),
        ),
      ],
    );
  }
}

class _WeekArrow extends StatelessWidget {
  const _WeekArrow({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      icon: Icon(icon, size: 22),
      color: context.colors.brand.onSolid,
      tooltip: label,
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints.tightFor(width: 34, height: 34),
      padding: EdgeInsets.zero,
    );
  }
}

class _DayChip extends StatelessWidget {
  const _DayChip({
    required this.day,
    required this.selected,
    required this.onTap,
  });

  final DateTime day;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final weekday = kWeekdayNames[day.weekday - 1];

    return Semantics(
      button: true,
      selected: selected,
      label: '$weekday ${day.day}',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Radii.md),
        child: AnimatedContainer(
          duration: context.motion(Motion.base),
          curve: Motion.easeOut,
          padding: const EdgeInsets.symmetric(vertical: Insets.xs),
          decoration: BoxDecoration(
            color: selected
                ? c.brand.onSolid
                : c.brand.onSolid.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(Radii.md),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                weekday,
                textScaler: TextScaler.noScaling,
                style: context.text.labelSmall?.copyWith(
                  color: selected ? c.inkMuted : c.brand.container,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                '${day.day}',
                textScaler: TextScaler.noScaling,
                style: context.text.titleSmall?.copyWith(
                  color: selected ? c.brand.solid : c.brand.onSolid,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
