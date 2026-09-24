import 'package:flutter/material.dart';

import '../../../app/app_scope.dart';
import '../../../core/api/api_exception.dart';
import '../../../shared/announce.dart';
import '../../../shared/reduced_motion.dart';
import '../../../ui/ui.dart';
import '../data/availability.dart';
import '../data/doctor.dart';
import '../data/doctor_repository.dart';
import '../data/patient_repository.dart';
import 'widgets/detail_sections.dart';

enum DetailTab {
  about('About'),
  availability('Availability'),
  experience('Experience'),
  education('Education'),
  reviews('Reviews');

  const DetailTab(this.label);
  final String label;
}

/// Everything a patient needs before committing to an appointment, ending in
/// the one action the screen exists for.
///
/// Reached two ways: with the [Doctor] already in hand from a card on the home
/// screen, or with nothing but an [doctorId] from a link or a notification. In
/// the second case the doctor is fetched here, which is why this screen has a
/// loading state at all.
class DoctorDetailScreen extends StatefulWidget {
  const DoctorDetailScreen({
    super.key,
    this.doctor,
    this.doctorId,
    this.doctors,
    this.patient,
  }) : assert(
          doctor != null || doctorId != null,
          'A doctor, or an id to fetch one with.',
        );

  final Doctor? doctor;
  final String? doctorId;

  final DoctorRepository? doctors;
  final PatientRepository? patient;

  @override
  State<DoctorDetailScreen> createState() => _DoctorDetailScreenState();
}

class _DoctorDetailScreenState extends State<DoctorDetailScreen> {
  DoctorRepository get _directory =>
      widget.doctors ?? AppScope.of(context).doctors;
  PatientRepository get _patient => widget.patient ?? AppScope.of(context).patient;

  DetailTab _tab = DetailTab.about;
  bool _bioExpanded = false;
  bool _favourite = false;
  bool _started = false;

  Doctor? _doctor;
  String? _doctorError;

  List<AvailabilityDay> _week = const [];
  bool _loadingSlots = true;
  AvailabilitySlot? _slot;
  bool _booking = false;

  late DateTime _day = DateTime.now();

