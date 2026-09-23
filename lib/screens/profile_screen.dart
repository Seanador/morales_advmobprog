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
    return FutureBuilder<User>(
      future: _user,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        final user = snapshot.data;
        if (snapshot.hasError || user == null || !user.hasSession) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Unable to load your profile.'),
                TextButton(
                  onPressed: () =>
                      setState(() => _user = _userService.getUser()),
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }
        return ListView(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: colors.primaryContainer,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                children: [
                  ClipOval(
                    child: SizedBox(
                      width: 88,
                      height: 88,
                      child: ColoredBox(
                        color: colors.surface,
                        child: user.image.isEmpty
                            ? const Icon(Icons.person_outline, size: 48)
                            : Image.network(
                                user.image,
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) =>
                                    const Icon(Icons.person_outline, size: 48),
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    user.fullName,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colors.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '@${user.username}',
                    style: TextStyle(color: colors.onPrimaryContainer),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            Text(
              'Account details',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Card(
              margin: EdgeInsets.zero,
              child: Column(
                children: [
                  _ProfileDetail(
                    icon: Icons.login_outlined,
                    label: 'Login type',
                    value: user.loginType.label,
                  ),
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  _ProfileDetail(
                    icon: Icons.email_outlined,
                    label: 'Email',
                    value: user.email,
                  ),
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  _ProfileDetail(
                    icon: Icons.badge_outlined,
                    label: 'User ID',
                    value: user.loginType == LoginType.firebase
                        ? user.firebaseUid
                        : '${user.id}',
                  ),
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  _ProfileDetail(
                    icon: Icons.person_outline,
                    label: 'Gender',
                    value: user.gender,
                  ),
                  if (user.age != null) ...[
                    const Divider(height: 1, indent: 16, endIndent: 16),
                    _ProfileDetail(
                      icon: Icons.cake_outlined,
                      label: 'Age',
                      value: '${user.age}',
                    ),
                  ],
                  if (user.contactNo.isNotEmpty) ...[
                    const Divider(height: 1, indent: 16, endIndent: 16),
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
              Text(
                'Firebase account',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                key: const Key('update_username'),
                onPressed: () => _updateUsername(user),
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Update username'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                key: const Key('change_password'),
                onPressed: () => _changePassword(user),
                icon: const Icon(Icons.password_outlined),
                label: const Text('Change password'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                key: const Key('delete_account'),
                onPressed: () => _deleteAccount(user),
                icon: const Icon(Icons.delete_forever_outlined),
                label: const Text('Delete account'),
                style: OutlinedButton.styleFrom(foregroundColor: colors.error),
              ),
            ],
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _isSigningOut
                  ? null
                  : () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CartScreen(userId: user.id),
                      ),
                    ),
              icon: const Icon(Icons.shopping_bag_outlined),
              label: const Text('View my cart'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _isSigningOut ? null : _signOut,
              icon: _isSigningOut
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.logout),
              label: Text(_isSigningOut ? 'Signing out...' : 'Sign out'),
            ),
          ],
        );
      },
    );
  }
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
  Widget build(BuildContext context) => ListTile(
    leading: Icon(icon),
    title: Text(label),
    subtitle: Text(value.isEmpty ? 'Not provided' : value),
  );
}
