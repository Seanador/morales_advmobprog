import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morales_advmopbrog/models/user.dart';
import 'package:morales_advmopbrog/screens/signin_screen.dart';
import 'package:morales_advmopbrog/screens/splash_screen.dart';
import 'package:morales_advmopbrog/services/user_service.dart';

const _userData = <String, dynamic>{
  'id': 7,
  'username': 'testshopper',
  'firstName': 'Test',
  'lastName': 'Shopper',
  'email': 'shopper@example.com',
  'accessToken': 'access-token',
  'refreshToken': 'refresh-token',
};

class _FakeUserService extends UserService {
  Future<Map<String, dynamic>> Function(String, String)? onLogin;
  Future<User?> Function()? onRestore;
  int loginCalls = 0;
  int restoreCalls = 0;
  String? receivedUsername;
  String? receivedPassword;

  @override
  Future<Map<String, dynamic>> loginUser(String username, String password) {
    loginCalls++;
    receivedUsername = username;
    receivedPassword = password;
    return onLogin?.call(username, password) ?? Future.value(_userData);
  }

  @override
  Future<User?> restoreSession() {
    restoreCalls++;
    return onRestore?.call() ?? Future.value(null);
  }
}

Widget _app(Widget home, {void Function(User, bool)? onHome}) {
  return MaterialApp(
    home: home,
    routes: {
      '/home': (context) {
        final user = ModalRoute.of(context)!.settings.arguments! as User;
        onHome?.call(user, Navigator.of(context).canPop());
        return Scaffold(body: Text('Shop for ${user.fullName}'));
      },
      '/signin': (context) {
        final arguments = ModalRoute.of(context)?.settings.arguments;
        return Scaffold(
          body: Column(
            children: [
              const Text('Sign-in destination'),
              if (arguments is String) Text(arguments),
            ],
          ),
        );
      },
    },
  );
}

Future<void> _enterCredentials(WidgetTester tester) async {
  await tester.enterText(
    find.byKey(const Key('signin_username')),
    ' testshopper ',
  );
  await tester.enterText(
    find.byKey(const Key('signin_password')),
    ' password ',
  );
  await tester.ensureVisible(find.byKey(const Key('signin_submit')));
}

