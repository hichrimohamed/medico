import 'package:flutter/material.dart';

import '../../../../ui/ui.dart';
import '../../data/doctor.dart';

/// Name, credentials, price and portrait. Sits on the page ground rather than
/// in a card — it is the subject of the screen, not an item on it.
class DoctorHero extends StatelessWidget {
  const DoctorHero({super.key, required this.doctor});

  final Doctor doctor;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Padding(
      padding: const EdgeInsets.fromLTRB(Insets.xl, Insets.xs, Insets.md, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(doctor.specialty, style: context.text.bodyLarge
                    ?.copyWith(color: c.inkMuted)),
                const SizedBox(height: Insets.xxs),
                Text(
                  doctor.name,
                  style: context.text.headlineMedium,
                ),
                if (doctor.qualificationLine.isNotEmpty) ...[
                  const SizedBox(height: Insets.xs),
                  Text(
                    doctor.qualificationLine,
                    style: context.text.bodyMedium
                        ?.copyWith(color: c.inkMuted, height: 1.4),
                  ),
                ],
                const SizedBox(height: Insets.md),
                // Wrap, not Row: at a large text size the amount and the unit
                // stop fitting side by side and a Row would overflow.
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: Insets.xxs,
                  children: [
                    Text(
                      '\$${doctor.pricePerSession}',
                      style: context.text.headlineMedium
                          ?.copyWith(color: c.brand.solid),
                    ),
                    Text(
                      '/session',
                      style: context.text.bodyLarge
                          ?.copyWith(color: c.inkMuted),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: Insets.xs),
          Padding(
            padding: const EdgeInsets.only(top: Insets.sm),
            child: MedicoAvatar(
              name: doctor.name,
              initials: doctor.initials,
              image: doctor.photo,
              size: 132,
            ),
          ),
        ],
      ),
    );
  }
}

/// Experience, rating and patient count.
class StatTiles extends StatelessWidget {
  const StatTiles({super.key, required this.doctor});

  final Doctor doctor;

  @override
  Widget build(BuildContext context) {
    final stats = <(IconData, String, String)>[
      (
        Icons.work_outline_rounded,
        '${doctor.yearsExperience} years',
        'Experience',
      ),
      (Icons.star_border_rounded, doctor.rating.toStringAsFixed(1), 'Rating'),
      (
        Icons.group_outlined,
        doctor.patientCountLabel,
        'Patients',
      ),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(Insets.xl, Insets.lg, Insets.xl, 0),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final (icon, value, label) in stats) ...[
              Expanded(child: _StatTile(icon: icon, value: value, label: label)),
              if (label != 'Patients') const SizedBox(width: Insets.xs),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Semantics(
      label: '$value $label',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.all(Insets.sm),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(Radii.lg),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: Icon(icon, size: 20, color: c.brand.solid),
            ),
            const SizedBox(height: Insets.xs),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.text.titleMedium,
            ),
            Text(label, style: context.text.bodySmall),
          ],
        ),
      ),
    );
  }
}

/// A labelled fact — session fee, follow-up fee, and so on.
class FactTile extends StatelessWidget {
  const FactTile({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.note,
  });

  final IconData icon;
  final String label;
  final String value;
  final String? note;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Semantics(
      label: '$label: $value${note == null ? '' : ', $note'}',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.all(Insets.sm + 2),
        decoration: BoxDecoration(
          color: c.brand.container,
          borderRadius: BorderRadius.circular(Radii.lg),
          border: Border.all(color: c.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: c.brand.solid),
            const SizedBox(height: Insets.sm),
            Text(label, style: context.text.bodySmall),
            const SizedBox(height: 2),
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: value, style: context.text.titleMedium),
                  if (note != null)
                    TextSpan(
                      text: '  $note',
                      style: context.text.bodySmall,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A role or a degree: what, where, when.
class CredentialRow extends StatelessWidget {
  const CredentialRow({super.key, required this.credential, required this.last});

  final Credential credential;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 11,
                height: 11,
                margin: const EdgeInsets.only(top: 5),
                decoration: BoxDecoration(
                  color: c.brand.solid,
                  shape: BoxShape.circle,
                ),
              ),
              if (!last)
                Expanded(
                  child: VerticalDivider(
                    color: c.line,
                    thickness: 1.5,
                    width: 11,
                  ),
                ),
            ],
          ),
          const SizedBox(width: Insets.sm + 2),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: last ? 0 : Insets.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(credential.title, style: context.text.titleMedium),
                  const SizedBox(height: 2),
                  Text(credential.place, style: context.text.bodyMedium
                      ?.copyWith(color: c.inkMuted)),
                  const SizedBox(height: 2),
                  Text(credential.period, style: context.text.bodySmall),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ReviewCard extends StatelessWidget {
  const ReviewCard({super.key, required this.review});

  final Review review;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(Insets.md),
      decoration: BoxDecoration(
        color: c.brand.container,
        borderRadius: BorderRadius.circular(Radii.lg),
        border: Border.all(color: c.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(review.author, style: context.text.titleMedium),
              ),
              Semantics(
                label: '${review.rating.toStringAsFixed(0)} out of 5',
                excludeSemantics: true,
                child: Row(
                  children: [
                    for (var i = 1; i <= 5; i++)
                      Icon(
                        i <= review.rating
                            ? Icons.star_rounded
                            : Icons.star_border_rounded,
                        size: 15,
                        color: i <= review.rating
                            ? c.accent.solid
                            : c.control,
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: Insets.xs),
          Text(review.body, style: context.text.bodyMedium),
          const SizedBox(height: Insets.xs),
          Text(review.when, style: context.text.bodySmall),
        ],
      ),
    );
  }
}
