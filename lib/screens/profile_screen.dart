import 'package:flutter/material.dart';

import '../models/user.dart';
import '../services/user_service.dart';
import 'cart_screen.dart';

//Enhancement 3
// Profile and cart navigation use the account persisted by UserService.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, this.userService});

  final UserService? userService;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late final UserService _userService = widget.userService ?? UserService();
  // Enhancement 3: Always fetch the provider-aware snapshot through
  // UserService.getUserData instead of reading preferences in the UI.
  late Future<User> _user = _loadUser();
  bool _isSigningOut = false;

  Future<User> _loadUser() async =>
      User.fromJson(await _userService.getUserData());

  Future<void> _signOut() async {
    if (_isSigningOut) return;
    setState(() => _isSigningOut = true);
    try {
      await _userService.logout();
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, '/signin', (_) => false);
    } catch (_) {
      if (!mounted) return;
      setState(() => _isSigningOut = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to sign out. Please try again.')),
      );
    }
  }

  Future<void> _updateUsername(User user) async {
    final controller = TextEditingController(text: user.username);
    final username = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Update username'),
        content: TextField(
          key: const Key('profile_username_input'),
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Username'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (username == null || username.length < 3) return;
    await _runAccountAction(() async {
      await _userService.updateUsername(username: username);
      setState(() => _user = _loadUser());
    }, success: 'Username updated.');
  }

  Future<void> _changePassword(User user) async {
    final current = TextEditingController();
    final replacement = TextEditingController();
    final values = await showDialog<List<String>>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change password'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              key: const Key('current_password_input'),
              controller: current,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Current password'),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('new_password_input'),
              controller: replacement,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'New password (8+ characters)',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(context, [current.text, replacement.text]),
            child: const Text('Change'),
          ),
        ],
      ),
    );
    current.dispose();
    replacement.dispose();
    if (values == null || values[0].isEmpty || values[1].length < 8) return;
    await _runAccountAction(
      () => _userService.resetPasswordFromCurrentPassword(
        currentPassword: values[0],
        newPassword: values[1],
        email: user.email,
      ),
      success: 'Password changed.',
    );
  }

  Future<void> _deleteAccount(User user) async {
    final password = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete account?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('This permanently deletes your Firebase account.'),
            const SizedBox(height: 12),
            TextField(
              key: const Key('delete_password_input'),
              controller: password,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Confirm your password',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    final enteredPassword = password.text;
    password.dispose();
    if (confirmed != true || enteredPassword.isEmpty) return;
    try {
      await _userService.deleteAccount(
        email: user.email,
        password: enteredPassword,
      );
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, '/signin', (_) => false);
    } catch (error) {
      if (!mounted) return;
      _showMessage(error.toString());
    }
  }

  Future<void> _runAccountAction(
    Future<void> Function() action, {
    required String success,
  }) async {
    try {
      await action();
      if (mounted) _showMessage(success);
    } catch (error) {
      if (mounted) _showMessage(error.toString());
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message.replaceFirst('Exception: ', ''))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Profile'), centerTitle: false),
      body: FutureBuilder<User>(
        future: _user,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator.adaptive());
          }
          final user = snapshot.data;
          if (snapshot.hasError || user == null || !user.hasSession) {
            return _ProfileError(
              onRetry: () => setState(() => _user = _loadUser()),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              final refreshed = _loadUser();
              setState(() => _user = refreshed);
              await refreshed;
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                _ProfileHeader(user: user),
                const SizedBox(height: 24),
                const _SectionTitle(
                  title: 'Account details',
                  subtitle: 'Your personal and sign-in information',
                ),
                const SizedBox(height: 10),
                Card(
                  margin: EdgeInsets.zero,
                  elevation: 0,
                  color: colors.surfaceContainerLow,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: [
                      _ProfileDetail(
                        icon: Icons.alternate_email_rounded,
                        label: 'Email',
                        value: user.email,
                      ),
                      const _ProfileDivider(),
                      _ProfileDetail(
                        icon: Icons.verified_user_outlined,
                        label: 'Login type',
                        value: user.loginType.label,
                      ),
                      const _ProfileDivider(),
                      _ProfileDetail(
                        icon: Icons.badge_outlined,
                        label: 'User ID',
                        value: user.loginType == LoginType.firebase
                            ? user.firebaseUid
                            : '${user.id}',
                      ),
                      if (user.gender.isNotEmpty) ...[
                        const _ProfileDivider(),
                        _ProfileDetail(
                          icon: Icons.person_outline_rounded,
                          label: 'Gender',
                          value: user.gender,
                        ),
                      ],
                      if (user.age != null) ...[
                        const _ProfileDivider(),
                        _ProfileDetail(
                          icon: Icons.cake_outlined,
                          label: 'Age',
                          value: '${user.age}',
                        ),
                      ],
                      if (user.contactNo.isNotEmpty) ...[
                        const _ProfileDivider(),
                        _ProfileDetail(
                          icon: Icons.phone_outlined,
                          label: 'Contact number',
                          value: user.contactNo,
                        ),
                      ],
                    ],
                  ),
                ),
                if (user.loginType == LoginType.firebase) ...[
                  const SizedBox(height: 24),
                  const _SectionTitle(
                    title: 'Account settings',
                    subtitle: 'Manage your Firebase account',
                  ),
                  const SizedBox(height: 10),
                  Card(
                    margin: EdgeInsets.zero,
                    elevation: 0,
                    color: colors.surfaceContainerLow,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      children: [
                        _ProfileAction(
                          key: const Key('update_username'),
                          icon: Icons.edit_outlined,
                          title: 'Update username',
                          subtitle: 'Change how your name appears',
                          onTap: () => _updateUsername(user),
                        ),
                        const _ProfileDivider(),
                        _ProfileAction(
                          key: const Key('change_password'),
                          icon: Icons.lock_reset_rounded,
                          title: 'Change password',
                          subtitle: 'Choose a new account password',
                          onTap: () => _changePassword(user),
                        ),
                        const _ProfileDivider(),
                        _ProfileAction(
                          key: const Key('delete_account'),
                          icon: Icons.delete_outline_rounded,
                          title: 'Delete account',
                          subtitle: 'Permanently remove your account',
                          foregroundColor: colors.error,
                          onTap: () => _deleteAccount(user),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                SizedBox(
                  height: 52,
                  child: FilledButton.icon(
                    onPressed: _isSigningOut
                        ? null
                        : () => Navigator.push(
                            context,
                            MaterialPageRoute<void>(
                              builder: (_) => CartScreen(userId: user.id),
                            ),
                          ),
                    icon: const Icon(Icons.shopping_bag_outlined),
                    label: const Text('View my cart'),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 52,
                  child: OutlinedButton.icon(
                    onPressed: _isSigningOut ? null : _signOut,
                    icon: _isSigningOut
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.logout_rounded),
                    label: Text(_isSigningOut ? 'Signing out...' : 'Sign out'),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.user});

  final User user;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final username = user.username.trim();
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [colors.primary, colors.primary.withValues(alpha: .78)],
        ),
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: colors.primary.withValues(alpha: .18),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 82,
            height: 82,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: colors.onPrimary.withValues(alpha: .22),
              shape: BoxShape.circle,
            ),
            child: ClipOval(
              child: ColoredBox(
                color: colors.surface,
                child: user.image.isEmpty
                    ? Icon(
                        Icons.person_rounded,
                        size: 48,
                        color: colors.primary,
                      )
                    : Image.network(
                        user.image,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Icon(
                          Icons.person_rounded,
                          size: 48,
                          color: colors.primary,
                        ),
                      ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            user.fullName.isEmpty ? 'Your profile' : user.fullName,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: colors.onPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (username.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              '@$username',
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: colors.onPrimary.withValues(alpha: .84)),
            ),
          ],
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: colors.onPrimary.withValues(alpha: .16),
              borderRadius: BorderRadius.circular(99),
            ),
            child: Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 5,
              children: [
                Icon(
                  Icons.verified_outlined,
                  size: 14,
                  color: colors.onPrimary,
                ),
                Text(
                  '${user.loginType.label} account',
                  style: TextStyle(
                    color: colors.onPrimary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 4),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    ),
  );
}

class _ProfileAction extends StatelessWidget {
  const _ProfileAction({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.foregroundColor,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Color? foregroundColor;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final foreground = foregroundColor ?? colors.onSurface;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
      leading: _ProfileIcon(icon: icon, color: foreground),
      title: Text(
        title,
        style: TextStyle(fontWeight: FontWeight.w600, color: foreground),
      ),
      subtitle: Text(subtitle),
      trailing: Icon(
        Icons.chevron_right_rounded,
        color: foreground.withValues(alpha: .7),
      ),
      onTap: onTap,
    );
  }
}

class _ProfileError extends StatelessWidget {
  const _ProfileError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.person_off_outlined,
            size: 52,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 12),
          const Text('Unable to load your profile.'),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Retry'),
          ),
        ],
      ),
    ),
  );
}

class _ProfileDetail extends StatelessWidget {
  const _ProfileDetail({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ProfileIcon(icon: icon, color: colors.primary),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: colors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value.isEmpty ? 'Not provided' : value,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileIcon extends StatelessWidget {
  const _ProfileIcon({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: 40,
    height: 40,
    decoration: BoxDecoration(
      color: color.withValues(alpha: .11),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Icon(icon, size: 21, color: color),
  );
}

class _ProfileDivider extends StatelessWidget {
  const _ProfileDivider();

  @override
  Widget build(BuildContext context) => Divider(
    height: 1,
    indent: 67,
    endIndent: 14,
    color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: .55),
  );
}