  Doctor? get doctor => _doctor ?? widget.doctor;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _load();
  }

  Future<void> _load() async {
    setState(() => _doctorError = null);

    if (doctor == null) {
      try {
        final fetched = await _directory.byId(widget.doctorId!);
        if (!mounted) return;
        setState(() => _doctor = fetched);
      } on ApiException catch (error) {
        if (!mounted) return;
        setState(() {
          _doctorError = error.message;
          _loadingSlots = false;
        });
        return;
      }
    }

    await Future.wait([_loadAvailability(), _loadFavourite()]);
  }

  Future<void> _loadAvailability() async {
    final id = doctor?.id;
    if (id == null) return;
    setState(() => _loadingSlots = true);

    try {
      // A week from today, which is exactly what the day picker offers. The
      // slots themselves are generated on read by the server, so this is the
      // only place that knows what is actually free.
      final week = await _directory.availability(id, days: 7);
      if (!mounted) return;
      setState(() {
        _week = week;
        _loadingSlots = false;
        // A slot chosen before a reload may be gone — somebody else can have
        // taken it in between, and the safest thing to do with a selection
        // that no longer exists is drop it.
        _slot = null;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _week = const [];
        _loadingSlots = false;
      });
      _say(error.message);
    }
  }

  Future<void> _loadFavourite() async {
    final id = doctor?.id;
    if (id == null) return;
    try {
      final saved = await _patient.favourites();
      if (!mounted) return;
      setState(() => _favourite = saved.any((doctor) => doctor.id == id));
    } on ApiException {
      // An unknown save state shows as unsaved. Tapping it will say so.
    }
  }

  /// Optimistic, and reverted if the server disagrees — the same bargain the
  /// heart on the home screen makes.
  Future<void> _toggleFavourite() async {
    final id = doctor?.id;
    if (id == null) return;

    final saved = !_favourite;
    setState(() => _favourite = saved);
    try {
      await _patient.setFavourite(id, saved: saved);
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _favourite = !saved);
      _say(error.message);
    }
  }

  /// The slots for the day the picker is on.
  AvailabilityDay? get _selectedDay {
    for (final day in _week) {
      if (day.sameDayAs(_day)) return day;
    }
    return null;
  }

  Future<void> _next() async {
    final current = doctor;
    final slot = _slot;

    if (current == null) return;
    if (slot == null) {
      // Nothing to confirm yet — send them to the only tab that can fix that.
      setState(() => _tab = DetailTab.availability);
      return;
    }

    setState(() => _booking = true);
    try {
      await _patient.book(doctorId: current.id, startsAt: slot.startsAt);
      if (!mounted) return;
      setState(() => _booking = false);
      _say(
        'Booked ${kWeekdayNames[_day.weekday - 1]} '
        '${_day.day} ${kMonthNames[_day.month - 1].substring(0, 3)} '
        'at ${slot.label} with ${current.name}.',
      );
      // The slot is gone now — for this patient and for everyone else looking
      // at the same diary.
      await _loadAvailability();
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _booking = false);
      _say(error.message);
      // Somebody else got there first, or the time has passed while the screen
      // was open. Either way the diary on screen is out of date.
      if (error.code == ApiErrorCode.slotTaken ||
          error.code == ApiErrorCode.slotInPast) {
        await _loadAvailability();
      }
    }
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
    final c = context.colors;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final barHeight = 52 + Insets.md * 2 + bottomInset;
    final current = doctor;

    if (current == null) {
      return Scaffold(
        appBar: const MedicoAppBar(),
        body: Center(
          child: _doctorError == null
              ? const MedicoLoadingRegion(
                  label: 'Loading doctor',
                  child: CircularProgressIndicator.adaptive(),
                )
              : MedicoEmptyState(
                  icon: Icons.cloud_off_rounded,
                  title: 'We could not open that doctor',
                  message: _doctorError!,
                  actionLabel: 'Try again',
                  onAction: _load,
                ),
        ),
      );
    }

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(child: _TopBar(
                  favourite: _favourite,
                  onFavouriteToggled: _toggleFavourite,
                  doctorName: current.name,
                )),
                SliverToBoxAdapter(child: DoctorHero(doctor: current)),
                SliverToBoxAdapter(child: StatTiles(doctor: current)),
                // Breathing room so the tiles are not clipped by the sheet
                // that slides up underneath them.
                const SliverToBoxAdapter(child: SizedBox(height: Insets.lg)),
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _TabStripHeader(
                    selected: _tab,
                    onSelected: (tab) => setState(() => _tab = tab),
                  ),
                ),
                SliverToBoxAdapter(
                  child: ColoredBox(
                    color: c.surface,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                        Insets.xl,
                        Insets.md,
                        Insets.xl,
                        Insets.xl,
                      ),
                      child: _panel(current),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: barHeight,
                    child: ColoredBox(color: c.surface),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _ActionBar(
              label: _slot == null
                  ? 'Next'
                  : 'Confirm ${kWeekdayNames[_day.weekday - 1]} '
                      '${_day.day} · ${_slot!.label}',
              busy: _booking,
              onPressed: _booking ? null : _next,
              bottomInset: bottomInset,
            ),
          ),
        ],
      ),
    );
  }

  Widget _panel(Doctor current) {
    return switch (_tab) {
      DetailTab.about => _About(
          doctor: current,
          expanded: _bioExpanded,
          onToggle: () => setState(() => _bioExpanded = !_bioExpanded),
        ),
      DetailTab.availability => _Availability(
          day: _day,
          week: _week,
          loading: _loadingSlots,
          slot: _slot,
          slots: _selectedDay?.slots ?? const [],
          onDaySelected: (day) => setState(() {
            _day = day;
            _slot = null;
          }),
          onSlotSelected: (slot) => setState(() => _slot = slot),
        ),
      DetailTab.experience => _Credentials(
          items: current.experience,
          empty: 'No roles on file yet.',
        ),
      DetailTab.education => _Credentials(
          items: current.education,
          empty: 'No qualifications on file yet.',
        ),
      DetailTab.reviews => _Reviews(doctor: current),
    };
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.favourite,
    required this.onFavouriteToggled,
    required this.doctorName,
  });

  final bool favourite;
  final VoidCallback onFavouriteToggled;
  final String doctorName;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Insets.md, Insets.xs, Insets.md, 0),
        child: Row(
          children: [
            CircleAction(
              icon: Icons.arrow_back_rounded,
              label: 'Back',
              onPressed: () => Navigator.of(context).maybePop(),
            ),
            const Spacer(),
            CircleAction(
              icon: favourite
                  ? Icons.favorite_rounded
                  : Icons.favorite_border_rounded,
              label: favourite ? 'Remove from saved' : 'Save this doctor',
              iconColor: favourite ? c.brand.solid : c.ink,
              onPressed: onFavouriteToggled,
            ),
            const SizedBox(width: Insets.xxs),
            CircleAction(
              icon: Icons.ios_share_rounded,
              label: 'Share',
              onPressed: () {
                // TODO(share): hand to the platform share sheet.
                ScaffoldMessenger.of(context)
                  ..clearSnackBars()
                  ..showSnackBar(
                    SnackBar(content: Text('Sharing $doctorName is coming next.')),
                  );
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Pinned so the patient can change section without scrolling back up.
class _TabStripHeader extends SliverPersistentHeaderDelegate {
  _TabStripHeader({required this.selected, required this.onSelected});

  final DetailTab selected;
  final ValueChanged<DetailTab> onSelected;

  static const double _height = 58;

  @override
  double get minExtent => _height;

  @override
  double get maxExtent => _height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      height: _height,
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(Radii.xl + 6),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: Insets.xl),
        children: [
          for (final tab in DetailTab.values)
            _Tab(
              tab: tab,
              selected: tab == selected,
              onTap: () => onSelected(tab),
            ),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _TabStripHeader oldDelegate) =>
      oldDelegate.selected != selected;
}

class _Tab extends StatelessWidget {
  const _Tab({required this.tab, required this.selected, required this.onTap});

  final DetailTab tab;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      button: true,
      selected: selected,
      label: tab.label,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: Insets.sm),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),
              Text(
                tab.label,
                style: context.text.labelLarge?.copyWith(
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? c.brand.solid : c.inkMuted,
                ),
              ),
              const SizedBox(height: Insets.xs),
              AnimatedContainer(
                duration: context.motion(Motion.base),
                curve: Motion.easeOut,
                height: 3,
                width: selected ? 30 : 0,
                decoration: BoxDecoration(
                  color: c.brand.solid,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(2),
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

class _About extends StatelessWidget {
  const _About({
    required this.doctor,
    required this.expanded,
    required this.onToggle,
  });

  final Doctor doctor;
  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AnimatedSize(
          duration: context.motion(Motion.base),
          curve: Motion.easeOut,
          alignment: Alignment.topCenter,
          child: Text(
            doctor.bio,
            maxLines: expanded ? null : 4,
            overflow: expanded ? null : TextOverflow.ellipsis,
            style: context.text.bodyLarge?.copyWith(height: 1.55),
          ),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: onToggle,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: Insets.xs),
              minimumSize: const Size(0, Layout.minTapTarget),
            ),
            child: Text(expanded ? 'Show less' : 'Read more'),
          ),
        ),
        const SizedBox(height: Insets.xs),
        // IntrinsicHeight: the tiles stretch to match each other, and a Row
        // cannot stretch inside a Column with unbounded height without it.
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: FactTile(
                  icon: Icons.payments_outlined,
                  label: 'Session fee',
                  value: '\$${doctor.pricePerSession}',
                ),
              ),
              const SizedBox(width: Insets.sm),
              Expanded(
                child: FactTile(
                  icon: Icons.replay_rounded,
                  label: 'Follow-up fee',
                  value: '\$${doctor.followUpFee}',
                  note: 'within ${doctor.followUpWindowDays} days',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: Insets.sm),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: FactTile(
                  icon: Icons.schedule_rounded,
                  label: 'Average session',
                  value: '${doctor.sessionMinutes} min',
                ),
              ),
              const SizedBox(width: Insets.sm),
              Expanded(
                child: FactTile(
                  icon: Icons.groups_outlined,
                  label: 'Patients seen',
                  value: doctor.patientCountLabel,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Availability extends StatelessWidget {
  const _Availability({
    required this.day,
    required this.week,
    required this.loading,
    required this.slot,
    required this.slots,
    required this.onDaySelected,
    required this.onSlotSelected,
  });

  final DateTime day;

  /// The doctor's week, as the server generated it. The day picker is built
  /// from this rather than from `DateTime.now()` plus seven, so a day the
  /// clinic does not open is a day with no slots rather than a day with
  /// twelve that all fail to book.
  final List<AvailabilityDay> week;

  final bool loading;
  final AvailabilitySlot? slot;
  final List<AvailabilitySlot> slots;
  final ValueChanged<DateTime> onDaySelected;
  final ValueChanged<AvailabilitySlot> onSlotSelected;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const MedicoLoadingRegion(
        label: 'Loading availability',
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: Insets.xl),
          child: Center(child: CircularProgressIndicator.adaptive()),
        ),
      );
    }

    if (week.isEmpty) {
      return const MedicoEmptyState(
        compact: true,
        icon: Icons.event_busy_outlined,
        title: 'No times to show',
        message: 'We could not load this doctor’s diary. Pull down to try '
            'again, or call the clinic on 0800 555 100.',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Pick a day', style: context.text.titleMedium),
        const SizedBox(height: Insets.sm),
        SizedBox(
          height: 66,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: week.length,
            separatorBuilder: (_, _) => const SizedBox(width: Insets.xs),
            itemBuilder: (context, index) {
              final value = week[index];
              return _DayButton(
                day: value.date,
                selected: value.sameDayAs(day),
                onTap: () => onDaySelected(value.date),
              );
            },
          ),
        ),
        const SizedBox(height: Insets.lg),
        Text('Pick a time', style: context.text.titleMedium),
        const SizedBox(height: Insets.sm),
        if (slots.isEmpty)
          Text(
            'The clinic is closed this day.',
            style: context.text.bodyMedium,
          )
        else
          Wrap(
            spacing: Insets.xs,
            runSpacing: Insets.xs,
            children: [
              for (final time in slots)
                _SlotChip(
                  time: time.label,
                  selected: time.startsAt == slot?.startsAt,
                  taken: !time.available,
                  onTap: () => onSlotSelected(time),
                ),
            ],
          ),
        const SizedBox(height: Insets.sm),
        Text(
          'Times are the clinic’s own.',
          style: context.text.bodySmall,
        ),

      ],
    );
  }
}

