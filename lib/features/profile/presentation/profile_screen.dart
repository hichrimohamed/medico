import 'package:flutter/material.dart';

import '../../../app/app_scope.dart';
import '../../../core/api/api_exception.dart';
import '../../../shared/announce.dart';
import '../../../ui/ui.dart';
import '../../auth/data/auth_service.dart';
import '../data/profile.dart';
import '../data/profile_repository.dart';
import 'widgets/account_sheets.dart';

/// The patient's own account: who the clinic has on file, and the few things
/// they can do about it.
///
/// The destructive action lives at the bottom, alone, under its own heading —
/// not in a row of settings where a thumb travelling down the page lands on it
/// by momentum.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    super.key,
    this.profile,
    this.auth,
    this.bottomInset = 0,
  });

  final ProfileRepository? profile;
  final AuthService? auth;

  /// Room for the floating tab bar this screen sits under.
  final double bottomInset;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  ProfileRepository get _repository =>
      widget.profile ?? AppScope.of(context).profile;
  AuthService get _auth => widget.auth ?? AppScope.of(context).auth;

  Profile? _profile;
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
      final profile = await _repository.load();
      if (!mounted) return;
      setState(() {
        _profile = profile;
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

  Future<void> _rename() async {
    final current = _profile;
    if (current == null) return;

    final updated = await showEditNameSheet(
      context: context,
      profile: _repository,
      currentName: current.name,
    );
    if (updated == null || !mounted) return;

    setState(() => _profile = updated);
    showMedicoSnack(context, 'Your name is now ${updated.name}.');
  }

  Future<void> _changePassword() async {
    final changed = await showChangePasswordSheet(
      context: context,
      profile: _repository,
    );
    if (changed != true || !mounted) return;

    showMedicoSnack(
      context,
      'Password changed. You are signed out everywhere else.',
    );
  }

  /// Ends the session. The app watches it and returns to sign-in by itself, so
  /// a deliberate sign-out and a token the server revoked end the same way.
  Future<void> _signOut() async {
    final confirmed = await showMedicoConfirm(
      context: context,
      title: 'Sign out?',
      message: 'You will need your email and password to sign back in.',
      confirmLabel: 'Sign out',
      cancelLabel: 'Stay signed in',
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    await _auth.signOut();
  }

  Future<void> _deleteAccount() async {
    final current = _profile;
    if (current == null) return;

    final deleted = await showDeleteAccountSheet(
      context: context,
      profile: _repository,
      current: current,
    );
    if (deleted != true || !mounted) return;

    // The account is gone, so there is nothing to revoke — the session is
    // dropped locally and the app follows it back to sign-in.
    await AppScope.of(context).session.end();
    if (!mounted) return;
    showMedicoSnack(context, 'Your account has been deleted.');
  }

  @override
  Widget build(BuildContext context) {
    final profile = _profile;

    return RefreshIndicator(
      onRefresh: _load,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          const SliverToBoxAdapter(child: _Header()),
          if (_error != null)
            SliverToBoxAdapter(
              child: _Padded(
                child: MedicoCard(
                  child: MedicoEmptyState.failure(
                    title: 'We could not load your profile',
                    message: _error!,
                    onAction: _load,
                  ),
                ),
              ),
            )
          else if (_loading || profile == null)
            const SliverToBoxAdapter(child: _ProfileSkeleton())
          else ...[
            SliverToBoxAdapter(child: _Identity(profile: profile)),
            SliverToBoxAdapter(child: _Counts(profile: profile)),
            SliverToBoxAdapter(
              child: _Padded(
                child: Padding(
                  padding: const EdgeInsets.only(top: Insets.xl),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const MedicoSectionHeader(title: 'Your account'),
                      MedicoCard(
                        padding: EdgeInsets.zero,
                        child: Column(
                          children: [
                            MedicoListRow(
                              title: 'Name',
                              subtitle: profile.name,
                              leading: const Icon(Icons.badge_outlined),
                              onTap: _rename,
                            ),
                            const MedicoDivider(),
                            MedicoListRow(
                              title: 'Password',
                              subtitle: 'Last changed when you set it',
                              leading: const Icon(Icons.lock_outline_rounded),
                              onTap: _changePassword,
                            ),
                            const MedicoDivider(),
                            MedicoListRow(
                              title: 'Email',
                              subtitle: profile.email,
                              leading: const Icon(Icons.mail_outline_rounded),
                              // Changing it means proving the new address is
                              // theirs, and a half-done change locks a patient
                              // out of their own records.
                              showChevron: false,
                              onTap: null,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: Insets.xl),
                      MedicoButton.secondary(
                        label: 'Sign out',
                        icon: Icons.logout_rounded,
                        onPressed: _signOut,
                      ),
                      const SizedBox(height: Insets.xxl),
                      _DangerZone(onDelete: _deleteAccount),
                    ],
                  ),
                ),
              ),
            ),
          ],
          SliverToBoxAdapter(child: SizedBox(height: widget.bottomInset)),
        ],
      ),
    );
  }
}

/// The one irreversible action, kept apart from everything else.
class _DangerZone extends StatelessWidget {
  const _DangerZone({required this.onDelete});

  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const MedicoSectionHeader(title: 'Leaving Medico'),
        MedicoCard(
          variant: MedicoCardVariant.outlined,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Deleting your account removes your appointments, your '
                'messages and your history. It cannot be undone.',
                style: context.text.bodyMedium?.copyWith(color: c.inkBody),
              ),
              const SizedBox(height: Insets.md),
              Align(
                alignment: Alignment.centerLeft,
                child: MedicoButton.danger(
                  label: 'Delete account',
                  icon: Icons.delete_outline_rounded,
                  onPressed: onDelete,
                  size: MedicoButtonSize.medium,
                  expand: false,
                ),
              ),
            ],
          ),
        ),
      ],
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Insets.gutter,
        Insets.sm,
        Insets.gutter,
        Insets.lg,
      ),
      child: Semantics(
        header: true,
        child: Text('Profile', style: context.text.headlineSmall),
      ),
    );
  }
}

