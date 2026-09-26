import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter/foundation.dart';
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

final ValueNotifier<UserService> userService = ValueNotifier(UserService());

class UserService {
  UserService({
    http.Client? client,
    firebase_auth.FirebaseAuth? firebaseAuth,
    FirebaseFirestore? firestore,
  }) : _client = client,
       _firebaseAuth = firebaseAuth,
       _firestore = firestore;

  final http.Client? _client;
  firebase_auth.FirebaseAuth? _firebaseAuth;
  FirebaseFirestore? _firestore;
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

  firebase_auth.FirebaseAuth get firebaseAuth =>
      _firebaseAuth ??= firebase_auth.FirebaseAuth.instance;

  FirebaseFirestore get firestore => _firestore ??= FirebaseFirestore.instance;

  firebase_auth.User? get currentUser => firebaseAuth.currentUser;

  Stream<firebase_auth.User?> get authStateChanges =>
      firebaseAuth.authStateChanges();

  Future<firebase_auth.UserCredential> signIn({
    required String email,
    required String password,
  }) async {
    // Enhancement 1: Firebase email/password sign-in is kept separate from
    // DummyJSON's username/password endpoint.
    try {
      final credential = await firebaseAuth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final firebaseUser = credential.user;
      if (firebaseUser == null) {
        throw const UserServiceException('Firebase did not return a user.');
      }
      await _ensureFirestoreProfile(firebaseUser);
      await _saveFirebaseProfile(firebaseUser);
      return credential;
    } on firebase_auth.FirebaseAuthException catch (error) {
      throw UserServiceException(
        _firebaseMessage(error),
        isAuthenticationFailure: true,
      );
    }
  }

  Future<firebase_auth.UserCredential> createAccount({
    required String email,
    required String password,
    String username = '',
    String firstName = '',
    String lastName = '',
    int? age,
    String contactNo = '',
  }) async {
    // Enhancement 1: Firebase Auth owns credentials. Additional profile
    // fields are saved locally because Firebase Auth only stores basic fields.
    try {
      final credential = await firebaseAuth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final firebaseUser = credential.user;
      if (firebaseUser == null) {
        throw const UserServiceException('Firebase did not return a user.');
      }
      if (username.trim().isNotEmpty) {
        await firebaseUser.updateDisplayName(username.trim());
      }
      await _createFirestoreProfile(
        firebaseUser,
        username: username,
        firstName: firstName,
        lastName: lastName,
        age: age,
        contactNo: contactNo,
      );
      await _saveFirebaseProfile(
        firebaseUser,
        username: username,
        firstName: firstName,
        lastName: lastName,
        age: age,
        contactNo: contactNo,
      );
      return credential;
    } on firebase_auth.FirebaseAuthException catch (error) {
      throw UserServiceException(_firebaseMessage(error));
    }
  }

