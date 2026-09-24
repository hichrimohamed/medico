import 'package:flutter/material.dart';

import '../../../app/app_scope.dart';
import '../../../app/routes.dart';
import '../../../core/api/api_exception.dart';
import '../../../shared/announce.dart';
import '../../../ui/ui.dart';
import '../../appointments/presentation/appointments_screen.dart';
import '../../auth/data/auth_service.dart';
import '../../doctors/data/availability.dart';
import '../../doctors/data/doctor.dart';
import '../../doctors/data/doctor_repository.dart';
import '../../doctors/data/patient_repository.dart';
import '../../doctors/presentation/saved_doctors_screen.dart';
import '../../doctors/presentation/widgets/doctor_card.dart';
import '../../messages/presentation/messages_screen.dart';
import '../../profile/presentation/profile_screen.dart';
import 'widgets/specialty_rail.dart';

/// The page the patient lands on: who they can see, when, and for how much.
///
/// Everything on it comes from the API — the directory, the specialties in the
/// rail, the saved hearts, and the week of slots under the lead doctor. The
/// repositories are constructor arguments so a test can hand the screen a
/// fixed directory; in the app they come from [AppScope].
class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    this.doctors,
    this.patient,
    this.auth,
    this.patientName,
    this.initialTab = 0,
  });

  final DoctorRepository? doctors;
  final PatientRepository? patient;
  final AuthService? auth;

  /// Overrides the signed-in patient's own name. For tests and previews.
  final String? patientName;

  /// Which destination to open on. A deep link to `/appointments` lands here.
  final int initialTab;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  DoctorRepository get _directory => widget.doctors ?? AppScope.of(context).doctors;
  PatientRepository get _patient => widget.patient ?? AppScope.of(context).patient;
  AuthService get _auth => widget.auth ?? AppScope.of(context).auth;

  Specialty? _specialty;
  late int _navIndex = widget.initialTab;

  List<Specialty> _specialties = const [];
  List<Doctor> _doctors = const [];
  Set<String> _favourites = {};
  List<AvailabilityDay> _leadWeek = const [];

  bool _loading = true;
  String? _error;
  bool _started = false;

  late DateTime _weekStart = _startOfWeek(DateTime.now());
  late DateTime _selectedDay = DateTime.now();

  static DateTime _startOfWeek(DateTime day) {
    final date = DateTime(day.year, day.month, day.day);
    return date.subtract(Duration(days: date.weekday - 1));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // The repositories come from an inherited widget, which is not readable in
    // initState. This runs once.
    if (_started) return;
    _started = true;
    _load();
  }

  String get _patientName =>
      widget.patientName ??
      AppScope.maybeOf(context)?.session.user?.firstName ??
      'there';

  /// Slots free on the day the strip is pointing at.
  int get _leadOpenSlots {
    for (final day in _leadWeek) {
      if (day.sameDayAs(_selectedDay)) return day.openCount;
    }
    return 0;
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // Three independent reads, so they go together rather than in a chain of
      // three round trips.
      final results = await Future.wait([
        _directory.specialtyFields(),
        _directory.list(specialtyField: _specialty?.field),
        _favouritesOrEmpty(),
      ]);
      if (!mounted) return;

      final fields = results[0] as List<String>;
      final doctors = results[1] as List<Doctor>;

      setState(() {
        _specialties =
            fields.map(SpecialtyCatalogue.byField).toList(growable: false);
        _doctors = doctors;
        _favourites = results[2] as Set<String>;
        _loading = false;
      });

      await _loadLeadAvailability();
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.message;
      });
      context.announce(error.message, urgent: true);
    }
  }

  /// Saved doctors need a session. The home screen is only reachable with one,
  /// but a directory that fails to load because the hearts did not would be a
  /// poor trade.
  Future<Set<String>> _favouritesOrEmpty() async {
    if (AppScope.maybeOf(context)?.session.isSignedIn == false) {
      return <String>{};
    }
    try {
      final saved = await _patient.favourites();
      return saved.map((doctor) => doctor.id).toSet();
    } on ApiException {
      return <String>{};
    }
  }

  /// Only the lead doctor's week is fetched: it is the only availability the
  /// screen shows, and asking for all five doctors' diaries to render one
  /// strip would be five requests for one number.
  Future<void> _loadLeadAvailability() async {
    final lead = _doctors.isEmpty ? null : _doctors.first;
    if (lead == null) {
      if (mounted) setState(() => _leadWeek = const []);
      return;
    }

    try {
      final week = await _directory.availability(
        lead.id,
        from: _weekStart,
        days: 7,
      );
      if (!mounted) return;
      setState(() => _leadWeek = week);
    } on ApiException {
      // The card still shows the doctor, the price and the rating. A missing
      // slot count is not worth an error banner over the whole directory.
      if (!mounted) return;
      setState(() => _leadWeek = const []);
    }
  }

  Future<void> _selectSpecialty(Specialty? specialty) async {
    setState(() {
      _specialty = specialty;
      _loading = true;
    });
    try {
      // Filtering is the server's job: it holds the whole directory, and this
      // screen only ever has the page it was given.
      final doctors = await _directory.list(specialtyField: specialty?.field);
      if (!mounted) return;
      setState(() {
        _doctors = doctors;
        _loading = false;
      });
      await _loadLeadAvailability();
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.message;
      });
    }
  }

  Future<void> _changeWeek(int delta) async {
    setState(() {
      _weekStart = _weekStart.add(Duration(days: 7 * delta));
      // Keep the selection inside the week on show, so the strip's count and
      // its highlight always describe the same day.
      _selectedDay = _weekStart;
    });
    await _loadLeadAvailability();
  }

  /// Optimistic: the heart fills on the tap, and puts itself back if the
  /// server disagrees. A save that waits for a round trip feels broken.
  Future<void> _toggleFavourite(Doctor doctor) async {
    final saved = !_favourites.contains(doctor.id);
    setState(() {
      if (saved) {
        _favourites = {..._favourites, doctor.id};
      } else {
        _favourites = {..._favourites}..remove(doctor.id);
      }
    });

    try {
      await _patient.setFavourite(doctor.id, saved: saved);
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        if (saved) {
          _favourites = {..._favourites}..remove(doctor.id);
        } else {
          _favourites = {..._favourites, doctor.id};
        }
      });
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  /// Re-reads the saved set without touching the directory listing.
  Future<void> _reloadFavourites() async {
    final saved = await _favouritesOrEmpty();
    if (!mounted) return;
    setState(() => _favourites = saved);
  }

  void _openDoctor(Doctor doctor) {
    Navigator.of(context).pushNamed(AppRoutes.doctor, arguments: doctor);
  }

  /// Ends the session. The navigation is deliberately not done here: the app
  /// watches the session and moves to sign-in whenever it empties, so a
  /// deliberate sign-out and a refresh token the server revoked end in the
  /// same place by the same path.
  Future<void> _signOut() => _auth.signOut();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    // The floating bar sits over the content, so the scroll view has to end
    // above it or the last card is unreachable.
    final navInset = 52 + Insets.sm + MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: SafeArea(
              bottom: false,
              child: _navIndex == 0
                  ? _Directory(
                      patientName: _patientName,
                      specialties: _specialties,
                      specialty: _specialty,
                      doctors: _doctors,
                      favourites: _favourites,
                      loading: _loading,
                      error: _error,
                      leadOpenSlots: _leadOpenSlots,
                      weekStart: _weekStart,
                      selectedDay: _selectedDay,
                      bottomInset: navInset + Insets.md,
                      onRetry: _load,
                      onSpecialtySelected: _selectSpecialty,
                      onFavouriteToggled: _toggleFavourite,
                      onDoctorTapped: _openDoctor,
                      onDaySelected: (day) =>
                          setState(() => _selectedDay = day),
                      onWeekChanged: _changeWeek,
                      onSignOut: _signOut,
                    )
                  : switch (_navIndex) {
                      1 => AppointmentsScreen(
                          patient: widget.patient,
                          bottomInset: navInset + Insets.md,
                          onFindDoctor: () => setState(() => _navIndex = 0),
                        ),
                      2 => SavedDoctorsScreen(
                          patient: widget.patient,
                          bottomInset: navInset + Insets.md,
                          onFindDoctor: () => setState(() => _navIndex = 0),
                        ),
                      3 => MessagesScreen(
                          bottomInset: navInset + Insets.md,
                        ),
                      4 => ProfileScreen(
                          auth: widget.auth,
                          bottomInset: navInset + Insets.md,
                        ),
                      _ => _Placeholder(
                          destination:
                              MedicoBottomNav.defaultDestinations[_navIndex],
                        ),
                    },
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: navInset + Insets.xl,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      c.canvas.withValues(alpha: 0),
                      c.canvas.withValues(alpha: 0.92),
                      c.canvas,
                    ],
                    stops: const [0, 0.35, 0.62],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: MediaQuery.paddingOf(context).bottom,
            child: MedicoBottomNav(
              index: _navIndex,
              onChanged: (index) {
                final leavingSaved = _navIndex == 2 && index != 2;
                setState(() => _navIndex = index);
                // A heart unsaved on the Saved tab has to be empty on the
                // directory when the patient comes back to it.
                if (leavingSaved) _reloadFavourites();
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _Directory extends StatelessWidget {
  const _Directory({
    required this.patientName,
    required this.specialties,
    required this.specialty,
    required this.doctors,
    required this.favourites,
    required this.loading,
    required this.error,
    required this.leadOpenSlots,
    required this.weekStart,
    required this.selectedDay,
    required this.bottomInset,
    required this.onRetry,
    required this.onSpecialtySelected,
    required this.onFavouriteToggled,
    required this.onDoctorTapped,
    required this.onDaySelected,
    required this.onWeekChanged,
    required this.onSignOut,
  });

  final String patientName;
  final List<Specialty> specialties;
  final Specialty? specialty;
  final List<Doctor> doctors;
  final Set<String> favourites;
  final bool loading;
  final String? error;
  final int leadOpenSlots;
  final DateTime weekStart;
  final DateTime selectedDay;
  final double bottomInset;
  final VoidCallback onRetry;
  final ValueChanged<Specialty?> onSpecialtySelected;
  final ValueChanged<Doctor> onFavouriteToggled;
  final ValueChanged<Doctor> onDoctorTapped;
  final ValueChanged<DateTime> onDaySelected;
  final ValueChanged<int> onWeekChanged;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    final lead = doctors.isEmpty ? null : doctors.first;
    final rest = doctors.length > 1 ? doctors.sublist(1) : const <Doctor>[];

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              Insets.xl,
              Insets.sm,
              Insets.md,
              Insets.xl,
            ),
            child: _Greeting(name: patientName, onSignOut: onSignOut),
          ),
        ),
        if (specialties.isNotEmpty)
          SliverToBoxAdapter(
            child: SpecialtyRail(
              specialties: specialties,
              selected: specialty,
              onSelected: onSpecialtySelected,
            ),
          ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              Insets.xl,
              Insets.lg,
              Insets.xl,
              Insets.sm + 2,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    specialty == null ? 'Top doctors' : specialty!.field,
                    style: context.text.titleLarge,
                  ),
                ),
                if (specialty != null)
                  TextButton(
                    onPressed: () => onSpecialtySelected(null),
                    child: const Text('Clear filter'),
                  )
                else
                  TextButton(
                    onPressed: () => ScaffoldMessenger.of(context)
                      ..clearSnackBars()
                      ..showSnackBar(
                        const SnackBar(
                          content: Text('The full directory is coming next.'),
                        ),
                      ),
                    child: const Text('See all'),
                  ),
              ],
            ),
          ),
        ),
        if (error != null)
          SliverToBoxAdapter(child: _LoadFailed(message: error!, onRetry: onRetry))
        else if (loading)
          const SliverToBoxAdapter(child: _DirectorySkeleton())
        else if (lead == null)
          SliverToBoxAdapter(
            child: _NoResults(
              specialty: specialty,
              onClear: () => onSpecialtySelected(null),
            ),
          )
        else ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: Insets.xl),
              child: FeaturedDoctorCard(
                doctor: lead,
                favourite: favourites.contains(lead.id),
                onFavouriteToggled: () => onFavouriteToggled(lead),
                openSlots: leadOpenSlots,
                weekStart: weekStart,
                selectedDay: selectedDay,
                onDaySelected: onDaySelected,
                onWeekChanged: onWeekChanged,
                onTap: () => onDoctorTapped(lead),
              ),
            ),
          ),
          SliverList.separated(
            itemCount: rest.length,
            separatorBuilder: (_, _) => const SizedBox(height: Insets.sm),
            itemBuilder: (context, index) {
              final doctor = rest[index];
              return Padding(
                padding: EdgeInsets.fromLTRB(
                  Insets.xl,
                  index == 0 ? Insets.sm : 0,
                  Insets.xl,
                  0,
                ),
                child: DoctorListCard(
                  doctor: doctor,
                  favourite: favourites.contains(doctor.id),
                  onFavouriteToggled: () => onFavouriteToggled(doctor),
                  onTap: () => onDoctorTapped(doctor),
                ),
              );
            },
          ),
        ],
        SliverToBoxAdapter(child: SizedBox(height: bottomInset)),
      ],
    );
  }
}

