import 'package:flutter/material.dart';

import '../../../../shared/reduced_motion.dart';
import '../../../../ui/ui.dart';
import '../../data/doctor.dart';
import 'availability_strip.dart';

/// The lead doctor: saturated, with the week's availability already open so
/// booking is one tap from the top of the screen.
class FeaturedDoctorCard extends StatelessWidget {
  const FeaturedDoctorCard({
    super.key,
    required this.doctor,
    required this.favourite,
    required this.onFavouriteToggled,
    required this.weekStart,
    required this.selectedDay,
    required this.onDaySelected,
    required this.onWeekChanged,
    required this.onTap,
    this.openSlots,
  });

  final Doctor doctor;

  /// Free slots on the selected day, once availability has been fetched.
  /// Null falls back to whatever the doctor arrived with, which is what keeps
  /// the card honest while the request is still in flight.
  final int? openSlots;
  final bool favourite;
  final VoidCallback onFavouriteToggled;
  final DateTime weekStart;
  final DateTime selectedDay;
  final ValueChanged<DateTime> onDaySelected;
  final ValueChanged<int> onWeekChanged;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Material(
      color: c.brand.solid,
      borderRadius: BorderRadius.circular(Radii.xl + 4),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(Insets.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  RatingPill(rating: doctor.rating),
                  const Spacer(),
                  FavouriteButton(
                    favourite: favourite,
                    onPressed: onFavouriteToggled,
                    onDark: true,
                  ),
                ],
              ),
              const SizedBox(height: Insets.sm),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          doctor.specialty,
                          style: context.text.bodyMedium
                              ?.copyWith(color: c.onBrandMuted),
                        ),
                        const SizedBox(height: Insets.xxs),
                        Text(
                          doctor.name,
                          style: context.text.headlineSmall
                              ?.copyWith(color: c.brand.onSolid),
                        ),
                        const SizedBox(height: Insets.xs),
                        _Price(
                          amount: doctor.pricePerSession,
                          onDark: true,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: Insets.xs),
                  MedicoAvatar(
                    name: doctor.name,
                    initials: doctor.initials,
                    image: doctor.photo,
                    size: AvatarSize.xl,
                    onBrand: true,
                  ),
                ],
              ),
              const SizedBox(height: Insets.md),
              AvailabilityStrip(
                weekStart: weekStart,
                selectedDay: selectedDay,
                openSlots: openSlots ?? doctor.openSlots,
                onDaySelected: onDaySelected,
                onWeekChanged: onWeekChanged,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Every other doctor in the list. A compact row rather than a second copy of
/// the featured card: more of the directory fits on screen, and the lead card
/// keeps its meaning.
class DoctorListCard extends StatelessWidget {
  const DoctorListCard({
    super.key,
    required this.doctor,
    required this.favourite,
    required this.onFavouriteToggled,
    required this.onTap,
  });

  final Doctor doctor;
  final bool favourite;
  final VoidCallback onFavouriteToggled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Material(
      color: c.surface,
      borderRadius: BorderRadius.circular(Radii.xl),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(Insets.sm + 2),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // The avatar names the doctor for its own sake, which is right
              // when it stands alone. Here the name is printed beside it, so
              // leaving both in makes a screen reader say it twice.
              ExcludeSemantics(
                child: MedicoAvatar(
                  name: doctor.name,
                  initials: doctor.initials,
                  image: doctor.photo,
                  size: 72,
                ),
              ),
              const SizedBox(width: Insets.sm + 2),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      doctor.specialty,
                      style: context.text.bodySmall,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      doctor.name,
                      style: context.text.titleMedium,
                    ),
                    const SizedBox(height: Insets.xs),
                    // Wrap, not Row: a three-digit fee plus the rating
                    // overflows the remaining width on a narrow card.
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: Insets.sm,
                      runSpacing: Insets.xxs,
                      children: [
                        _Price(amount: doctor.pricePerSession),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.star_rounded,
                              size: 17,
                              color: c.accent.solid,
                            ),
                            const SizedBox(width: 2),
                            Text(
                              doctor.rating.toStringAsFixed(1),
                              style: context.text.bodySmall?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: c.inkBody,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              FavouriteButton(
                favourite: favourite,
                onPressed: onFavouriteToggled,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Price extends StatelessWidget {
  const _Price({required this.amount, this.onDark = false});

  final int amount;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      label: '$amount dollars per session',
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(
            '\$$amount',
            style: (onDark ? context.text.titleLarge : context.text.titleMedium)
                ?.copyWith(color: onDark ? c.brand.onSolid : c.ink),
          ),
          Text(
            '/session',
            style: context.text.bodySmall?.copyWith(
              color: onDark ? c.brand.container : c.inkMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class FavouriteButton extends StatelessWidget {
  const FavouriteButton({
    super.key,
    required this.favourite,
    required this.onPressed,
    this.onDark = false,
  });

  final bool favourite;
  final VoidCallback onPressed;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      // `container: true` is what makes this its own node. Without it the
      // heart's name and its toggled state are merged into whatever tappable
      // ancestor it sits in — a card, usually — which leaves a screen-reader
      // user hearing "…, Remove from saved doctors" as the tail of the card's
      // label, with no way to activate it separately.
      container: true,
      button: true,
      toggled: favourite,
      label: favourite ? 'Remove from saved doctors' : 'Save this doctor',
      excludeSemantics: true,
      child: Tooltip(
        message: favourite ? 'Saved' : 'Save',
        child: SizedBox.square(
          dimension: Layout.minTapTarget,
          child: Center(
            child: Material(
              color: onDark
                  ? c.brand.onSolid.withValues(alpha: 0.16)
                  : c.brand.container,
              shape: const CircleBorder(),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: onPressed,
                child: SizedBox.square(
                  dimension: 42,
                  child: AnimatedSwitcher(
                    duration: context.motion(Motion.fast),
                    transitionBuilder: (child, animation) =>
                        ScaleTransition(scale: animation, child: child),
                    child: Icon(
                      favourite
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                      key: ValueKey<bool>(favourite),
                      size: 20,
                      color: onDark
                          ? c.brand.onSolid
                          : (favourite
                              ? c.brand.solid
                              : c.inkMuted),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
