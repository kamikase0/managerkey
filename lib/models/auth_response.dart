import 'user_model.dart';

class AuthResponse {
  final String refresh;
  final String access;
  final User user;

  AuthResponse({
    required this.refresh,
    required this.access,
    required this.user,
  });

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    return AuthResponse(
      refresh: json['refresh'],
      access: json['access'],
      user: User.fromJson(json['user']),
    );
  }
}