/// The directory's shape while it is on its way.
///
/// The same two card sizes the real content uses, so nothing moves when it
/// lands — and one "Loading" for a screen reader rather than a narration of
/// grey rectangles.
class _DirectorySkeleton extends StatelessWidget {
  const _DirectorySkeleton();

  @override
  Widget build(BuildContext context) {
    return MedicoLoadingRegion(
      label: 'Loading doctors',
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Insets.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            MedicoSkeleton(
              width: double.infinity,
              height: 260,
              radius: BorderRadius.circular(Radii.xl + 4),
            ),
            const SizedBox(height: Insets.md),
            for (var i = 0; i < 3; i++) ...[
              MedicoSkeleton(
                width: double.infinity,
                height: 92,
                radius: BorderRadius.circular(Radii.lg),
              ),
              const SizedBox(height: Insets.sm),
            ],
          ],
        ),
      ),
    );
  }
}

/// The directory could not be fetched. Says so, and offers the one thing that
/// might fix it, rather than leaving an empty page that looks like a clinic
/// with no doctors in it.
class _LoadFailed extends StatelessWidget {
  const _LoadFailed({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(Insets.xl, Insets.md, Insets.xl, 0),
      child: MedicoCard(
        child: MedicoEmptyState.failure(
          title: 'We could not load the directory',
          message: message,
          onAction: onRetry,
        ),
      ),
    );
  }
}

