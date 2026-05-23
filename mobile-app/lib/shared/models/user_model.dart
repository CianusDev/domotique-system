class UserModel {
  final String id;
  final String email;
  final String? username;
  final String? firstName;
  final String? lastName;
  final bool emailVerified;

  const UserModel({
    required this.id,
    required this.email,
    this.username,
    this.firstName,
    this.lastName,
    this.emailVerified = false,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String,
      email: json['email'] as String,
      username: json['username'] as String?,
      firstName: json['firstName'] as String?,
      lastName: json['lastName'] as String?,
      emailVerified: json['emailVerified'] as bool? ?? false,
    );
  }

  /// Fullname > username > email
  String get displayName {
    final full = '${firstName ?? ''} ${lastName ?? ''}'.trim();
    if (full.isNotEmpty) return full;
    if (username?.isNotEmpty == true) return username!;
    return email;
  }

  UserModel copyWith({
    String? id,
    String? email,
    String? username,
    String? firstName,
    String? lastName,
    bool? emailVerified,
  }) {
    return UserModel(
      id: id ?? this.id,
      email: email ?? this.email,
      username: username ?? this.username,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      emailVerified: emailVerified ?? this.emailVerified,
    );
  }
}
