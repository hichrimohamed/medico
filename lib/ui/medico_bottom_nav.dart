import 'package:flutter/material.dart';

import '../shared/reduced_motion.dart';
import '../theme/app_tokens.dart';
import '../theme/theme_context.dart';

class NavDestination {
  const NavDestination(this.icon, this.label);

  final IconData icon;
  final String label;
}

/// The floating tab bar.
///
/// Only the active destination carries a label, so the current place is
/// legible without decoding five icons — and every destination still has a
/// tooltip and a screen-reader name, so nothing depends on the patient
/// recognising a glyph.
class MedicoBottomNav extends StatelessWidget {
  const MedicoBottomNav({
    super.key,
    required this.index,
    required this.onChanged,
    this.destinations = defaultDestinations,
  });

  final int index;
  final ValueChanged<int> onChanged;
  final List<NavDestination> destinations;

  static const List<NavDestination> defaultDestinations = [
    NavDestination(Icons.home_rounded, 'Home'),
    NavDestination(Icons.calendar_month_rounded, 'Appointments'),
    NavDestination(Icons.favorite_rounded, 'Saved'),
    NavDestination(Icons.chat_bubble_rounded, 'Messages'),
    NavDestination(Icons.person_rounded, 'Profile'),
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(Insets.md, 0, Insets.md, Insets.sm),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          for (var i = 0; i < destinations.length; i++)
            _NavItem(
              destination: destinations[i],
              selected: i == index,
              onTap: () => onChanged(i),
            ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  final NavDestination destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Semantics(
      button: true,
      selected: selected,
      label: destination.label,
      excludeSemantics: true,
      child: Tooltip(
        message: destination.label,
        child: AnimatedContainer(
          duration: context.motion(Motion.base),
          curve: Motion.easeOut,
          height: 52,
          decoration: BoxDecoration(
            color: selected ? c.brand.solid : c.surfaceRaised,
            borderRadius: BorderRadius.circular(Radii.xl + 6),
            // The one genuinely floating surface in the app: it sits over
            // scrolling content, so it earns its shadow.
            boxShadow: c.shadowLg,
          ),
          clipBehavior: Clip.antiAlias,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: selected ? Insets.sm + 2 : 0,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: selected ? null : 52,
                      child: Icon(
                        destination.icon,
                        size: 22,
                        color: selected ? c.brand.onSolid : c.inkMuted,
                      ),
                    ),
                    if (selected) ...[
                      const SizedBox(width: Insets.xs),
                      Text(
                        destination.label,
                        // The bar is a fixed-height strip across the bottom of
                        // the screen; at 200% this label would push the other
                        // four destinations off it.
                        textScaler: TextScaler.noScaling,
                        style: context.text.labelSmall?.copyWith(
                          color: c.brand.onSolid,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
