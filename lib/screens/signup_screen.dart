import 'package:flutter/material.dart';

import '../models/user.dart';
import '../services/user_service.dart';

// Enhancement 2: A shared registration form mirrors the useful identity fields
// in DummyJSON users. Firebase creates a real account; DummyJSON only simulates
// POST /users/add because its public API does not persist newly added users.
class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key, this.userService});

  final UserService? userService;

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _age = TextEditingController();
  final _contactNo = TextEditingController();
  final _username = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  late final UserService _userService = widget.userService ?? UserService();

  LoginType _loginType = LoginType.firebase;
  bool _submitting = false;
  bool _obscurePassword = true;
  String? _error;

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _age.dispose();
    _contactNo.dispose();
    _username.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting || !_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      if (_loginType == LoginType.firebase) {
        await _userService.createAccount(
          email: _email.text,
          password: _password.text,
          username: _username.text,
          firstName: _firstName.text,
          lastName: _lastName.text,
          age: int.parse(_age.text),
          contactNo: _contactNo.text,
        );
        if (!mounted) return;
        Navigator.pushNamedAndRemoveUntil(context, '/home', (_) => false);
        return;
      }

      await _userService.createDummyAccount(
        firstName: _firstName.text,
        lastName: _lastName.text,
        age: int.parse(_age.text),
        contactNo: _contactNo.text,
        username: _username.text,
        email: _email.text,
        password: _password.text,
      );
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Demo account created'),
          content: const Text(
            'DummyJSON simulated the request but does not save new users. '
            'Sign in with credentials from dummyjson.com/users.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = error.toString().replaceFirst(RegExp(r'^Exception: '), '');
      });
    }
  }

  String? _required(String? value, String label) =>
      value == null || value.trim().isEmpty ? 'Enter your $label.' : null;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Create account')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text(
                'Choose where to create the account',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              SegmentedButton<LoginType>(
                key: const Key('signup_type_toggle'),
                segments: const [
                  ButtonSegment(
                    value: LoginType.firebase,
                    label: Text('Firebase'),
                    icon: Icon(Icons.local_fire_department),
                  ),
                  ButtonSegment(
                    value: LoginType.dummyJson,
                    label: Text('DummyJSON demo'),
                    icon: Icon(Icons.api_outlined),
                  ),
                ],
                selected: {_loginType},
                onSelectionChanged: _submitting
                    ? null
                    : (value) => setState(() => _loginType = value.first),
              ),
              const SizedBox(height: 8),
              Text(
                _loginType == LoginType.firebase
                    ? 'Firebase creates a persistent email/password account.'
                    : 'DummyJSON returns a simulated user and does not persist it.',
                style: TextStyle(color: colors.onSurfaceVariant),
              ),
              const SizedBox(height: 24),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _field(
                      key: const Key('signup_first_name'),
                      controller: _firstName,
                      label: 'First name',
                      validator: (value) => _required(value, 'first name'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _field(
                      key: const Key('signup_last_name'),
                      controller: _lastName,
                      label: 'Last name',
                      validator: (value) => _required(value, 'last name'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _field(
                key: const Key('signup_age'),
                controller: _age,
                label: 'Age',
                keyboardType: TextInputType.number,
                validator: (value) {
                  final age = int.tryParse(value?.trim() ?? '');
                  if (age == null) return 'Enter a valid age.';
                  if (age < 13 || age > 120) {
                    return 'Age must be between 13 and 120.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              _field(
                key: const Key('signup_contact'),
                controller: _contactNo,
                label: 'Contact number',
                keyboardType: TextInputType.phone,
                validator: (value) {
                  final contact = value?.trim() ?? '';
                  if (!RegExp(r'^\+?[0-9][0-9 -]{6,14}$').hasMatch(contact)) {
                    return 'Enter a valid contact number.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              _field(
                key: const Key('signup_username'),
                controller: _username,
                label: 'Username',
                validator: (value) {
                  final username = value?.trim() ?? '';
                  if (username.length < 3) {
                    return 'Username must have at least 3 characters.';
                  }
                  if (!RegExp(r'^[a-zA-Z0-9._-]+$').hasMatch(username)) {
                    return 'Use letters, numbers, dots, dashes, or underscores.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              _field(
                key: const Key('signup_email'),
                controller: _email,
                label: 'Email address',
                keyboardType: TextInputType.emailAddress,
                validator: (value) =>
                    RegExp(
                      r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                    ).hasMatch(value?.trim() ?? '')
                    ? null
                    : 'Enter a valid email address.',
              ),
              const SizedBox(height: 16),
              TextFormField(
                key: const Key('signup_password'),
                controller: _password,
                enabled: !_submitting,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  labelText: 'Password',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                  ),
                ),
                validator: (value) {
                  final password = value ?? '';
                  if (password.length < 8) {
                    return 'Password must have at least 8 characters.';
                  }
                  if (!RegExp(r'[A-Z]').hasMatch(password) ||
                      !RegExp(r'[a-z]').hasMatch(password) ||
                      !RegExp(r'[0-9]').hasMatch(password)) {
                    return 'Include uppercase, lowercase, and a number.';
                  }
                  return null;
                },
              ),
              if (_error != null) ...[
                const SizedBox(height: 16),
                Text(
                  _error!,
                  key: const Key('signup_error'),
                  style: TextStyle(color: colors.error),
                ),
              ],
              const SizedBox(height: 24),
              FilledButton(
                key: const Key('signup_submit'),
                onPressed: _submitting ? null : _submit,
                child: _submitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(
                        _loginType == LoginType.firebase
                            ? 'Create Firebase account'
                            : 'Simulate DummyJSON signup',
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field({
    required Key key,
    required TextEditingController controller,
    required String label,
    required String? Function(String?) validator,
    TextInputType? keyboardType,
  }) => TextFormField(
    key: key,
    controller: controller,
    enabled: !_submitting,
    keyboardType: keyboardType,
    textInputAction: TextInputAction.next,
    decoration: InputDecoration(
      labelText: label,
      border: const OutlineInputBorder(),
    ),
    validator: validator,
  );
}
