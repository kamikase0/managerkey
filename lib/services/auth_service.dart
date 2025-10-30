import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/auth_response.dart';
import '../models/user_model.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  static const String _authKey = 'auth_tokens';
  static const String _userKey = 'user_data';

  Future<AuthResponse> loginWithEmail(String email, String password) async {
    // Simular llamada a API con el JSON proporcionado
    await Future.delayed(const Duration(seconds: 1));

    // Determinar grupo basado en el email
    String userGroup = "operador";
    String username = "jose_luis_subia";

    if (email.contains("soporte")) {
      userGroup = "soporte";
      username = "carlos_soporte";
    } else if (email.contains("coordinador")) {
      userGroup = "coordinador";
      username = "ana_coordinadora";
    }

    final mockResponse = {
      "refresh": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ0b2tlbl90eXBlIjoicmVmcmVzaCIsImV4cCI6MTc2MTY3MjI2NCwiaWF0IjoxNzYxNTg1ODY0LCJqdGkiOiJkOGZkYTJkZDQ4MDc0MTBmYjA3NzhjMjk3ZDE3Yzg3NSIsInVzZXJfaWQiOiIyIiwidXNlcm5hbWUiOiJwcnVlYmFfY29vcmRpbmFkb3IiLCJlbWFpbCI6IiIsImdyb3VwIjoiY29vcmRpbmFkb3IifQ.EZ6YUzRm4vJAA9igRVsgx96TXQ7zEZojmUofGrr0ZUc",
      "access": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ0b2tlbl90eXBlIjoiYWNjZXNzIiwiZXhwIjoxNzYxNTg2MTY0LCJpYXQiOjE3NjE1ODU4NjQsImp0aSI6ImQyMGQ4YThhM2U5NDQ1YWY4MzM0ZWQ5MjdiZTc3OTYzIiwidXNlcl9pZCI6IjIiLCJ1c2VybmFtZSI6InBydWViYV9jb29yZGluYWRvciIsImVtYWlsIjoiIiwiZ3JvdXAiOiJjb29yZGluYWRvciJ9.Vn6vZTM_stjJX2BkdQ0YtDuBW6rLSqTC6tjcz2e9YXY",
      "user": {
        "id": 2,
        "username": username,
        "email": email, // Usar el email real ingresado
        "is_staff": true,
        "is_active": true,
        "groups": [userGroup]
      }
    };

    final authResponse = AuthResponse.fromJson(mockResponse);
    await _saveAuthData(authResponse);

    return authResponse;
  }

  Future<String> getWelcomeMessage() async {
    final user = await getCurrentUser();
    return user?.welcomeMessage ?? 'Bienvenido/a';
  }

  Future<void> _saveAuthData(AuthResponse authResponse) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_authKey, json.encode(authResponse.toJson()));
    await prefs.setString(_userKey, json.encode(authResponse.user.toJson()));
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_authKey);
    await prefs.remove(_userKey);
  }

  Future<bool> isAuthenticated() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(_authKey);
  }

  Future<User?> getCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();
    final userJson = prefs.getString(_userKey);
    if (userJson != null) {
      final userMap = json.decode(userJson);
      return User.fromJson(userMap);
    }
    return null;
  }

  Future<String?> getUserGroup() async {
    final user = await getCurrentUser();
    return user?.primaryGroup;
  }

  Future<String> getUserDisplayName() async {
    final user = await getCurrentUser();
    if (user != null) {
      // Convertir "prueba_coordinador" a "Prueba Coordinador"
      final nameParts = user.username.split('_');
      final formattedName = nameParts.map((part) =>
      part[0].toUpperCase() + part.substring(1)
      ).join(' ');
      return formattedName;
    }
    return 'Usuario';
  }

  // Método para obtener el rol formateado
  Future<String> getUserRoleDisplay() async {
    final user = await getCurrentUser();
    if (user != null && user.groups.isNotEmpty) {
      final role = user.groups.first;
      switch (role) {
        case 'operador':
          return 'Operador Rural';
        case 'soporte':
          return 'Soporte Técnico';
        case 'coordinador':
          return 'Coordinador';
        default:
          return 'Usuario';
      }
    }
    return 'Usuario';
  }
}



// Extension para convertir objetos a JSON
extension AuthResponseExtensions on AuthResponse {
  Map<String, dynamic> toJson() {
    return {
      'refresh': refresh,
      'access': access,
      'user': {
        'id': user.id,
        'username': user.username,
        'email': user.email,
        'is_staff': user.isStaff,
        'is_active': user.isActive,
        'groups': user.groups,
      },
    };
  }
}

extension UserExtensions on User {
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'email': email,
      'is_staff': isStaff,
      'is_active': isActive,
      'groups': groups,
    };
  }
}