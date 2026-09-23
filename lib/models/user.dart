// Enhancement 2: The persisted profile records which authentication provider
// owns the session so the app can restore DummyJSON and Firebase differently.
enum LoginType {
  dummyJson,
  firebase;

  String get label => this == LoginType.firebase ? 'Firebase' : 'DummyJSON';

  static LoginType fromValue(Object? value) =>
      value == 'firebase' ? LoginType.firebase : LoginType.dummyJson;
}

// Enhancement 3: Keep only the profile and session fields the app needs.
class User {
  const User({
    required this.id,
    this.username = '',
    this.email = '',
    this.firstName = '',
    this.lastName = '',
    this.gender = '',
    this.image = '',
    this.accessToken = '',
    this.refreshToken = '',
    this.age,
    this.contactNo = '',
    this.firebaseUid = '',
    this.loginType = LoginType.dummyJson,
  });

  final int id;
  final String username;
  final String email;
  final String firstName;
  final String lastName;
  final String gender;
  final String image;
  final String accessToken;
  final String refreshToken;
  final int? age;
  final String contactNo;
  final String firebaseUid;
  final LoginType loginType;

  String get fullName {
    final name = [
      firstName.trim(),
      lastName.trim(),
    ].where((part) => part.isNotEmpty).join(' ');
    return name.isEmpty ? username : name;
  }

  bool get hasSession => loginType == LoginType.firebase
      ? firebaseUid.trim().isNotEmpty && accessToken.trim().isNotEmpty
      : id > 0 && accessToken.trim().isNotEmpty;

  factory User.fromJson(Map<String, dynamic> json) {
    String stringValue(String key) => json[key] is String ? json[key] : '';
    final accessToken = stringValue('accessToken');
    return User(
      id: json['id'] is int
          ? json['id'] as int
          : int.tryParse('${json['id']}') ?? 0,
      username: stringValue('username'),
      email: stringValue('email'),
      firstName: stringValue('firstName'),
      lastName: stringValue('lastName'),
      gender: stringValue('gender'),
      image: stringValue('image'),
      accessToken: accessToken.trim().isNotEmpty
          ? accessToken
          : stringValue('token'),
      refreshToken: stringValue('refreshToken'),
      age: json['age'] is int
          ? json['age'] as int
          : int.tryParse('${json['age'] ?? ''}'),
      contactNo: stringValue('contactNo').isNotEmpty
          ? stringValue('contactNo')
          : stringValue('phone'),
      firebaseUid: stringValue('firebaseUid'),
      loginType: LoginType.fromValue(json['loginType']),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'username': username,
    'email': email,
    'firstName': firstName,
    'lastName': lastName,
    'gender': gender,
    'image': image,
    'accessToken': accessToken,
    'refreshToken': refreshToken,
    'age': age,
    'contactNo': contactNo,
    'firebaseUid': firebaseUid,
    'loginType': loginType.name,
  };
}