class _DayButton extends StatelessWidget {
  const _DayButton({
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
        borderRadius: BorderRadius.circular(Radii.lg),
        child: AnimatedContainer(
          duration: context.motion(Motion.base),
          curve: Motion.easeOut,
          width: 58,
          padding: const EdgeInsets.symmetric(vertical: Insets.xs),
          decoration: BoxDecoration(
            color: selected ? c.brand.solid : c.brand.container,
            borderRadius: BorderRadius.circular(Radii.lg),
            border: Border.all(
              color: selected ? c.brand.solid : c.line,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                weekday,
                style: context.text.labelSmall?.copyWith(
                  color: selected ? c.brand.container : c.inkMuted,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${day.day}',
                style: context.text.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: selected ? c.brand.onSolid : c.ink,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SlotChip extends StatelessWidget {
  const _SlotChip({
    required this.time,
    required this.selected,
    required this.taken,
    required this.onTap,
  });

  final String time;
  final bool selected;
  final bool taken;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final background = taken
        ? c.canvas
        : selected
            ? c.brand.solid
            : c.surface;
    final foreground = taken
        ? c.inkDisabled
        : selected
            ? c.brand.onSolid
            : c.inkBody;

    return Semantics(
      button: !taken,
      selected: selected,
      enabled: !taken,
      label: taken ? '$time, already booked' : time,
      excludeSemantics: true,
      child: InkWell(
        onTap: taken ? null : onTap,
        borderRadius: BorderRadius.circular(Radii.md),
        child: AnimatedContainer(
          duration: context.motion(Motion.fast),
          curve: Motion.easeOut,
          padding: const EdgeInsets.symmetric(
            horizontal: Insets.md,
            vertical: Insets.sm,
          ),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(Radii.md),
            border: Border.all(
              color: selected ? c.brand.solid : c.control,
            ),
          ),
          child: Text(
            time,
            style: context.text.labelMedium?.copyWith(
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: foreground,
              decoration: taken ? TextDecoration.lineThrough : null,
            ),
          ),
        ),
      ),
    );
  }
}

class _Credentials extends StatelessWidget {
  const _Credentials({required this.items, required this.empty});

  final List<Credential> items;
  final String empty;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Text(empty, style: Theme.of(context).textTheme.bodyLarge);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < items.length; i++)
          CredentialRow(credential: items[i], last: i == items.length - 1),
      ],
    );
  }
}

class _Reviews extends StatelessWidget {
  const _Reviews({required this.doctor});

