import 'dart:async';
import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:morales_advmopbrog/models/user.dart';
import 'package:morales_advmopbrog/services/user_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _account = <String, dynamic>{
  'id': 7,
  'username': 'testuser',
  'email': 'test@example.com',
  'firstName': 'Test',
  'lastName': 'User',
  'gender': 'female',
  'image': 'https://example.com/avatar.png',
  'accessToken': 'access-before',
  'refreshToken': 'refresh-before',
};

http.Response _json(Map<String, dynamic> body, [int statusCode = 200]) =>
    http.Response(jsonEncode(body), statusCode);

void main() {
  setUp(() {
    dotenv.testLoad(fileInput: 'HOST=https://dummyjson.com');
    SharedPreferences.setMockInitialValues({'darkMode': true});
  });

  test(
    'user model supports legacy tokens and excludes API password fields',
    () {
      final user = User.fromJson({
        ..._account,
        'id': '7',
        'accessToken': '',
        'token': 'legacy-access',
        'password': 'never-store-this',
      });

      expect(user.id, 7);
      expect(user.fullName, 'Test User');
      expect(user.hasSession, isTrue);
      expect(user.accessToken, 'legacy-access');
      expect(user.toJson().containsKey('password'), isFalse);
      expect(User.fromJson(user.toJson()).email, 'test@example.com');
      expect(
        User.fromJson({'id': 'invalid', 'accessToken': 'x'}).hasSession,
        isFalse,
      );
    },
  );

  test(
    'login sends credentials and persists only the validated user',
    () async {
      final client = MockClient((request) async {
        expect(request.url.toString(), 'https://dummyjson.com/auth/login');
        expect(request.method, 'POST');
        expect(jsonDecode(request.body), {
          'username': 'testuser',
          'password': ' password ',
          'expiresInMins': 60,
        });
        return _json({..._account, 'password': 'never-store-this'});
      });
      final service = UserService(client: client);

      final result = await service.loginUser(' testuser ', ' password ');

      expect(result['id'], 7);
      expect((await UserService().getUser()).username, 'testuser');
      expect(await service.isLoggedIn(), isTrue);
      expect(result.containsKey('password'), isFalse);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getKeys(), {'darkMode', 'authUser'});
      expect(prefs.getString('authUser'), isNot(contains('never-store-this')));
    },
  );

  test('invalid credentials do not create or overwrite a session', () async {
    final service = UserService(
      client: MockClient(
        (_) async => _json({'message': 'Invalid credentials'}, 400),
      ),
    );
    await service.saveUserData(_account);

    await expectLater(
      service.loginUser('wrong', 'wrong'),
      throwsA(isA<UserServiceException>()),
    );

    expect((await service.getUser()).id, 7);
    expect(service.data['accessToken'], 'access-before');
  });

  test('malformed successful login cannot persist a partial session', () async {
    for (final body in ['not-json', '[]', '{"id":7}', '{"accessToken":"x"}']) {
      final service = UserService(
        client: MockClient((_) async => http.Response(body, 200)),
      );

      await expectLater(
        service.loginUser('testuser', 'password'),
        throwsA(isA<UserServiceException>()),
      );

      expect(await service.isLoggedIn(), isFalse);
      expect(service.data, isEmpty);
      expect(
        (await SharedPreferences.getInstance()).containsKey('authUser'),
        isFalse,
      );
    }
  });

  test('blank credentials are rejected before a request is sent', () async {
    final service = UserService(
      client: MockClient((_) async {
        fail('Blank credentials must not trigger a network request.');
      }),
    );

    await expectLater(
      service.loginUser(' ', 'password'),
      throwsA(isA<UserServiceException>()),
    );
    await expectLater(
      service.loginUser('testuser', ''),
      throwsA(isA<UserServiceException>()),
    );
  });

  test(
    'invalid Firebase usernames are rejected before account access',
    () async {
      final service = UserService();

      for (final username in ['ab', 'invalid username', 'invalid@username']) {
        await expectLater(
          service.updateUsername(username: username),
          throwsA(
            isA<UserServiceException>().having(
              (exception) => exception.message,
              'message',
              contains('at least 3'),
            ),
          ),
        );
      }
    },
  );

  test(
    'restoring a valid session refreshes profile but never saves its password',
    () async {
      final service = UserService(
        client: MockClient((request) async {
          expect(request.url.path, '/auth/me');
          expect(request.headers['Authorization'], 'Bearer access-before');
          return _json({
            'id': 7,
            'firstName': 'Updated',
            'password': 'never-store-this',
          });
        }),
      );
      await service.saveUserData(_account);

      final user = await service.restoreSession();

      expect(user?.fullName, 'Updated User');
      expect(user?.accessToken, 'access-before');
      expect(user?.refreshToken, 'refresh-before');
      expect((await service.getUser()).firstName, 'Updated');
      expect(service.data.containsKey('password'), isFalse);
    },
  );

  test(
    'expired token is refreshed and identity is checked before saving',
    () async {
      final paths = <String>[];
      final service = UserService(
        client: MockClient((request) async {
          paths.add(request.url.path);
          if (request.url.path == '/auth/refresh') {
            expect(jsonDecode(request.body), {
              'refreshToken': 'refresh-before',
              'expiresInMins': 60,
            });
            return _json({
              'accessToken': 'access-after',
              'refreshToken': 'refresh-after',
            });
          }
          if (request.headers['Authorization'] == 'Bearer access-before') {
            return _json({'message': 'Token expired'}, 401);
          }
          expect(request.headers['Authorization'], 'Bearer access-after');
          return _json({'id': 7, 'firstName': 'Updated'});
        }),
      );
      await service.saveUserData(_account);

      final user = await service.restoreSession();

      expect(paths, ['/auth/me', '/auth/refresh', '/auth/me']);
      expect(user?.accessToken, 'access-after');
      expect(user?.refreshToken, 'refresh-after');
      expect((await UserService().getUser()).accessToken, 'access-after');
    },
  );

  test(
    'rejected refresh clears authentication while keeping appearance settings',
    () async {
      final service = UserService(
        client: MockClient((_) async => _json({'message': 'Expired'}, 401)),
      );
      await service.saveUserData(_account);

      expect(await service.restoreSession(), isNull);
      expect(await service.isLoggedIn(), isFalse);
      expect(service.data, isEmpty);
      expect(
        (await SharedPreferences.getInstance()).getBool('darkMode'),
        isTrue,
      );
    },
  );

  test(
    'expired legacy session without refresh token returns to sign in',
    () async {
      SharedPreferences.setMockInitialValues({
        'id': 7,
        'username': 'testuser',
        'token': 'legacy-access',
        'darkMode': true,
      });
      var requests = 0;
      final service = UserService(
        client: MockClient((request) async {
          requests++;
          expect(request.headers['Authorization'], 'Bearer legacy-access');
          return _json({'message': 'Expired'}, 401);
        }),
      );

      expect(await service.restoreSession(), isNull);
      expect(requests, 1);
      expect((await SharedPreferences.getInstance()).getKeys(), {'darkMode'});
    },
  );

  test(
    'an authenticated different user cannot inherit saved profile or cart id',
    () async {
      final service = UserService(
        client: MockClient(
          (_) async => _json({'id': 99, 'firstName': 'Someone'}),
        ),
      );
      await service.saveUserData(_account);

      expect(await service.restoreSession(), isNull);
      expect(await service.isLoggedIn(), isFalse);
    },
  );

  test('server failures preserve the saved session for retry', () async {
    for (final code in [408, 429, 500, 503]) {
      final service = UserService(
        client: MockClient(
          (_) async => _json({'message': 'Unavailable'}, code),
        ),
      );
      await service.saveUserData(_account);

      await expectLater(
        service.restoreSession(),
        throwsA(isA<UserServiceException>()),
      );
      expect((await service.getUser()).accessToken, 'access-before');
    }
  });

  test(
    'network and timeout errors are readable and preserve the saved session',
    () async {
      for (final error in [
        http.ClientException('offline'),
        TimeoutException('slow'),
      ]) {
        final service = UserService(
          client: MockClient((_) async => throw error),
        );
        await service.saveUserData(_account);

        await expectLater(
          service.restoreSession(),
          throwsA(
            isA<UserServiceException>().having(
              (exception) => exception.message,
              'message',
              contains('try again'),
            ),
          ),
        );

        expect((await service.getUser()).id, 7);
      }
    },
  );

  test(
    'failed validation after refreshing leaves the previous session retryable',
    () async {
      var requests = 0;
      final service = UserService(
        client: MockClient((request) async {
          requests++;
          if (request.url.path == '/auth/refresh') {
            return _json({
              'accessToken': 'access-after',
              'refreshToken': 'refresh-after',
            });
          }
          return requests == 1
              ? _json({'message': 'Expired'}, 401)
              : _json({'message': 'Unavailable'}, 503);
        }),
      );
      await service.saveUserData(_account);

      await expectLater(
        service.restoreSession(),
        throwsA(isA<UserServiceException>()),
      );
      expect((await service.getUser()).accessToken, 'access-before');
    },
  );

  test(
    'corrupt saved data is cleared without attempting authentication',
    () async {
      SharedPreferences.setMockInitialValues({
        'authUser': '{bad json',
        'darkMode': true,
      });
      final service = UserService(
        client: MockClient(
          (_) async => fail('Corrupt local sessions cannot be used.'),
        ),
      );

      expect(await service.restoreSession(), isNull);
      expect((await SharedPreferences.getInstance()).getKeys(), {'darkMode'});
    },
  );

  test('logout removes both current and legacy auth data only', () async {
    SharedPreferences.setMockInitialValues({
      ..._account,
      'token': 'old-token',
      'darkMode': true,
      'unrelatedSetting': 'keep',
    });
    final service = UserService();
    await service.saveUserData(_account);

    await service.logout();

    expect(service.data, isEmpty);
    expect(await service.isLoggedIn(), isFalse);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getKeys(), {'darkMode', 'unrelatedSetting'});
    expect(prefs.getString('unrelatedSetting'), 'keep');
  });
}
