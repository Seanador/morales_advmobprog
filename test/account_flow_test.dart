import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:morales_advmopbrog/main.dart';
import 'package:morales_advmopbrog/models/user.dart';
import 'package:morales_advmopbrog/screens/cart_screen.dart';
import 'package:morales_advmopbrog/screens/home_screen.dart';
import 'package:morales_advmopbrog/screens/product_screen.dart';
import 'package:morales_advmopbrog/screens/profile_screen.dart';
import 'package:morales_advmopbrog/screens/signin_screen.dart';
import 'package:morales_advmopbrog/screens/splash_screen.dart';
import 'package:morales_advmopbrog/services/user_service.dart';
import 'package:morales_advmopbrog/services/product_service.dart';

const account = User(
  id: 42,
  username: 'alex',
  firstName: 'Alex',
  lastName: 'Rivera',
  email: 'alex@example.com',
  gender: 'female',
  accessToken: 'test-access-token',
  refreshToken: 'test-refresh-token',
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  ProductService products() => ProductService(
    client: MockClient((_) async {
      return http.Response('{"products": []}', 200);
    }),
  );

  testWidgets(
    'fresh launch reaches sign-in without requesting a saved session',
    (tester) async {
      final service = UserService(
        client: MockClient((_) async {
          fail('A fresh installation should not send an auth request.');
        }),
      );
      await tester.pumpWidget(
        MoralesAdvMobProg(userService: service, productService: products()),
      );
      await tester.pumpAndSettle();
      expect(find.byType(SigninScreen), findsOneWidget);
      expect(find.byType(HomeScreen), findsNothing);
    },
  );

  testWidgets(
    'saved session restores profile, user cart and signs out without back access',
    (tester) async {
      var restores = 0;
      final service = UserService(
        client: MockClient((request) async {
          expect(request.url.path, '/auth/me');
          expect(request.headers['Authorization'], 'Bearer test-access-token');
          restores++;
          return http.Response(jsonEncode(account.toJson()), 200);
        }),
      );
      await service.saveUserData(account.toJson());
      await tester.pumpWidget(
        MoralesAdvMobProg(userService: service, productService: products()),
      );
      await tester.pumpAndSettle();

      expect(restores, 1);
      expect(tester.widget<HomeScreen>(find.byType(HomeScreen)).user.id, 42);
      expect(
        tester.widget<ProductScreen>(find.byType(ProductScreen)).userId,
        42,
      );
      await tester.tap(find.text('Profile'));
      await tester.pumpAndSettle();
      expect(find.byType(ProfileScreen), findsOneWidget);
      expect(find.text('Alex Rivera'), findsOneWidget);
      expect(find.text('alex@example.com'), findsOneWidget);
      expect(find.text('42'), findsOneWidget);
      expect(find.text('test-access-token'), findsNothing);

      await tester.scrollUntilVisible(
        find.text('View my cart'),
        200,
        scrollable: find.descendant(
          of: find.byType(ProfileScreen),
          matching: find.byType(Scrollable),
        ),
      );
      await tester.tap(find.text('View my cart'));
      await tester.pumpAndSettle();
      expect(tester.widget<CartScreen>(find.byType(CartScreen)).userId, 42);
      Navigator.of(tester.element(find.byType(CartScreen))).pop();
      await tester.pumpAndSettle();

      final homeNavigator = Navigator.of(
        tester.element(find.byType(HomeScreen)),
      );
      unawaited(homeNavigator.pushNamed('/cart'));
      await tester.pumpAndSettle();
      expect(tester.widget<CartScreen>(find.byType(CartScreen)).userId, 42);
      homeNavigator.pop();
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text('Sign out'),
        200,
        scrollable: find.descendant(
          of: find.byType(ProfileScreen),
          matching: find.byType(Scrollable),
        ),
      );
      await tester.tap(find.text('Sign out'));
      await tester.pumpAndSettle();
      expect(find.byType(SigninScreen), findsOneWidget);
      expect(await service.isLoggedIn(), isFalse);
      expect(
        Navigator.of(tester.element(find.byType(SigninScreen))).canPop(),
        isFalse,
      );
    },
  );

  testWidgets('login saves the account used by the actual home route', (
    tester,
  ) async {
    final service = UserService(
      client: MockClient((request) async {
        expect(request.url.path, '/auth/login');
        expect(jsonDecode(request.body)['username'], 'alex');
        return http.Response(jsonEncode(account.toJson()), 200);
      }),
    );
    await tester.pumpWidget(
      MoralesAdvMobProg(userService: service, productService: products()),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), 'alex');
    await tester.enterText(find.byType(TextFormField).at(1), 'password');
    await tester.ensureVisible(find.byKey(const Key('signin_submit')));
    await tester.tap(find.byKey(const Key('signin_submit')));
    await tester.pumpAndSettle();
    expect(tester.widget<HomeScreen>(find.byType(HomeScreen)).user.id, 42);
    expect((await service.getUser()).username, 'alex');
    expect(
      Navigator.of(tester.element(find.byType(HomeScreen))).canPop(),
      isFalse,
    );
  });

  testWidgets(
    'browser home deep link waits for exactly one session validation',
    (tester) async {
      tester.binding.platformDispatcher.defaultRouteNameTestValue = '/home';
      addTearDown(
        tester.binding.platformDispatcher.clearDefaultRouteNameTestValue,
      );
      final pending = Completer<http.Response>();
      var restores = 0;
      final service = UserService(
        client: MockClient((_) {
          restores++;
          return pending.future;
        }),
      );
      await service.saveUserData(account.toJson());
      await tester.pumpWidget(
        MoralesAdvMobProg(userService: service, productService: products()),
      );
      await tester.pump();
      expect(find.byType(SplashScreen), findsOneWidget);
      expect(find.byType(HomeScreen), findsNothing);
      expect(restores, 1);
      pending.complete(http.Response(jsonEncode(account.toJson()), 200));
      await tester.pumpAndSettle();
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(restores, 1);
    },
  );

  testWidgets('profile remains scrollable on a small display with large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final service = UserService();
    await service.saveUserData(account.toJson());
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(320, 568),
            textScaler: TextScaler.linear(1.8),
          ),
          child: Scaffold(body: ProfileScreen(userService: service)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Sign out'),
      200,
      scrollable: find.byType(Scrollable),
    );
    expect(tester.takeException(), isNull);
  });
}
