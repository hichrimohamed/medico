import 'package:flutter/material.dart';

import '../../../../shared/reduced_motion.dart';
import '../../../../ui/ui.dart';
import '../../../doctors/data/doctor.dart';

/// The specialty filter. Scrolls horizontally, and the selected chip is the
/// only saturated thing in the row so the current filter is never in doubt.
class SpecialtyRail extends StatelessWidget {
  const SpecialtyRail({
    super.key,
    required this.specialties,
    required this.selected,
    required this.onSelected,
  });

  final List<Specialty> specialties;

  /// Null means "everything" — the unfiltered default.
  final Specialty? selected;
  final ValueChanged<Specialty?> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 112,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: Insets.xl),
        itemCount: specialties.length,
        separatorBuilder: (_, _) => const SizedBox(width: Insets.md),
        itemBuilder: (context, index) {
          final specialty = specialties[index];
          final isSelected = specialty.field == selected?.field;
          return _SpecialtyChip(
            specialty: specialty,
            selected: isSelected,
            // Tapping the active filter clears it, which is how a patient
            // gets back to the full list without hunting for a reset.
            onTap: () => onSelected(isSelected ? null : specialty),
          );
        },
      ),
    );
  }
}

class _SpecialtyChip extends StatelessWidget {
  const _SpecialtyChip({
    required this.specialty,
    required this.selected,
    required this.onTap,
  });

  final Specialty specialty;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Semantics(
      button: true,
      selected: selected,
      label: specialty.field,
      excludeSemantics: true,
      child: SizedBox(
        width: 92,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(Radii.lg),
          child: Column(
            children: [
              AnimatedContainer(
                duration: context.motion(Motion.base),
                curve: Motion.easeOut,
                width: 62,
                height: 62,
                decoration: BoxDecoration(
                  color: selected ? c.brand.solid : c.surface,
                  shape: BoxShape.circle,
                  border: Border.all(
                    // `line` is a divider colour and does not clear 3:1
                    // against the canvas. These circles are filter buttons —
                    // their edge is a control boundary and has to be visible.
                    color: selected ? c.brand.solid : c.control,
                  ),
                ),
                child: Icon(
                  specialty.icon,
                  size: 28,
                  color: selected ? c.brand.onSolid : c.brand.ink,
                ),
              ),
              const SizedBox(height: Insets.xs),
              Flexible(
                child: Text(
                  specialty.field,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.labelSmall?.copyWith(
                    color: selected ? c.ink : c.inkMuted,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
