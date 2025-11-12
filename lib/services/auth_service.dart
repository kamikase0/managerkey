import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/enviroment.dart';
import '../models/auth_response.dart';
import '../models/user_model.dart';

class AuthService {
static final AuthService _instance = AuthService._internal();
factory AuthService() => _instance;
AuthService._internal();

static const String _authKey = 'auth_tokens';
static const String _userKey = 'user_data';

static const String _baseUrl = '${Enviroment.apiUrl}token/';

Future<AuthResponse> loginWithEmail(String username, String password) async {
final url = Uri.parse(_baseUrl);

final response = await http.post(
url,
headers: {'Content-Type': 'application/json'},
body: json.encode({
'username': username,
'password': password,
}),
);

if (response.statusCode == 200) {
final data = json.decode(response.body);
final authResponse = AuthResponse.fromJson(data);

await _saveAuthData(authResponse);
return authResponse;
} else {
throw Exception('Error de autenticación: ${response.body}');
}
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

Future<String> getWelcomeMessage() async {
final user = await getCurrentUser();
return user != null ? ' ${user.username}' : 'Bienvenido/a';
}

Future<String?> getTipoOperador() async {
final user = await getCurrentUser();
return user?.tipoOperador;
}

Future<int?> getIdOperador() async {
final user = await getCurrentUser();
return user?.idOperador;
}

Future<bool> isOperadorRural() async {
final user = await getCurrentUser();
return user?.isOperadorRural ?? false;
}

Future<bool> isOperadorUrbano() async {
final user = await getCurrentUser();
return user?.isOperadorUrbano ?? false;
}
}