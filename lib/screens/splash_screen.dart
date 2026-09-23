import 'package:flutter/material.dart';

import '../models/user.dart';
import '../services/user_service.dart';

//Enhancement 1
// Restore and verify the persisted session before entering the shop.
class SplashScreen extends StatefulWidget {
  const SplashScreen({
    super.key,
    this.userService,
    this.username,
    this.password,
  });

  final UserService? userService;
  final String? username;
  final String? password;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  late final UserService _userService;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _userService = widget.userService ?? UserService();
    _checkAuthentication();
  }

  Future<void> _checkAuthentication() async {
    try {
      final User? user;
      if (widget.username != null && widget.password != null) {
        final response = await _userService.loginUser(
          widget.username!,
          widget.password!,
        );
        user = User.fromJson(response);
      } else {
        user = await _userService.restoreSession();
      }
      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil(
        user == null ? '/signin' : '/home',
        (_) => false,
        arguments: user,
      );
    } catch (error) {
      if (!mounted) return;
      if (error is UserServiceException && error.isAuthenticationFailure) {
        Navigator.of(context).pushNamedAndRemoveUntil(
          '/signin',
          (_) => false,
          arguments: error.message,
        );
        return;
      }
      setState(() {
        _isLoading = false;
        _error = error.toString().replaceFirst(RegExp(r'^Exception: '), '');
      });
    }
  }

  void _retry() {
    if (_isLoading) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    _checkAuthentication();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF13284B), Color(0xFF071428)],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              padding: const EdgeInsets.all(32),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: (constraints.maxHeight - 64)
                      .clamp(0, double.infinity)
                      .toDouble(),
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(28),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(28),
                            border: Border.all(
                              color: const Color(0xFFE7BD56),
                              width: 3,
                            ),
                          ),
                          child: Image.asset(
                            'assets/images/nubdexchange_logo.png',
                            width: 230,
                            height: 86,
                            fit: BoxFit.contain,
                            semanticLabel: 'NU BD Exchange',
                          ),
                        ),
                        const SizedBox(height: 36),
                        Text(
                          'Discover. Shop. Connect.',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Your community. Your next great find.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Color(0xFFBDC9DB),
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 48),
                        if (_isLoading) ...[
                          const SizedBox(
                            width: 30,
                            height: 30,
                            child: CircularProgressIndicator(
                              color: Color(0xFFE7BD56),
                              strokeWidth: 3,
                            ),
                          ),
                          const SizedBox(height: 18),
                          const Text(
                            'Getting your account ready…',
                            style: TextStyle(color: Colors.white),
                            textAlign: TextAlign.center,
                          ),
                        ] else ...[
                          const Icon(
                            Icons.wifi_off_rounded,
                            color: Color(0xFFE7BD56),
                            size: 32,
                          ),
                          const SizedBox(height: 16),
                          Semantics(
                            liveRegion: true,
                            child: Text(
                              _error ??
                                  'Authentication failed. Check your connection and try again.',
                              style: TextStyle(color: Colors.white),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          const SizedBox(height: 20),
                          FilledButton.icon(
                            key: const Key('splash_retry'),
                            onPressed: _retry,
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFFE7BD56),
                              foregroundColor: const Color(0xFF13284B),
                            ),
                            icon: const Icon(Icons.refresh),
                            label: const Text('Try again'),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