  final Doctor doctor;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    if (doctor.reviews.isEmpty) {
      return Text(
        'No reviews yet. You could be the first after your appointment.',
        style: context.text.bodyLarge,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              doctor.rating.toStringAsFixed(1),
              style: context.text.displaySmall,
            ),
            const SizedBox(width: Insets.sm),
            Expanded(
              child: Text(
                'from ${doctor.reviews.length} patients who saw '
                '${doctor.name.split(' ').last}',
                style: context.text.bodyMedium
                    ?.copyWith(color: c.inkMuted),
              ),
            ),
          ],
        ),
        const SizedBox(height: Insets.md),
        for (final review in doctor.reviews) ...[
          ReviewCard(review: review),
          const SizedBox(height: Insets.sm),
        ],
      ],
    );
  }
}

/// The one commitment on the screen, always reachable without scrolling.
class _ActionBar extends StatelessWidget {
  const _ActionBar({
    required this.label,
    required this.onPressed,
    required this.bottomInset,
    this.busy = false,
  });

  final String label;

  /// Null while the booking is in flight — a second tap would be a second
  /// appointment, and the server's unique index would reject it as a clash
  /// with the patient's own.
  final VoidCallback? onPressed;
  final double bottomInset;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: EdgeInsets.fromLTRB(
        Insets.xl,
        Insets.md,
        Insets.xl,
        Insets.md + bottomInset,
      ),
      decoration: BoxDecoration(
        color: c.surface,
        boxShadow: [
          BoxShadow(
            color: c.ink.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
        ),
        child: busy
            ? const SizedBox.square(
                dimension: IconSize.md,
                child: CircularProgressIndicator.adaptive(strokeWidth: 2),
              )
            : Text(label),
      ),
    );
  }
}
