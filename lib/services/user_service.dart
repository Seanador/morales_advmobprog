import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../constants.dart';
import '../models/user.dart';

class UserServiceException implements Exception {
  const UserServiceException(
    this.message, {
    this.isAuthenticationFailure = false,
  });

  final String message;
  final bool isAuthenticationFailure;

  @override
  String toString() => message;
}

class UserService {
  UserService({http.Client? client}) : _client = client;

  final http.Client? _client;
  static const _requestTimeout = Duration(seconds: 15);
  static const _sessionKey = 'authUser';
  static const _legacyKeys = [
    'id',
    'username',
    'email',
    'firstName',
    'lastName',
    'gender',
    'image',
    'accessToken',
    'refreshToken',
    'token',
  ];

  Map<String, dynamic> data = {};

  //Enhancement 2
  // A successful login validates and saves the session once before navigation.
  Future<Map<String, dynamic>> loginUser(
    String username,
    String password,
  ) async {
    if (username.trim().isEmpty || password.isEmpty) {
      throw const UserServiceException('Enter your username and password.');
    }
    final response = await _request(
      '/auth/login',
      body: {
        'username': username.trim(),
        'password': password,
        'expiresInMins': 60,
      },
    );
    if ([400, 401, 403].contains(response.statusCode)) {
      throw const UserServiceException(
        'Incorrect username or password.',
        isAuthenticationFailure: true,
      );
    }
    if (response.statusCode != 200) {
      throw const UserServiceException(
        'Sign in is unavailable right now. Please try again.',
      );
    }
    final Map<String, dynamic> responseData;
    try {
      responseData = _decodeObject(response.body);
    } on FormatException {
      throw const UserServiceException(
        'The sign-in response was incomplete. Please try again.',
      );
    }
    final user = User.fromJson(responseData);
    if (!user.hasSession) {
      throw const UserServiceException(
        'The sign-in response was incomplete. Please try again.',
      );
    }
    await saveUserData(user.toJson());
    return Map<String, dynamic>.from(data);
  }

  //Enhancement 1
  // Validate saved credentials; expired access tokens can be refreshed without
  // storing a password. Network failures leave the session available for retry.
  Future<User?> restoreSession() async {
    var user = await getUser();
    if (!user.hasSession) {
      await logout();
      return null;
    }

    var response = await _request('/auth/me', accessToken: user.accessToken);
    if ([401, 403].contains(response.statusCode)) {
      if (user.refreshToken.trim().isEmpty) {
        await logout();
        return null;
      }
      final refresh = await _request(
        '/auth/refresh',
        body: {'refreshToken': user.refreshToken, 'expiresInMins': 60},
      );
      if (_isRejected(refresh.statusCode)) {
        await logout();
        return null;
      }
      _requireAvailable(refresh);
      try {
        final tokens = _decodeObject(refresh.body);
        final newAccessToken = User.fromJson(tokens).accessToken;
        if (newAccessToken.trim().isEmpty) {
          throw const FormatException('Missing refreshed access token.');
        }
        user = User.fromJson({
          ...user.toJson(),
          'accessToken': newAccessToken,
          'refreshToken':
              tokens['refreshToken'] is String &&
                  (tokens['refreshToken'] as String).trim().isNotEmpty
              ? tokens['refreshToken']
              : user.refreshToken,
        });
      } on FormatException {
        await logout();
        return null;
      }
      response = await _request('/auth/me', accessToken: user.accessToken);
    }

    if (_isRejected(response.statusCode)) {
      await logout();
      return null;
    }
    _requireAvailable(response);
    try {
      final profile = _decodeObject(response.body);
      // Never combine an old account's saved data with another user's token.
      if (User.fromJson(profile).id != user.id) {
        throw const FormatException('Session identity does not match.');
      }
      final validatedUser = User.fromJson({
        ...user.toJson(),
        ...profile,
        'accessToken': user.accessToken,
        'refreshToken': user.refreshToken,
      });
      await saveUserData(validatedUser.toJson());
      return validatedUser;
    } on FormatException {
      await logout();
      return null;
    }
  }

  //Enhancement 3
  // One JSON write keeps the account and its tokens together. User.fromJson
  // discards unrelated API fields, including the password returned by /auth/me.
  Future<void> saveUserData(Map<String, dynamic> userData) async {
    final user = User.fromJson(userData);
    if (!user.hasSession) {
      throw const UserServiceException('Cannot save an incomplete session.');
    }
    final prefs = await SharedPreferences.getInstance();
    final saved = await prefs.setString(_sessionKey, jsonEncode(user.toJson()));
    if (!saved) {
      throw const UserServiceException(
        'Could not save your session. Please try again.',
      );
    }
    data = user.toJson();
  }

  Future<Map<String, dynamic>> getUserData() async {
    final prefs = await SharedPreferences.getInstance();
    Map<String, dynamic> saved;
    final snapshot = prefs.get(_sessionKey);
    if (snapshot != null) {
      try {
        saved = snapshot is String ? _decodeObject(snapshot) : {};
      } on FormatException {
        saved = {};
      }
    } else {
      // Migrate sessions written by the original service on the next save.
      saved = {for (final key in _legacyKeys) key: prefs.get(key)};
    }
    final user = User.fromJson(saved);
    return {...user.toJson(), 'token': user.accessToken};
  }

  Future<User> getUser() async => User.fromJson(await getUserData());

  /// Reports whether a local session exists; restoreSession validates it online.
  Future<bool> isLoggedIn() async => (await getUser()).hasSession;

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    for (final key in [_sessionKey, ..._legacyKeys]) {
      final removed = await prefs.remove(key);
      if (!removed) {
        throw const UserServiceException(
          'Could not sign out. Please try again.',
        );
      }
    }
    data = {};
  }

  Future<http.Response> _request(
    String path, {
    Map<String, dynamic>? body,
    String? accessToken,
  }) async {
    final uri = Uri.parse('$host$path');
    final headers = {
      'Content-Type': 'application/json',
      if (accessToken != null) 'Authorization': 'Bearer $accessToken',
    };
    try {
      final Future<http.Response> request;
      if (body == null) {
        request = _client != null
            ? _client.get(uri, headers: headers)
            : http.get(uri, headers: headers);
      } else {
        request = _client != null
            ? _client.post(uri, headers: headers, body: jsonEncode(body))
            : http.post(uri, headers: headers, body: jsonEncode(body));
      }
      return await request.timeout(_requestTimeout);
    } on TimeoutException {
      throw const UserServiceException(
        'The connection timed out. Please try again.',
      );
    } on http.ClientException {
      throw const UserServiceException(
        'Could not connect. Check your internet connection and try again.',
      );
    }
  }

  static Map<String, dynamic> _decodeObject(String body) {
    final decoded = jsonDecode(body);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Expected a JSON object.');
    }
    return decoded;
  }

  static bool _isRejected(int statusCode) =>
      statusCode >= 400 &&
      statusCode < 500 &&
      statusCode != 408 &&
      statusCode != 429;

  static void _requireAvailable(http.Response response) {
    if (response.statusCode != 200) {
      throw const UserServiceException(
        'We could not check your session. Please try again.',
      );
    }
  }
}
