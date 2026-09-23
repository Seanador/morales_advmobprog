import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

import '../providers/theme_provider.dart';
import '../services/user_service.dart';
import '../widgets/custom_text.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, this.userService});

  final UserService? userService;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 1,
      child: Scaffold(
        appBar: AppBar(
          elevation: 2,
          title: CustomText(
            text: 'Settings',
            fontSize: 20.sp,
            fontWeight: FontWeight.w600,
          ),
          bottom: const TabBar(
            tabs: [Tab(text: 'Appearance')],
            labelPadding: EdgeInsets.symmetric(vertical: 8),
          ),
        ),
        body: TabBarView(
          children: [
            Consumer<ThemeProvider>(
              builder: (context, themeProvider, child) {
                return ListView(
                  padding: EdgeInsets.all(16.w),
                  children: [
                    SwitchListTile(
                      value: themeProvider.isDark,
                      onChanged: (_) => themeProvider.toggleTheme(),
                      title: const CustomText(
                        text: 'Dark Mode',
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                      subtitle: const CustomText(
                        text: 'Toggle between light and dark appearance',
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                      ),
                      secondary: Icon(
                        themeProvider.isDark
                            ? Icons.dark_mode
                            : Icons.light_mode,
                      ),
                    ),
                    const Divider(),
                    // Enhancement 1: Settings also exposes a session-clearing
                    // logout action and removes the navigation history.
                    _LogoutTile(userService: userService),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _LogoutTile extends StatefulWidget {
  const _LogoutTile({this.userService});

  final UserService? userService;

  @override
  State<_LogoutTile> createState() => _LogoutTileState();
}

class _LogoutTileState extends State<_LogoutTile> {
  bool _loading = false;

  Future<void> _logout() async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      await (widget.userService ?? UserService()).logout();
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, '/signin', (_) => false);
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to sign out. Please try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) => ListTile(
    key: const Key('settings_logout'),
    leading: _loading
        ? const SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : const Icon(Icons.logout),
    title: const Text('Log out'),
    subtitle: const Text('Clear your session and return to sign in'),
    onTap: _loading ? null : _logout,
  );
}
