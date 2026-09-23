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
  late Future<User> _user = _userService.getUser();
  bool _isSigningOut = false;

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
                    icon: Icons.email_outlined,
                    label: 'Email',
                    value: user.email,
                  ),
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  _ProfileDetail(
                    icon: Icons.badge_outlined,
                    label: 'User ID',
                    value: '${user.id}',
                  ),
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  _ProfileDetail(
                    icon: Icons.person_outline,
                    label: 'Gender',
                    value: user.gender,
                  ),
                ],
              ),
            ),
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