void main() {
  testWidgets(
    'empty sign-in validates without submitting or starting a spinner',
    (tester) async {
      final service = _FakeUserService();
      await tester.pumpWidget(_app(SigninScreen(userService: service)));
      await tester.ensureVisible(find.byKey(const Key('signin_submit')));
      await tester.tap(find.byKey(const Key('signin_submit')));
      await tester.pump();

      expect(find.text('Enter your username.'), findsOneWidget);
      expect(find.text('Enter your password.'), findsOneWidget);
      expect(service.loginCalls, 0);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('signin_submit')))
            .onPressed,
        isNotNull,
      );
    },
  );

  testWidgets(
    'sign-in disables inputs while waiting and passes the authenticated user home',
    (tester) async {
      final completer = Completer<Map<String, dynamic>>();
      final service = _FakeUserService()..onLogin = (_, _) => completer.future;
      User? navigatedUser;
      bool? canGoBack;
      await tester.pumpWidget(
        _app(
          SigninScreen(userService: service),
          onHome: (user, canPop) {
            navigatedUser = user;
            canGoBack = canPop;
          },
        ),
      );
      await _enterCredentials(tester);
      await tester.tap(find.byKey(const Key('signin_submit')));
      await tester.pump();

      expect(service.loginCalls, 1);
      expect(service.receivedUsername, 'testshopper');
      expect(service.receivedPassword, ' password ');
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('signin_submit')))
            .onPressed,
        isNull,
      );
      expect(
        tester
            .widget<TextFormField>(find.byKey(const Key('signin_username')))
            .enabled,
        isFalse,
      );
      expect(
        tester
            .widget<TextFormField>(find.byKey(const Key('signin_password')))
            .enabled,
        isFalse,
      );

      completer.complete(_userData);
      await tester.pumpAndSettle();

      expect(find.text('Shop for Test Shopper'), findsOneWidget);
      expect(navigatedUser!.id, 7);
      expect(canGoBack, isFalse);
      expect(find.byType(SigninScreen), findsNothing);
    },
  );

  testWidgets('failed sign-in returns to sign-in with the error message', (
    tester,
  ) async {
    final service = _FakeUserService()
      ..onLogin = (_, _) => Future.error(
        const UserServiceException(
          'Incorrect username or password.',
          isAuthenticationFailure: true,
        ),
      );
    await tester.pumpWidget(_app(SigninScreen(userService: service)));
    await _enterCredentials(tester);
    await tester.tap(find.byKey(const Key('signin_submit')));
    await tester.pumpAndSettle();

    expect(find.text('Sign-in destination'), findsOneWidget);
    expect(find.text('Incorrect username or password.'), findsOneWidget);
    expect(find.byKey(const Key('splash_retry')), findsNothing);
  });

  testWidgets('password can be revealed and hidden', (tester) async {
    await tester.pumpWidget(
      _app(SigninScreen(userService: _FakeUserService())),
    );
    final password = find.descendant(
      of: find.byKey(const Key('signin_password')),
      matching: find.byType(TextField),
    );
    expect(tester.widget<TextField>(password).obscureText, isTrue);
    await tester.ensureVisible(find.byTooltip('Show password'));
    await tester.tap(find.byTooltip('Show password'));
    await tester.pump();
    expect(tester.widget<TextField>(password).obscureText, isFalse);
    await tester.tap(find.byTooltip('Hide password'));
    await tester.pump();
    expect(tester.widget<TextField>(password).obscureText, isTrue);
  });

  testWidgets('sign-in displays an authentication error from splash', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        SigninScreen(
          userService: _FakeUserService(),
          initialError: 'Incorrect username or password.',
        ),
      ),
    );

    expect(find.byKey(const Key('signin_error')), findsOneWidget);
    expect(find.text('Incorrect username or password.'), findsOneWidget);
  });

  testWidgets(
    'sign-in remains scrollable on a small screen with keyboard and large text',
    (tester) async {
      tester.view.physicalSize = const Size(320, 480);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: const TextScaler.linear(1.5),
              viewInsets: const EdgeInsets.only(bottom: 180),
            ),
            child: child!,
          ),
          home: SigninScreen(userService: _FakeUserService()),
        ),
      );
      await tester.ensureVisible(find.byKey(const Key('signin_submit')));
      await tester.pump();
      expect(
        find.byKey(const Key('signin_submit')).hitTestable(),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('splash waits for restoration then opens the saved user home', (
    tester,
  ) async {
    final completer = Completer<User?>();
    final service = _FakeUserService()..onRestore = () => completer.future;
    User? restoredUser;
    bool? canGoBack;
    await tester.pumpWidget(
      _app(
        SplashScreen(userService: service),
        onHome: (user, canPop) {
          restoredUser = user;
          canGoBack = canPop;
        },
      ),
    );
    expect(find.text('Getting your account ready…'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    completer.complete(User.fromJson(_userData));
    await tester.pumpAndSettle();
    expect(service.restoreCalls, 1);
    expect(restoredUser!.id, 7);
    expect(canGoBack, isFalse);
    expect(find.text('Shop for Test Shopper'), findsOneWidget);
  });

  testWidgets('splash opens sign-in when there is no valid session', (
    tester,
  ) async {
    final service = _FakeUserService();
    await tester.pumpWidget(_app(SplashScreen(userService: service)));
    await tester.pumpAndSettle();
    expect(find.text('Sign-in destination'), findsOneWidget);
    expect(find.byType(SplashScreen), findsNothing);
  });

  testWidgets(
    'splash restoration failure stays recoverable and retry succeeds',
    (tester) async {
      final service = _FakeUserService()
        ..onRestore = () => Future.error(Exception('Connection unavailable.'));
      await tester.pumpWidget(_app(SplashScreen(userService: service)));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('splash_retry')), findsOneWidget);
      expect(find.text('Sign-in destination'), findsNothing);

      service.onRestore = () async => User.fromJson(_userData);
      await tester.tap(find.byKey(const Key('splash_retry')));
      await tester.pumpAndSettle();
      expect(service.restoreCalls, 2);
      expect(find.text('Shop for Test Shopper'), findsOneWidget);
    },
  );

  testWidgets('incorrect credentials return from splash to sign-in', (
    tester,
  ) async {
    final service = _FakeUserService()
      ..onLogin = (_, _) => Future.error(
        const UserServiceException(
          'Incorrect username or password.',
          isAuthenticationFailure: true,
        ),
      );

    await tester.pumpWidget(
      _app(
        SplashScreen(
          userService: service,
          username: 'testshopper',
          password: 'wrong-password',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Sign-in destination'), findsOneWidget);
    expect(find.text('Incorrect username or password.'), findsOneWidget);
    expect(find.byType(SplashScreen), findsNothing);
    expect(find.byKey(const Key('splash_retry')), findsNothing);
  });

  testWidgets(
    'finishing authentication after screen disposal does not navigate',
    (tester) async {
      final completer = Completer<Map<String, dynamic>>();
      final service = _FakeUserService()..onLogin = (_, _) => completer.future;
      await tester.pumpWidget(_app(SigninScreen(userService: service)));
      await _enterCredentials(tester);
      await tester.tap(find.byKey(const Key('signin_submit')));
      await tester.pump();
      await tester.pumpWidget(
        MaterialApp(key: UniqueKey(), home: const Text('Another screen')),
      );
      completer.complete(_userData);
      await tester.pumpAndSettle();
      expect(find.text('Another screen'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
