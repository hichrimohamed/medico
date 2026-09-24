import 'package:flutter/material.dart';

import '../../../app/app_scope.dart';
import '../../../app/routes.dart';
import '../../../core/api/api_exception.dart';
import '../../../shared/announce.dart';
import '../../../ui/ui.dart';
import '../data/doctor.dart';
import '../data/patient_repository.dart';
import 'widgets/doctor_card.dart';

/// The doctors a patient has kept.
///
/// A short list, by design: this is the shelf a patient comes back to, not a
/// second directory. So it borrows the directory's own card rather than
/// inventing a smaller one — the same doctor should look the same wherever
/// they appear, or the list stops reading as "mine" and starts reading as
/// "another screen".
class SavedDoctorsScreen extends StatefulWidget {
  const SavedDoctorsScreen({
    super.key,
    this.patient,
    this.bottomInset = 0,
    this.onFindDoctor,
  });

  final PatientRepository? patient;

  /// Room for the floating tab bar this screen sits under.
  final double bottomInset;

  /// Sends an empty-handed patient to the directory. Null hides the offer.
  final VoidCallback? onFindDoctor;

  @override
  State<SavedDoctorsScreen> createState() => _SavedDoctorsScreenState();
}

class _SavedDoctorsScreenState extends State<SavedDoctorsScreen> {
  PatientRepository get _patient =>
      widget.patient ?? AppScope.of(context).patient;

  List<Doctor> _doctors = const [];
  bool _loading = true;
  String? _error;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final doctors = await _patient.favourites();
      if (!mounted) return;
      setState(() {
        _doctors = doctors;
        _loading = false;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.message;
      });
      context.announce(error.message, urgent: true);
    }
  }

  /// Unsaving here removes the row the patient is looking at, so it comes with
  /// an undo rather than a confirmation. A dialog for something this cheap to
  /// reverse is a toll booth; an undo costs nothing and covers the fat finger.
  Future<void> _remove(Doctor doctor) async {
    final at = _doctors.indexWhere((saved) => saved.id == doctor.id);
    if (at < 0) return;

    setState(() => _doctors = [..._doctors]..removeAt(at));

    try {
      await _patient.setFavourite(doctor.id, saved: false);
      if (!mounted) return;
      showMedicoSnack(
        context,
        'Removed ${doctor.name} from saved.',
        actionLabel: 'Undo',
        onAction: () => _restore(doctor, at),
      );
    } on ApiException catch (error) {
      if (!mounted) return;
      // The server kept them, so the list has to as well.
      setState(() => _doctors = [..._doctors]..insert(at, doctor));
      showMedicoSnack(context, error.message);
    }
  }

  Future<void> _restore(Doctor doctor, int at) async {
    // Back where they were, not on the end — the patient is undoing a mistake,
    // not saving the doctor again.
    setState(() {
      final restored = [..._doctors];
      restored.insert(at.clamp(0, restored.length), doctor);
      _doctors = restored;
    });

    try {
      await _patient.setFavourite(doctor.id, saved: true);
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _doctors = [..._doctors]
        ..removeWhere((saved) => saved.id == doctor.id));
      showMedicoSnack(context, error.message);
    }
  }

  void _openDoctor(Doctor doctor) {
    Navigator.of(context)
        .pushNamed(AppRoutes.doctor, arguments: doctor)
        // A heart tapped on the doctor's own page changes this list, so it is
        // re-read on the way back rather than showing a doctor the patient has
        // just unsaved.
        .then((_) {
      if (mounted) _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _load,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(child: _Header(count: _doctors.length)),
          if (_error != null)
            SliverToBoxAdapter(
              child: _Padded(
                child: MedicoCard(
                  child: MedicoEmptyState.failure(
                    title: 'We could not load your saved doctors',
                    message: _error!,
                    onAction: _load,
                  ),
                ),
              ),
            )
          else if (_loading)
            const SliverToBoxAdapter(child: _ListSkeleton())
          else if (_doctors.isEmpty)
            SliverToBoxAdapter(
              child: _Padded(
                child: MedicoCard(
                  child: MedicoEmptyState(
                    compact: true,
                    icon: Icons.favorite_border_rounded,
                    title: 'No saved doctors yet',
                    message: 'Tap the heart on any doctor to keep them here, '
                        'so booking again takes one tap instead of a search.',
                    actionLabel:
                        widget.onFindDoctor == null ? null : 'Find a doctor',
                    onAction: widget.onFindDoctor,
                  ),
                ),
              ),
            )
          else
            SliverList.separated(
              itemCount: _doctors.length,
              separatorBuilder: (_, _) => const SizedBox(height: Insets.sm),
              itemBuilder: (context, index) {
                final doctor = _doctors[index];
                return _Padded(
                  child: DoctorListCard(
                    doctor: doctor,
                    // Every doctor on this screen is saved, by definition.
                    favourite: true,
                    onFavouriteToggled: () => _remove(doctor),
                    onTap: () => _openDoctor(doctor),
                  ),
                );
              },
            ),
          SliverToBoxAdapter(child: SizedBox(height: widget.bottomInset)),
        ],
      ),
    );
  }
}

class _Padded extends StatelessWidget {
  const _Padded({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: Insets.gutter),
        child: child,
      );
}

class _Header extends StatelessWidget {
  const _Header({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Insets.gutter,
        Insets.sm,
        Insets.gutter,
        Insets.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: Text('Saved doctors', style: context.text.headlineSmall),
          ),
          const SizedBox(height: 2),
          Text(
            count == 1
                ? 'One doctor you can book again in a tap.'
                : 'Doctors you can book again in a tap.',
            style: context.text.bodyLarge?.copyWith(color: c.inkMuted),
          ),
        ],
      ),
    );
  }
}

/// The shape of the list while it is on its way — the same card height, so
/// nothing jumps when the real doctors land.
class _ListSkeleton extends StatelessWidget {
  const _ListSkeleton();

  @override
  Widget build(BuildContext context) {
    return MedicoLoadingRegion(
      label: 'Loading your saved doctors',
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Insets.gutter),
        child: Column(
          children: [
            for (var i = 0; i < 3; i++) ...[
              MedicoSkeleton(
                width: double.infinity,
                height: 96,
                radius: Radii.xlAll,
              ),
              const SizedBox(height: Insets.sm),
            ],
          ],
        ),
      ),
    );
  }
}
