import 'package:flutter/material.dart';

import '../../../app/app_scope.dart';
import '../../../app/routes.dart';
import '../../../core/api/api_exception.dart';
import '../../../shared/announce.dart';
import '../../../ui/ui.dart';
import '../../doctors/data/doctor.dart';
import '../../doctors/data/patient_repository.dart';
import '../data/appointment.dart';

/// What the patient has booked.
///
/// The screen answers one question first — *am I seeing someone, and when* —
/// so the next appointment is the first thing on it and the date is the
/// largest thing on the card. Everything else is there to make that legible:
/// who, what they do, and whether the clinic still expects the patient to
/// turn up.
class AppointmentsScreen extends StatefulWidget {
  const AppointmentsScreen({
    super.key,
    this.patient,
    this.bottomInset = 0,
    this.onFindDoctor,
    this.now,
  });

  final PatientRepository? patient;

  /// Room for the floating tab bar this screen sits under.
  final double bottomInset;

  /// Sends an empty-handed patient to the directory. Null hides the offer.
  final VoidCallback? onFindDoctor;

  /// Fixed clock, for tests. "Upcoming" is a question about the time, and a
  /// screen whose golden render depends on `DateTime.now()` is a golden that
  /// fails at midnight.
  final DateTime? now;

  @override
  State<AppointmentsScreen> createState() => _AppointmentsScreenState();
}

class _AppointmentsScreenState extends State<AppointmentsScreen> {
  PatientRepository get _patient =>
      widget.patient ?? AppScope.of(context).patient;

  DateTime get _now => widget.now ?? DateTime.now();

  AppointmentFilter _filter = AppointmentFilter.upcoming;
  List<Appointment> _appointments = const [];

  bool _loading = true;
  String? _error;
  bool _started = false;

  /// The one being cancelled, so its own card can show the wait rather than
  /// the whole list going grey.
  String? _cancelling;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _load();
  }

  Future<void> _load({AppointmentFilter? filter}) async {
    final wanted = filter ?? _filter;
    setState(() {
      _filter = wanted;
      _loading = true;
      _error = null;
    });

    try {
      final appointments = await _patient.appointments(wanted);
      if (!mounted) return;
      setState(() {
        _appointments = appointments;
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

  /// Cancelling is the one irreversible thing on this screen — the slot goes
  /// back to the clinic the moment it is confirmed, and someone else can take
  /// it — so it asks first, and the buttons are named for what they do.
  Future<void> _cancel(Appointment appointment) async {
    final confirmed = await showMedicoConfirm(
      context: context,
      title: 'Cancel this appointment?',
      message: '${appointment.doctor.name} on ${appointment.dayLabel} at '
          '${appointment.clinicTime}. The time goes back to the clinic, and we '
          'cannot hold it for you.',
      confirmLabel: 'Cancel appointment',
      cancelLabel: 'Keep it',
      destructive: true,
    );
    if (!confirmed || !mounted) return;

    setState(() => _cancelling = appointment.id);
    try {
      await _patient.cancelAppointment(appointment.id);
      if (!mounted) return;
      setState(() => _cancelling = null);
      _say('Appointment cancelled. It is under Cancelled if you need it.');
      await _load();
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _cancelling = null);
      _say(error.message);
    }
  }

  void _openDoctor(Doctor doctor) {
    if (doctor.id.isEmpty) return;
    Navigator.of(context).pushNamed(AppRoutes.doctor, arguments: doctor);
  }

  void _say(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));
    context.announce(message);
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _load,
      child: CustomScrollView(
        // Always scrollable, or pull-to-refresh dies on the empty state —
        // which is exactly where a patient expecting a booking to appear will
        // pull.
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          const SliverToBoxAdapter(child: _Header()),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(bottom: Insets.lg),
              child: MedicoChipBar(
                children: [
                  for (final filter in AppointmentFilter.values)
                    MedicoChip(
                      label: filter.label,
                      selected: filter == _filter,
                      // Only the filter in force carries a count, and only
                      // when there is something to count: "Upcoming 0" next to
                      // an empty state that already says so is the same fact
                      // twice.
                      count: filter == _filter &&
                              !_loading &&
                              _error == null &&
                              _appointments.isNotEmpty
                          ? _appointments.length
                          : null,
                      onTap: () {
                        if (filter == _filter) return;
                        _load(filter: filter);
                      },
                    ),
                ],
              ),
            ),
          ),
          if (_error != null)
            SliverToBoxAdapter(
              child: _Padded(
                child: MedicoCard(
                  child: MedicoEmptyState.failure(
                    title: 'We could not load your appointments',
                    message: _error!,
                    onAction: _load,
                  ),
                ),
              ),
            )
          else if (_loading)
            const SliverToBoxAdapter(child: _ListSkeleton())
          else if (_appointments.isEmpty)
            SliverToBoxAdapter(
              child: _Padded(
                child: MedicoCard(
                  child: _EmptyFor(
                    filter: _filter,
                    onFindDoctor: widget.onFindDoctor,
                  ),
                ),
              ),
            )
          else
            SliverList.separated(
              itemCount: _appointments.length,
              separatorBuilder: (_, _) => const SizedBox(height: Insets.sm),
              itemBuilder: (context, index) {
                final appointment = _appointments[index];
                return _Padded(
                  child: AppointmentCard(
                    appointment: appointment,
                    now: _now,
                    cancelling: _cancelling == appointment.id,
                    onCancel: () => _cancel(appointment),
                    onTap: () => _openDoctor(appointment.doctor),
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
  const _Header();

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
            child: Text('Appointments', style: context.text.headlineSmall),
          ),
          const SizedBox(height: 2),
          Text(
            'Times are the clinic’s own.',
            style: context.text.bodyLarge?.copyWith(color: c.inkMuted),
          ),
        ],
      ),
    );
  }
}

