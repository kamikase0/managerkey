import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/enviroment.dart';
import '../models/auth_response.dart';
import '../models/user_model.dart';
import '../services/punto_empadronamiento_service.dart';

class AuthService {
  final PuntoEmpadronamientoService _puntoEmpadronamientoService = PuntoEmpadronamientoService();

  static final AuthService _instance = AuthService._internal();

  factory AuthService() => _instance;

  AuthService._internal();

  static const String _authKey = 'auth_tokens';
  static const String _userKey = 'user_data';

  static const String _baseUrl = '${Enviroment.apiUrl}token/';
  static const String _refreshUrl = '${Enviroment.apiUrl}token/refresh/';

  Future<AuthResponse> loginWithEmail(String username, String password) async {
    final url = Uri.parse(_baseUrl);

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'username': username, 'password': password}),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final authResponse = AuthResponse.fromJson(data);

      await _saveAuthData(authResponse);

      // ✅ NUEVO: Sincronizar puntos de empadronamiento después del login exitoso
      await _sincronizarPuntosEmpadronamiento(authResponse.access);

      return authResponse;
    } else {
      throw Exception('Error de autenticación: ${response.body}');
    }
  }

  // ✅ NUEVO: Método para sincronizar puntos de empadronamiento
  Future<void> _sincronizarPuntosEmpadronamiento(String accessToken) async {
    try {
      print('🔄 Sincronizando puntos de empadronamiento...');
      await _puntoEmpadronamientoService.syncPuntosEmpadronamiento(accessToken);
      print('✅ Puntos de empadronamiento sincronizados exitosamente');
    } catch (e) {
      print('⚠️ Error sincronizando puntos de empadronamiento: $e');
      // No relanzamos la excepción para no afectar el flujo de login
    }
  }

  // ✅ NUEVO: Método público para forzar sincronización (útil para manual o después de logout/login)
  Future<void> sincronizarPuntosEmpadronamiento() async {
    try {
      final token = await getAccessToken();
      if (token != null) {
        await _sincronizarPuntosEmpadronamiento(token);
      } else {
        print('❌ No hay token disponible para sincronizar puntos de empadronamiento');
      }
    } catch (e) {
      print('❌ Error forzando sincronización: $e');
      rethrow;
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
    print('DEBUG: Servicio logout completado');
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

  // CORREGIDO: Usar la propiedad idOperador del modelo Operador
  Future<int?> getIdOperador() async {
    final user = await getCurrentUser();
    return user?.idOperador; // Esto usa el getter que ya existe en tu User model
  }

  // CORREGIDO: Método para obtener datos del operador
  Future<Map<String, dynamic>?> getDatosOperador() async {
    final user = await getCurrentUser();
    if (user?.operador != null) {
      final operador = user!.operador!;
      return {
        'id_operador': operador.idOperador,
        'tipo_operador': operador.tipoOperador,
        'id_estacion': operador.idEstacion,
        'nro_estacion': operador.nroEstacion,
        'ruta_id': operador.ruta.id,
        'ruta_nombre': operador.ruta.nombre,
      };
    }
    return null;
  }

  // NUEVO: Método para obtener la ruta del operador
  Future<String?> getRutaOperador() async {
    final datosOperador = await getDatosOperador();
    return datosOperador?['ruta_nombre'];
  }

  // NUEVO: Método para obtener el ID de estación
  Future<int?> getIdEstacion() async {
    final datosOperador = await getDatosOperador();
    return datosOperador?['id_estacion'];
  }

  Future<String?> getAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    final authJson = prefs.getString(_authKey);

    if (authJson != null) {
      try {
        final tokenMap = json.decode(authJson) as Map<String, dynamic>;
        return tokenMap['access'] ?? tokenMap['accessToken'];
      } catch (e) {
        print('Error al decodificar el token de acceso: $e');
        return null;
      }
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

  Future<bool> isOperadorRural() async {
    final user = await getCurrentUser();
    return user?.isOperadorRural ?? false;
  }

  Future<bool> isOperadorUrbano() async {
    final user = await getCurrentUser();
    return user?.isOperadorUrbano ?? false;
  }

  Future<bool> refreshToken() async {
    final prefs = await SharedPreferences.getInstance();
    final authJson = prefs.getString(_authKey);

    if (authJson == null) {
      return false;
    }

    final tokenMap = json.decode(authJson) as Map<String, dynamic>;
    final refreshToken = tokenMap['refresh'] ?? tokenMap['refreshToken'];

    if (refreshToken == null) {
      return false;
    }

    try {
      final response = await http.post(
        Uri.parse(_refreshUrl),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'refresh': refreshToken}),
      );

      if (response.statusCode == 200) {
        final newTokens = json.decode(response.body);
        tokenMap['access'] = newTokens['access'];
        await prefs.setString(_authKey, json.encode(tokenMap));
        print('✅ Token de acceso refrescado exitosamente.');
        return true;
      } else {
        print('❌ Falló el refresco del token. Forzando logout.');
        await logout();
        return false;
      }
    } catch (e) {
      print('❌ Error durante el refresco del token: $e');
      return false;
    }
  }

  String determinarTipoUsuario(User user) {
    final group = user.primaryGroup?.toLowerCase() ?? '';

    if (group.contains('coordinador') || group.contains('admin')) {
      return 'coordinador';
    } else if (group.contains('tecnico') || group.contains('soporte')) {
      return 'tecnico';
    } else {
      return 'operador';
    }
  }

  // NUEVO: Método para obtener información completa del usuario (útil para debug)
  Future<Map<String, dynamic>> getUserInfo() async {
    final user = await getCurrentUser();
    final accessToken = await getAccessToken();
    final idOperador = await getIdOperador();
    final datosOperador = await getDatosOperador();

    return {
      'user': user != null ? {
        'id': user.id,
        'username': user.username,
        'email': user.email,
        'groups': user.groups,
        'primaryGroup': user.primaryGroup,
      } : null,
      'hasToken': accessToken != null,
      'idOperador': idOperador,
      'datosOperador': datosOperador,
      'isOperadorRural': user?.isOperadorRural ?? false,
      'isOperadorUrbano': user?.isOperadorUrbano ?? false,
    };
  }
}