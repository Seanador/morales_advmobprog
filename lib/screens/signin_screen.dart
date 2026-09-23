import 'package:flutter/material.dart';

import '../models/user.dart';
import 'splash_screen.dart';
import '../services/user_service.dart';

//Enhancement 2
// A complete sign-in form using UserService's authenticated, saved user data.
class SigninScreen extends StatefulWidget {
  const SigninScreen({super.key, this.userService, this.initialError});

  final UserService? userService;
  final String? initialError;

  @override
  State<SigninScreen> createState() => _SigninScreenState();
}

class _SigninScreenState extends State<SigninScreen> {
  static const _navy = Color(0xFF13284B);
  static const _gold = Color(0xFFE7BD56);
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  late final UserService _userService;
  bool _isLoading = false;
  bool _obscurePassword = true;
  LoginType _loginType = LoginType.dummyJson;
  String? _error;

  @override
  void initState() {
    super.initState();
    _userService = widget.userService ?? UserService();
    _error = widget.initialError;
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_isLoading || !_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Enhancement 2: The selected login type determines whether credentials
      // go to DummyJSON or directly to the Firebase Auth SDK.
      if (_loginType == LoginType.firebase) {
        await _userService.signIn(
          email: _usernameController.text.trim(),
          password: _passwordController.text,
        );
        if (!mounted) return;
        Navigator.of(context).pushNamedAndRemoveUntil('/home', (_) => false);
        return;
      }
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(
          builder: (_) => SplashScreen(
            userService: _userService,
            username: _usernameController.text.trim(),
            password: _passwordController.text,
          ),
        ),
        (_) => false,
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = error.toString().replaceFirst(RegExp(r'^Exception: '), '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF101927)
          : const Color(0xFFF3F5F9),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: (constraints.maxHeight - 48)
                    .clamp(0, double.infinity)
                    .toDouble(),
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 16,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Image.asset(
                            'assets/images/nubdexchange_logo.png',
                            width: 210,
                            height: 64,
                            fit: BoxFit.contain,
                            semanticLabel: 'NU BD Exchange',
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),
                      Text(
                        'Your next find\nstarts here.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : _navy,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Sign in to explore the shop and pick up where you left off.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 28),
                      Card(
                        margin: EdgeInsets.zero,
                        elevation: 0,
                        color: theme.colorScheme.surface,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                          side: BorderSide(
                            color: theme.colorScheme.outlineVariant,
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: AutofillGroup(
                            child: Form(
                              key: _formKey,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Text(
                                    'Welcome back',
                                    style: theme.textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    _loginType == LoginType.firebase
                                        ? 'Use your Firebase email and password.'
                                        : 'Use your DummyJSON username and password.',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                  const SizedBox(height: 18),
                                  // Enhancement 2: Users explicitly choose the
                                  // authentication provider before signing in.
                                  SegmentedButton<LoginType>(
                                    key: const Key('login_type_toggle'),
                                    segments: const [
                                      ButtonSegment(
                                        value: LoginType.dummyJson,
                                        label: Text('DummyJSON'),
                                        icon: Icon(Icons.api_outlined),
                                      ),
                                      ButtonSegment(
                                        value: LoginType.firebase,
                                        label: Text('Firebase'),
                                        icon: Icon(Icons.local_fire_department),
                                      ),
                                    ],
                                    selected: {_loginType},
                                    onSelectionChanged: _isLoading
                                        ? null
                                        : (selection) => setState(() {
                                            _loginType = selection.first;
                                            _usernameController.clear();
                                            _error = null;
                                          }),
                                  ),
                                  const SizedBox(height: 24),
                                  TextFormField(
                                    key: const Key('signin_username'),
                                    controller: _usernameController,
                                    enabled: !_isLoading,
                                    autocorrect: false,
                                    textInputAction: TextInputAction.next,
                                    keyboardType:
                                        _loginType == LoginType.firebase
                                        ? TextInputType.emailAddress
                                        : TextInputType.text,
                                    autofillHints: [
                                      _loginType == LoginType.firebase
                                          ? AutofillHints.email
                                          : AutofillHints.username,
                                    ],
                                    decoration: InputDecoration(
                                      labelText:
                                          _loginType == LoginType.firebase
                                          ? 'Email address'
                                          : 'Username',
                                      prefixIcon: Icon(
                                        _loginType == LoginType.firebase
                                            ? Icons.email_outlined
                                            : Icons.person_outline,
                                      ),
                                      border: const OutlineInputBorder(),
                                    ),
                                    validator: (value) {
                                      final input = value?.trim() ?? '';
                                      if (input.isEmpty) {
                                        return _loginType == LoginType.firebase
                                            ? 'Enter your email address.'
                                            : 'Enter your username.';
                                      }
                                      if (_loginType == LoginType.firebase &&
                                          !RegExp(
                                            r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                                          ).hasMatch(input)) {
                                        return 'Enter a valid email address.';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 18),
                                  TextFormField(
                                    key: const Key('signin_password'),
                                    controller: _passwordController,
                                    enabled: !_isLoading,
                                    obscureText: _obscurePassword,
                                    autocorrect: false,
                                    enableSuggestions: false,
                                    textInputAction: TextInputAction.done,
                                    autofillHints: const [
                                      AutofillHints.password,
                                    ],
                                    onFieldSubmitted: (_) => _login(),
                                    decoration: InputDecoration(
                                      labelText: 'Password',
                                      prefixIcon: const Icon(
                                        Icons.lock_outline,
                                      ),
                                      border: const OutlineInputBorder(),
                                      suffixIcon: IconButton(
                                        tooltip: _obscurePassword
                                            ? 'Show password'
                                            : 'Hide password',
                                        onPressed: _isLoading
                                            ? null
                                            : () {
                                                setState(
                                                  () => _obscurePassword =
                                                      !_obscurePassword,
                                                );
                                              },
                                        icon: Icon(
                                          _obscurePassword
                                              ? Icons.visibility_outlined
                                              : Icons.visibility_off_outlined,
                                        ),
                                      ),
                                    ),
                                    validator: (value) =>
                                        value == null || value.isEmpty
                                        ? 'Enter your password.'
                                        : null,
                                  ),
                                  if (_error != null) ...[
                                    const SizedBox(height: 16),
                                    Semantics(
                                      liveRegion: true,
                                      child: Text(
                                        _error!,
                                        key: const Key('signin_error'),
                                        style: TextStyle(
                                          color: theme.colorScheme.error,
                                        ),
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 24),
                                  FilledButton(
                                    key: const Key('signin_submit'),
                                    onPressed: _isLoading ? null : _login,
                                    style: FilledButton.styleFrom(
                                      backgroundColor: _navy,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 16,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    child: _isLoading
                                        ? const SizedBox(
                                            width: 22,
                                            height: 22,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: _gold,
                                              semanticsLabel: 'Signing in',
                                            ),
                                          )
                                        : const Text('Sign in'),
                                  ),
                                  const SizedBox(height: 10),
                                  TextButton(
                                    key: const Key('open_signup'),
                                    onPressed: _isLoading
                                        ? null
                                        : () => Navigator.pushNamed(
                                            context,
                                            '/signup',
                                          ),
                                    child: const Text('Create an account'),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Your session stays saved on this device until you sign out.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
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