/// One appointment.
///
/// The whole card opens the doctor, so the target is a card and not a link in
/// a corner. Cancel is deliberately *not* inside that target: a destructive
/// action nested in a tappable row is how people cancel things they meant to
/// look at.
class AppointmentCard extends StatelessWidget {
  const AppointmentCard({
    super.key,
    required this.appointment,
    required this.now,
    required this.onCancel,
    required this.onTap,
    this.cancelling = false,
  });

  final Appointment appointment;
  final DateTime now;
  final VoidCallback onCancel;
  final VoidCallback onTap;
  final bool cancelling;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final state = appointment.stateAt(now);
    final doctor = appointment.doctor;
    final canCancel = appointment.canCancelAt(now);

    return MedicoCard(
      onTap: onTap,
      // One announcement for one subject, rather than six fragments.
      semanticLabel: '${_statusOf(state).label}. ${doctor.name}'
          '${doctor.specialty.isEmpty ? '' : ', ${doctor.specialty}'}. '
          '${appointment.dayLabel} at ${appointment.clinicTime}.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _DateBlock(appointment: appointment, dimmed: !canCancel),
              const SizedBox(width: Insets.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (doctor.specialty.isNotEmpty)
                      Text(
                        doctor.specialty,
                        style: context.text.bodySmall?.copyWith(
                          color: c.inkMuted,
                        ),
                      ),
                    // The name gets the full width of the card. The badge used
                    // to sit beside it and pushed every second surname onto a
                    // line of its own.
                    Text(
                      doctor.name,
                      style: context.text.titleMedium,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: Insets.xs),
                    Wrap(
                      spacing: Insets.sm,
                      runSpacing: Insets.xs,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.schedule_rounded,
                              size: IconSize.sm,
                              color: c.inkMuted,
                            ),
                            const SizedBox(width: Insets.xxs),
                            Text(
                              '${appointment.clinicTime} – '
                              '${appointment.clinicEndTime}',
                              style: context.text.bodyMedium
                                  ?.copyWith(color: c.inkBody),
                            ),
                          ],
                        ),
                        StatusBadge(status: _statusOf(state)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (appointment.reason.isNotEmpty) ...[
            const SizedBox(height: Insets.sm),
            Text(
              appointment.reason,
              style: context.text.bodyMedium?.copyWith(color: c.inkMuted),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          if (canCancel) ...[
            Divider(color: c.line, height: Insets.xl),
            Align(
              alignment: Alignment.centerLeft,
              child: MedicoButton.quiet(
                label: 'Cancel appointment',
                busyLabel: 'Cancelling',
                busy: cancelling,
                onPressed: cancelling ? null : onCancel,
                size: MedicoButtonSize.medium,
                expand: false,
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// The clinical vocabulary is closed — see [MedicoStatus]. This is the only
  /// place an appointment's state is turned into one of its cases.
  static MedicoStatus _statusOf(AppointmentState state) => switch (state) {
        AppointmentState.scheduled => MedicoStatus.scheduled,
        AppointmentState.inProgress => MedicoStatus.inProgress,
        AppointmentState.completed => MedicoStatus.completed,
        AppointmentState.cancelled => MedicoStatus.cancelled,
      };
}

/// The date, as the thing the eye lands on first.
class _DateBlock extends StatelessWidget {
  const _DateBlock({required this.appointment, required this.dimmed});

  final Appointment appointment;

  /// Past and cancelled appointments keep their shape but lose their colour —
  /// the list stays scannable without them shouting alongside the live ones.
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Container(
      width: 58,
      padding: const EdgeInsets.symmetric(vertical: Insets.xs),
      decoration: BoxDecoration(
        color: dimmed ? c.canvas : c.brand.container,
        borderRadius: Radii.mdAll,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            appointment.dayOfMonth,
            style: context.text.titleLarge?.copyWith(
              color: dimmed ? c.inkMuted : c.brand.ink,
            ),
          ),
          Text(
            appointment.monthShort,
            style: context.text.labelSmall?.copyWith(
              color: dimmed ? c.inkMuted : c.brand.ink,
            ),
          ),
        ],
      ),
    );
  }
}

/// Nothing to show is a fact, not a failure — and each filter is empty for a
/// different reason, so each says its own.
class _EmptyFor extends StatelessWidget {
  const _EmptyFor({required this.filter, required this.onFindDoctor});

  final AppointmentFilter filter;
  final VoidCallback? onFindDoctor;

  @override
  Widget build(BuildContext context) {
    return switch (filter) {
      AppointmentFilter.upcoming => MedicoEmptyState(
          compact: true,
          icon: Icons.event_available_outlined,
          title: 'Nothing booked yet',
          message: 'When you book a time with a doctor it will appear here, '
              'with everything you need to turn up.',
          actionLabel: onFindDoctor == null ? null : 'Find a doctor',
          onAction: onFindDoctor,
        ),
      AppointmentFilter.past => MedicoEmptyState(
          compact: true,
          icon: Icons.history_rounded,
          title: 'No past appointments',
          message: 'Appointments you have been to are kept here.',
        ),
      AppointmentFilter.cancelled => MedicoEmptyState(
          compact: true,
          icon: Icons.event_busy_outlined,
          title: 'Nothing cancelled',
          message: 'Anything you call off stays here, so there is a record of '
              'it.',
        ),
    };
  }
}

/// The shape of the list while it is on its way.
class _ListSkeleton extends StatelessWidget {
  const _ListSkeleton();

  @override
  Widget build(BuildContext context) {
    return MedicoLoadingRegion(
      label: 'Loading your appointments',
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Insets.gutter),
        child: Column(
          children: [
            for (var i = 0; i < 3; i++) ...[
              MedicoSkeleton(
                width: double.infinity,
                height: 116,
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
