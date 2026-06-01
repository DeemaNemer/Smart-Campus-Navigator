import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../config/app_colors.dart';
import '../../models/app_user.dart';
import '../../providers/auth_provider.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final user = authState.user;
    final displayName = user?.fullName ?? user?.username ?? 'Guest User';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
        children: [
          _ProfileHeader(user: user, displayName: displayName),
          const SizedBox(height: 18),
          if (user != null) ...[
            _AccountDetails(user: user),
            const SizedBox(height: 14),
          ],
          _QuickActions(user: user),
          const SizedBox(height: 14),
          _SettingsActions(user: user),
          SizedBox(height: user == null ? 42 : 18),
          if (user == null) const _BackToLoginButton(),
          if (user != null) _SignOutButton(ref: ref),
        ],
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  final AppUser? user;
  final String displayName;

  const _ProfileHeader({required this.user, required this.displayName});

  @override
  Widget build(BuildContext context) {
    final userLabel = user?.userTypeLabel ?? 'Guest';
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 76,
            height: 76,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.primary, AppColors.primaryDark],
              ),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              _initials(displayName),
              style: const TextStyle(
                color: AppColors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                if (user != null)
                  Text(
                    user!.email,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                const SizedBox(height: 10),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    userLabel,
                    style: const TextStyle(
                      color: AppColors.primaryDark,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _initials(String name) {
    final parts = name.trim().split(' ').where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }
}

class _AccountDetails extends StatelessWidget {
  final AppUser user;

  const _AccountDetails({required this.user});

  @override
  Widget build(BuildContext context) {
    return _Section(
      title: 'Account Details',
      children: [
        _InfoTile(
          icon: Icons.alternate_email,
          label: 'Username',
          value: user.username,
        ),
        if (user.studentId != null && user.studentId!.isNotEmpty)
          _InfoTile(
            icon: Icons.badge_outlined,
            label: 'Student ID',
            value: user.studentId!,
          ),
        _InfoTile(
          icon: user.isVerified ? Icons.verified_outlined : Icons.pending,
          label: 'Verification',
          value: user.isVerified ? 'Verified' : 'Not verified',
        ),
      ],
    );
  }
}

class _QuickActions extends StatelessWidget {
  final AppUser? user;

  const _QuickActions({required this.user});

  @override
  Widget build(BuildContext context) {
    final actions = <Widget>[];
    if (user?.canCreateEvents ?? false) {
      actions.add(_ActionTile(
        icon: Icons.event_note,
        label: 'My Events',
        onTap: () => context.push('/events/my'),
      ));
    }
    if (user?.isAdmin ?? false) {
      actions.add(_ActionTile(
        icon: Icons.admin_panel_settings,
        label: 'Admin Panel',
        onTap: () => context.push('/admin'),
      ));
    }
    actions.add(_ActionTile(
      icon: Icons.route_outlined,
      label: 'Outdoor Navigation',
      onTap: () => context.push('/outdoor-navigation'),
    ));

    return _Section(title: 'Shortcuts', children: actions);
  }
}

class _SettingsActions extends StatelessWidget {
  final AppUser? user;

  const _SettingsActions({required this.user});

  @override
  Widget build(BuildContext context) {
    return _Section(
      title: 'Settings',
      children: [
        _ActionTile(
          icon: Icons.privacy_tip_outlined,
          label: 'Privacy Policy',
          onTap: () => context.push('/privacy-policy'),
        ),
        _ActionTile(
          icon: Icons.info_outline,
          label: 'About Smart Campus Navigator',
          onTap: () {
            showAboutDialog(
              context: context,
              applicationName: 'Smart Campus Navigator',
              applicationVersion: '1.0.0',
              applicationLegalese: '2026 Birzeit University',
            );
          },
        ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _Section({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          ...children,
        ],
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primary, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: AppColors.primary),
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
      trailing: const Icon(Icons.chevron_right, color: AppColors.textLight),
      onTap: onTap,
    );
  }
}

class _SignOutButton extends StatelessWidget {
  final WidgetRef ref;

  const _SignOutButton({required this.ref});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () => _confirmLogout(context),
        icon: const Icon(Icons.logout, color: AppColors.error),
        label: const Text(
          'Sign Out',
          style: TextStyle(
            color: AppColors.error,
            fontWeight: FontWeight.bold,
          ),
        ),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          side: const BorderSide(color: AppColors.error),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Sign Out',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(authProvider.notifier).logout();
      if (context.mounted) context.go('/login');
    }
  }
}

class _BackToLoginButton extends StatelessWidget {
  const _BackToLoginButton();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () => context.go('/login'),
        icon: const Icon(Icons.login, color: AppColors.white, size: 20),
        label: const Text(
          'Back to Login Page',
          style: TextStyle(
            color: AppColors.white,
            fontWeight: FontWeight.bold,
            fontSize: 15,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.white,
          elevation: 0,
          minimumSize: const Size.fromHeight(54),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );
  }
}