class _Greeting extends StatelessWidget {
  const _Greeting({required this.name, required this.onSignOut});

  final String name;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Hello $name 👋',
                style: context.text.headlineSmall,
              ),
              const SizedBox(height: 2),
              Text(
                'How are you today?',
                style: context.text.bodyLarge
                    ?.copyWith(color: c.inkMuted),
              ),
            ],
          ),
        ),
        CircleAction(
          icon: Icons.search_rounded,
          label: 'Search doctors',
          onPressed: () => _soon(context, 'Search'),
        ),
        const SizedBox(width: Insets.xxs),
        CircleAction(
          icon: Icons.notifications_none_rounded,
          label: 'Notifications',
          badge: true,
          onPressed: () => _soon(context, 'Notifications'),
        ),
        const SizedBox(width: Insets.xxs),
        CircleAction(
          icon: Icons.logout_rounded,
          label: 'Sign out',
          onPressed: () => _signOut(context),
        ),
      ],
    );
  }

  /// Signing out is one tap from the patient's own name, so it is one tap away
  /// from an accidental one too — and on a shared phone, coming back means
  /// typing the password again. Hence the confirmation.
  Future<void> _signOut(BuildContext context) async {
    final confirmed = await showMedicoConfirm(
      context: context,
      title: 'Sign out?',
      message: 'You will need your email and password to sign back in.',
      confirmLabel: 'Sign out',
      cancelLabel: 'Stay signed in',
      destructive: true,
    );
    if (!confirmed || !context.mounted) return;
    onSignOut();
  }

  void _soon(BuildContext context, String what) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text('$what is coming next.')));
  }
}

/// Filtering to a specialty with nobody free is a real state, not an error.
class _NoResults extends StatelessWidget {
  const _NoResults({required this.specialty, required this.onClear});

  final Specialty? specialty;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(Insets.xl, Insets.md, Insets.xl, 0),
      child: MedicoCard(
        child: MedicoEmptyState(
          compact: true,
          icon: specialty?.icon ?? Icons.search_off_rounded,
          title: specialty == null
              ? 'No doctors free this week'
              : 'No ${specialty!.practitioner.toLowerCase()}s free this week',
          message: 'Try another specialty, or call the clinic on 0800 555 100 '
              'and we will find someone for you.',
          actionLabel: 'Show all doctors',
          onAction: onClear,
        ),
      ),
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.destination});

  final NavDestination destination;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: MedicoEmptyState(
        icon: destination.icon,
        title: destination.label,
        message:
            'Not built yet — the directory on Home is the finished screen.',
      ),
    );
  }
}
