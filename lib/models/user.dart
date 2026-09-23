//Enhancement 3
// Keep only the profile and session fields the app needs from DummyJSON.
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

  String get fullName {
    final name = [
      firstName.trim(),
      lastName.trim(),
    ].where((part) => part.isNotEmpty).join(' ');
    return name.isEmpty ? username : name;
  }

  bool get hasSession => id > 0 && accessToken.trim().isNotEmpty;

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
  };
}