/// Who the clinic has on file.
class _Identity extends StatelessWidget {
  const _Identity({required this.profile});

  final Profile profile;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final since = profile.memberSinceLabel;

    return _Padded(
      child: MedicoCard(
        semanticLabel: [
          profile.name,
          profile.email,
          if (since != null) 'with Medico since $since',
        ].join('. '),
        child: Row(
          children: [
            ExcludeSemantics(child: MedicoAvatar(name: profile.name, size: 60)),
            const SizedBox(width: Insets.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    profile.name,
                    style: context.text.titleLarge,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    profile.email,
                    style: context.text.bodyMedium
                        ?.copyWith(color: c.inkMuted),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (since != null) ...[
                    const SizedBox(height: Insets.xxs),
                    Text(
                      'With Medico since $since',
                      style: context.text.bodySmall
                          ?.copyWith(color: c.inkMuted),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Three numbers the patient can act on, each a place they have already been.
class _Counts extends StatelessWidget {
  const _Counts({required this.profile});

  final Profile profile;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: Insets.sm),
      child: _Padded(
        child: Row(
          children: [
            Expanded(
              child: _CountTile(
                icon: Icons.calendar_month_rounded,
                value: profile.upcomingAppointments,
                label: 'Upcoming',
              ),
            ),
            const SizedBox(width: Insets.sm),
            Expanded(
              child: _CountTile(
                icon: Icons.favorite_rounded,
                value: profile.savedDoctors,
                label: 'Saved',
              ),
            ),
            const SizedBox(width: Insets.sm),
            Expanded(
              child: _CountTile(
                icon: Icons.chat_bubble_rounded,
                value: profile.unreadThreads,
                label: 'Unread',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CountTile extends StatelessWidget {
  const _CountTile({
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final int value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Semantics(
      container: true,
      label: '$value $label',
      excludeSemantics: true,
      child: MedicoCard(
        padding: const EdgeInsets.symmetric(
          horizontal: Insets.sm,
          vertical: Insets.md,
        ),
        child: Column(
          children: [
            Icon(icon, size: IconSize.md, color: c.brand.ink),
            const SizedBox(height: Insets.xs),
            Text('$value', style: context.text.titleLarge),
            Text(
              label,
              style: context.text.bodySmall?.copyWith(color: c.inkMuted),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileSkeleton extends StatelessWidget {
  const _ProfileSkeleton();

  @override
  Widget build(BuildContext context) {
    return MedicoLoadingRegion(
      label: 'Loading your profile',
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Insets.gutter),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            MedicoSkeleton(
              width: double.infinity,
              height: 100,
              radius: Radii.xlAll,
            ),
            const SizedBox(height: Insets.sm),
            MedicoSkeleton(
              width: double.infinity,
              height: 96,
              radius: Radii.xlAll,
            ),
            const SizedBox(height: Insets.xl),
            MedicoSkeleton(
              width: double.infinity,
              height: 168,
              radius: Radii.xlAll,
            ),
          ],
        ),
      ),
    );
  }
}