  Future<void> _createFirestoreProfile(
    firebase_auth.User firebaseUser, {
    required String username,
    required String firstName,
    required String lastName,
    required int? age,
    required String contactNo,
  }) async {
    try {
      await firestore.collection('Users').doc(firebaseUser.uid).set({
        'uid': firebaseUser.uid,
        'email': firebaseUser.email ?? '',
        'username': username.trim(),
        'firstName': firstName.trim(),
        'lastName': lastName.trim(),
        'age': age,
        'contactNo': contactNo.trim(),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (error) {
      throw UserServiceException(
        error.code == 'permission-denied'
            ? 'The account was created, but Firestore denied the user profile. '
                  'Deploy the Firestore security rules and sign in again.'
            : 'The account was created, but its profile could not be saved to '
                  'Firestore. Please try again.',
      );
    }
  }

  Future<void> _ensureFirestoreProfile(firebase_auth.User firebaseUser) async {
    final profile = firestore.collection('Users').doc(firebaseUser.uid);
    try {
      if ((await profile.get()).exists) return;
      await profile.set({
        'uid': firebaseUser.uid,
        'email': firebaseUser.email ?? '',
        'username': firebaseUser.displayName ?? '',
        'firstName': '',
        'lastName': '',
        'age': null,
        'contactNo': '',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (error) {
      throw UserServiceException(
        error.code == 'permission-denied'
            ? 'Firestore denied access to your user profile. Deploy the '
                  'Firestore security rules and try again.'
            : 'Could not load your Firestore profile. Please try again.',
      );
    }
  }

  Future<void> signOut() async {
    // Enhancement 1: Clear both Firebase's persisted session and app data.
    try {
      await firebaseAuth.signOut();
    } finally {
      await _clearLocalSession();
    }
  }

  Future<void> updateUsername({required String username}) async {
    // Enhancement 3: Profile edits apply to Firebase and the local snapshot.
    final firebaseUser = _requireFirebaseUser();
    await firebaseUser.updateDisplayName(username.trim());
    await firebaseUser.reload();
    final saved = await getUser();
    await _saveFirebaseProfile(
      firebaseAuth.currentUser ?? firebaseUser,
      username: username,
      firstName: saved.firstName,
      lastName: saved.lastName,
      age: saved.age,
      contactNo: saved.contactNo,
      existingId: saved.id,
    );
  }

  Future<void> deleteAccount({
    required String email,
    required String password,
  }) async {
    // Enhancement 1: Sensitive Firebase operations require recent login.
    final firebaseUser = _requireFirebaseUser();
    final credential = firebase_auth.EmailAuthProvider.credential(
      email: email,
      password: password,
    );

    await firebaseUser.reauthenticateWithCredential(credential);
    await firebaseUser.delete();
    await _clearLocalSession();
  }

  Future<void> resetPasswordFromCurrentPassword({
    required String currentPassword,
    required String newPassword,
    required String email,
  }) async {
    final firebaseUser = _requireFirebaseUser();
    final credential = firebase_auth.EmailAuthProvider.credential(
      email: email,
      password: currentPassword,
    );

    await firebaseUser.reauthenticateWithCredential(credential);
    await firebaseUser.updatePassword(newPassword);
  }

  // Enhancement 2: DummyJSON account creation is a simulated API call. The
  // service does not pretend that the returned user can later authenticate.
  Future<Map<String, dynamic>> createDummyAccount({
    required String firstName,
    required String lastName,
    required int age,
    required String contactNo,
    required String username,
    required String email,
    required String password,
  }) async {
    final response = await _request(
      '/users/add',
      body: {
        'firstName': firstName.trim(),
        'lastName': lastName.trim(),
        'age': age,
        'phone': contactNo.trim(),
        'username': username.trim(),
        'email': email.trim(),
        'password': password,
      },
    );
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw const UserServiceException(
        'DummyJSON could not simulate account creation.',
      );
    }
    return _decodeObject(response.body);
  }

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
    final user = User.fromJson({
      ...responseData,
      'loginType': LoginType.dummyJson.name,
    });
    if (!user.hasSession) {
      throw const UserServiceException(
        'The sign-in response was incomplete. Please try again.',
      );
    }
    await saveUserData(user.toJson());
    return Map<String, dynamic>.from(data);
  }

  // Enhancement 2: Restore the selected provider. Firebase refreshes its ID
  // token through the SDK; DummyJSON uses /auth/refresh explicitly.
  Future<User?> restoreSession() async {
    var user = await getUser();
    if (!user.hasSession) {
      await logout();
      return null;
    }

    if (user.loginType == LoginType.firebase) {
      return _restoreFirebaseSession(user);
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
        'loginType': LoginType.dummyJson.name,
      });
      await saveUserData(validatedUser.toJson());
      return validatedUser;
    } on FormatException {
      await logout();
      return null;
    }
  }

  // Enhancement 3
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
    // Enhancement 1: Sign out from the active provider, clear every app token,
    // and preserve unrelated preferences such as the theme.
    final saved = await getUser();
    if (saved.loginType == LoginType.firebase) {
      try {
        await firebaseAuth.signOut();
      } finally {
        await _clearLocalSession();
      }
      return;
    }
    await _clearLocalSession();
  }

  Future<void> _clearLocalSession() async {
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

  Future<User?> _restoreFirebaseSession(User saved) async {
    try {
      final initialUser =
          firebaseAuth.currentUser ??
          await authStateChanges.first.timeout(_requestTimeout);
      if (initialUser == null || initialUser.uid != saved.firebaseUid) {
        await _clearLocalSession();
        return null;
      }
      await initialUser.reload();
      final refreshedUser = firebaseAuth.currentUser ?? initialUser;
      await _saveFirebaseProfile(
        refreshedUser,
        username: refreshedUser.displayName ?? saved.username,
        firstName: saved.firstName,
        lastName: saved.lastName,
        age: saved.age,
        contactNo: saved.contactNo,
        existingId: saved.id,
      );
      return getUser();
    } on firebase_auth.FirebaseAuthException catch (error) {
      if ({
        'user-disabled',
        'user-not-found',
        'invalid-user-token',
      }.contains(error.code)) {
        await _clearLocalSession();
        return null;
      }
      throw UserServiceException(_firebaseMessage(error));
    } on TimeoutException {
      throw const UserServiceException(
        'Firebase session check timed out. Please try again.',
      );
    }
  }

  Future<void> _saveFirebaseProfile(
    firebase_auth.User firebaseUser, {
    String username = '',
    String firstName = '',
    String lastName = '',
    int? age,
    String contactNo = '',
    int? existingId,
  }) async {
    // Firebase refresh tokens remain inside the SDK. getIdToken() returns a
    // cached valid ID token or refreshes it when necessary.
    final idToken = await firebaseUser.getIdToken();
    if (idToken == null || idToken.isEmpty) {
      throw const UserServiceException('Could not obtain a Firebase ID token.');
    }
    final preferredUsername = username.trim().isNotEmpty
        ? username.trim()
        : (firebaseUser.displayName?.trim().isNotEmpty ?? false)
        ? firebaseUser.displayName!.trim()
        : (firebaseUser.email?.split('@').first ?? 'firebase-user');
    final profile = User(
      id: existingId ?? _localIdForFirebaseUser(firebaseUser.uid),
      username: preferredUsername,
      email: firebaseUser.email ?? '',
      firstName: firstName.trim(),
      lastName: lastName.trim(),
      accessToken: idToken,
      age: age,
      contactNo: contactNo.trim(),
      firebaseUid: firebaseUser.uid,
      loginType: LoginType.firebase,
    );
    await saveUserData(profile.toJson());
  }

  firebase_auth.User _requireFirebaseUser() {
    final firebaseUser = currentUser;
    if (firebaseUser == null) {
      throw const UserServiceException('No Firebase user is signed in.');
    }
    return firebaseUser;
  }

  static int _localIdForFirebaseUser(String uid) {
    final id = uid.hashCode & 0x7fffffff;
    return id == 0 ? 1 : id;
  }

  static String _firebaseMessage(firebase_auth.FirebaseAuthException error) {
    return switch (error.code) {
      'invalid-email' => 'Enter a valid email address.',
      'invalid-credential' ||
      'wrong-password' ||
      'user-not-found' => 'Incorrect email or password.',
      'email-already-in-use' => 'That email already has an account.',
      'weak-password' => 'Use a stronger password with at least 6 characters.',
      'requires-recent-login' =>
        'Please sign in again before changing sensitive account details.',
      'network-request-failed' =>
        'Could not connect to Firebase. Check your connection.',
      _ => error.message ?? 'Firebase authentication failed.',
    };
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
