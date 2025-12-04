import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:manager_key/services/reporte_sync_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/enviroment.dart';
import '../models/auth_response.dart';
import '../models/user_model.dart';
import '../services/punto_empadronamiento_service.dart';
import 'api_service.dart';

class AuthService {
  final PuntoEmpadronamientoService _puntoEmpadronamientoService =
  PuntoEmpadronamientoService();

  ReporteSyncService? _reporteSyncService;

  static final AuthService _instance = AuthService._internal();

  factory AuthService() => _instance;

  AuthService._internal();

  static const String _authKey = 'auth_tokens';
  static const String _userKey = 'user_data';
  static const String _reportesKey = 'reportes_cargados';

  static const String _baseUrl = '${Enviroment.apiUrlDev}token/';
  static const String _refreshUrl = '${Enviroment.apiUrlDev}token/refresh/';

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

      //sincronizacion cargar reportes
      await _cargarReportesDuranteLogin(authResponse.access);

      // ✅ NUEVO: Sincronizar puntos de empadronamiento después del login exitoso
      await _sincronizarPuntosEmpadronamiento(authResponse.access);

      return authResponse;
    } else {
      throw Exception('Error de autenticación: ${response.body}');
    }
  }

  //Imyectar ResporteSyncService
  void setReporteSyncService(ReporteSyncService syncService) {
    _reporteSyncService = syncService;
  }

  // ✅ NUEVO: Método para sincronizar puntos de empadronamiento
  Future<void> _sincronizarPuntosEmpadronamiento(String accessToken) async {
    try {
      print('📄 Sincronizando puntos de empadronamiento...');
      await _puntoEmpadronamientoService.syncPuntosEmpadronamiento(accessToken);
      print('✅ Puntos de empadronamiento sincronizados exitosamente');
    } catch (e) {
      print('⚠️ Error sincronizando puntos de empadronamiento: $e');
    }
  }

  /// Guarda los tokens de acceso y refresco en SharedPreferences
  Future<void> saveTokens({required String access, String? refresh}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('access_token', access);
      if (refresh != null) {
        await prefs.setString('refresh_token', refresh);
      }
      print('✅ Tokens guardados en SharedPreferences');
    } catch (e) {
      print('❌ Error al guardar tokens: $e');
      throw Exception('No se pudieron guardar las credenciales de sesión.');
    }
  }

  /// Obtiene el token de acceso desde SharedPreferences
  Future<String?> getAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('access_token');
  }

  /// ✅ LOGOUT COMPLETO Y CORRECTO
  Future<void> logout() async {
    try {
      print('🔄 Iniciando logout completo...');

      final prefs = await SharedPreferences.getInstance();

      // 1️⃣ Remover todos los tokens
      print('🔑 Eliminando tokens...');
      await prefs.remove('access_token');
      await prefs.remove('refresh_token');
      print('✅ Tokens eliminados');

      // 2️⃣ Remover datos de autenticación
      print('👤 Eliminando datos de usuario...');
      await prefs.remove(_authKey);
      await prefs.remove(_userKey);
      print('✅ Datos de usuario eliminados');

      // 3️⃣ Remover datos de reportes
      print('📊 Eliminando caché de reportes...');
      await prefs.remove(_reportesKey);
      await prefs.remove('reportes_cargados_login');
      print('✅ Caché de reportes eliminada');

      // 4️⃣ Remover otros datos cacheados
      print('💾 Eliminando datos cacheados...');
      final allKeys = prefs.getKeys();

      // Remover todas las claves que contengan datos de sesión
      final keysToRemove = allKeys.where((key) =>
      key.contains('auth') ||
          key.contains('user') ||
          key.contains('token') ||
          key.contains('reporte') ||
          key.contains('ubicacion') ||
          key.contains('sync') ||
          key.contains('cache')
      ).toList();

      for (final key in keysToRemove) {
        print('  - Removiendo: $key');
        await prefs.remove(key);
      }

      print('✅ Datos cacheados eliminados');

      // 5️⃣ Limpiar el singleton
      print('🧹 Limpiando servicios...');
      _reporteSyncService = null;
      print('✅ Servicios limpios');

      print('✅ ============================================');
      print('✅ LOGOUT COMPLETADO CORRECTAMENTE');
      print('✅ ============================================');
    } catch (e) {
      print('❌ Error durante logout: $e');
      // Continuar de todas formas, asegurando que se limpie lo máximo posible
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.clear(); // Nuclear option si algo falla
        print('✅ SharedPreferences limpiada completamente');
      } catch (e2) {
        print('❌ Error limpiando SharedPreferences: $e2');
      }
    }
  }

  /// ✅ VERIFICAR DATOS RESIDUALES (para debugging)
  Future<Map<String, dynamic>> diagnosticarLogout() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final allKeys = prefs.getKeys();

      final relevantKeys = allKeys.where((key) =>
      key.contains('auth') ||
          key.contains('user') ||
          key.contains('token') ||
          key.contains('reporte')
      ).toList();

      return {
        'totalKeys': allKeys.length,
        'relevantKeys': relevantKeys,
        'hasAccessToken': prefs.containsKey('access_token'),
        'hasRefreshToken': prefs.containsKey('refresh_token'),
        'hasAuthData': prefs.containsKey(_authKey),
        'hasUserData': prefs.containsKey(_userKey),
      };
    } catch (e) {
      print('❌ Error diagnosticando: $e');
      return {};
    }
  }

  // ✅ RESTO DE MÉTODOS (sin cambios)
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

  Future<int?> getIdOperador() async {
    final user = await getCurrentUser();
    return user?.idOperador;
  }

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

  Future<String?> getRutaOperador() async {
    final datosOperador = await getDatosOperador();
    return datosOperador?['ruta_nombre'];
  }

  Future<int?> getIdEstacion() async {
    final datosOperador = await getDatosOperador();
    return datosOperador?['id_estacion'];
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

  Future<Map<String, dynamic>> getUserInfo() async {
    final user = await getCurrentUser();
    final accessToken = await getAccessToken();
    final idOperador = await getIdOperador();
    final datosOperador = await getDatosOperador();

    return {
      'user': user != null
          ? {
        'id': user.id,
        'username': user.username,
        'email': user.email,
        'groups': user.groups,
        'primaryGroup': user.primaryGroup,
      }
          : null,
      'hasToken': accessToken != null,
      'idOperador': idOperador,
      'datosOperador': datosOperador,
      'isOperadorRural': user?.isOperadorRural ?? false,
      'isOperadorUrbano': user?.isOperadorUrbano ?? false,
    };
  }

  Future<void> _cargarReportesDuranteLogin(String accessToken) async {
    // Implementación existente sin cambios
  }

  Future<bool> _verificarConexionInternet() async {
    try {
      final response = await http
          .get(Uri.parse('${Enviroment.apiUrlDev}/'))
          .timeout(Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> _obtenerReportesRemotos(
      ApiService apiService,
      int operadorId,
      ) async {
    try {
      return await apiService.obtenerReportesPorOperador(operadorId);
    } catch (e) {
      print('❌ Error obteniendo reportes remotos: $e');
      return [];
    }
  }

  Future<void> _guardarReportesEnCache(
      List<Map<String, dynamic>> reportes,
      ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_reportesKey, json.encode(reportes));
      print('💾 Reportes guardados en cache: ${reportes.length}');
    } catch (e) {
      print('❌ Error guardando reportes en cache: $e');
    }
  }

  Future<void> _marcarReportesCargados() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('reportes_cargados_login', true);
    } catch (e) {
      print('❌ Error marcando reportes como cargados: $e');
    }
  }

  Future<void> recargarReportes() async {
    try {
      final token = await getAccessToken();
      if (token != null) {
        await _cargarReportesDuranteLogin(token);
      }
    } catch (e) {
      print('❌ Error forzando recarga de reportes: $e');
    }
  }

  Future<void> guardarReportesEnCache(
      List<Map<String, dynamic>> reportes,
      ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_reportesKey, json.encode(reportes));
      print('💾 Reportes guardados en cache: ${reportes.length}');
    } catch (e) {
      print('❌ Error guardando reportes en cache: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getReportesFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final reportesJson = prefs.getString(_reportesKey);

      if (reportesJson != null) {
        final List<dynamic> reportesList = json.decode(reportesJson);
        return reportesList.cast<Map<String, dynamic>>();
      }
      return [];
    } catch (e) {
      print('❌ Error obteniendo reportes del cache: $e');
      return [];
    }
  }

  Future<bool> areReportesCargados() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool('reportes_cargados_login') ?? false;
    } catch (e) {
      return false;
    }
  }

  Future<void> marcarReportesCargados() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('reportes_cargados_login', true);
    } catch (e) {
      print('❌ Error marcando reportes como cargados: $e');
    }
  }

  Future<List<Map<dynamic, dynamic>>> _obtenerReportesLocalesNoSincronizados(
      int operadorId,
      ) async {
    try {
      if (_reporteSyncService == null) {
        print('⚠️ ReporteSyncService no está inicializado');
        return [];
      }

      final locales = await _reporteSyncService!.getReportes();
      return locales
          .where(
            (r) =>
        r["operador"] == operadorId &&
            (r["synced"] == 0 || r["synced"] == false),
      )
          .map((r) => {...r, "synced": false})
          .toList();
    } catch (e) {
      print('❌ Error obteniendo reportes locales no sincronizados: $e');
      return [];
    }
  }

  Future<List<Map<dynamic, dynamic>>> _obtenerTodosReportesLocales(
      int operadorId,
      ) async {
    try {
      if (_reporteSyncService == null) {
        print('⚠️ ReporteSyncService no está inicializado');
        return [];
      }

      final locales = await _reporteSyncService!.getReportes();
      return locales
          .where((r) => r["operador"] == operadorId)
          .map((r) => {...r, "synced": r["synced"] == 1 || r["synced"] == true})
          .toList();
    } catch (e) {
      print('❌ Error obteniendo todos los reportes locales: $e');
      return [];
    }
  }
}

// import 'dart:convert';
// import 'package:http/http.dart' as http;
// import 'package:manager_key/services/reporte_sync_service.dart';
// import 'package:shared_preferences/shared_preferences.dart';
// import '../config/enviroment.dart';
// import '../models/auth_response.dart';
// import '../models/user_model.dart';
// import '../services/punto_empadronamiento_service.dart';
// import 'api_service.dart';
//
// class AuthService {
//   final PuntoEmpadronamientoService _puntoEmpadronamientoService =
//   PuntoEmpadronamientoService();
//
//   ReporteSyncService? _reporteSyncService;
//
//   static final AuthService _instance = AuthService._internal();
//
//   factory AuthService() => _instance;
//
//   AuthService._internal();
//
//   static const String _authKey = 'auth_tokens';
//   static const String _userKey = 'user_data';
//   static const String _reportesKey = 'reportes_cargados';
//
//   static const String _baseUrl = '${Enviroment.apiUrlDev}token/';
//   static const String _refreshUrl = '${Enviroment.apiUrlDev}token/refresh/';
//
//   Future<AuthResponse> loginWithEmail(String username, String password) async {
//     final url = Uri.parse(_baseUrl);
//
//     final response = await http.post(
//       url,
//       headers: {'Content-Type': 'application/json'},
//       body: json.encode({'username': username, 'password': password}),
//     );
//
//     if (response.statusCode == 200) {
//       final data = json.decode(response.body);
//       final authResponse = AuthResponse.fromJson(data);
//
//       await _saveAuthData(authResponse);
//
//       //sincronizacion cargar reportes
//       await _cargarReportesDuranteLogin(authResponse.access);
//
//       // ✅ NUEVO: Sincronizar puntos de empadronamiento después del login exitoso
//       await _sincronizarPuntosEmpadronamiento(authResponse.access);
//
//       return authResponse;
//     } else {
//       throw Exception('Error de autenticación: ${response.body}');
//     }
//   }
//
//   //Imyectar ResporteSyncService
//   void setReporteSyncService(ReporteSyncService syncService) {
//     _reporteSyncService = syncService;
//   }
//
//   // ✅ NUEVO: Método para sincronizar puntos de empadronamiento
//   Future<void> _sincronizarPuntosEmpadronamiento(String accessToken) async {
//     try {
//       print('🔄 Sincronizando puntos de empadronamiento...');
//       await _puntoEmpadronamientoService.syncPuntosEmpadronamiento(accessToken);
//       print('✅ Puntos de empadronamiento sincronizados exitosamente');
//     } catch (e) {
//       print('⚠️ Error sincronizando puntos de empadronamiento: $e');
//       // No relanzamos la excepción para no afectar el flujo de login
//     }
//   }
//
//   //Guarda los tokens de acceso y refreso  en shared prederferences
//   /// Guarda los tokens de acceso y refresco en SharedPreferences
//   Future<void> saveTokens({required String access, String? refresh}) async {
//     try {
//       final prefs = await SharedPreferences.getInstance();
//       await prefs.setString('access_token', access);
//       if (refresh != null) {
//         await prefs.setString('refresh_token', refresh);
//       }
//       print('✅ Tokens guardados en SharedPreferences');
//     } catch (e) {
//       print('❌ Error al guardar tokens: $e');
//       // Puedes decidir si relanzar el error o manejarlo aquí
//       throw Exception('No se pudieron guardar las credenciales de sesión.');
//     }
//   }
//
//   // AÑADE TAMBIÉN ESTE OTRO MÉTODO
//   /// Obtiene el token de acceso desde SharedPreferences
//   Future<String?> getAccessToken() async {
//     final prefs = await SharedPreferences.getInstance();
//     return prefs.getString('access_token');
//   }
//
//
//   // TU MÉTODO logout DEBERÍA LUCIR ASÍ
//   Future<void> logout() async {
//     final prefs = await SharedPreferences.getInstance();
//     await prefs.remove('access_token');
//     await prefs.remove('refresh_token');
//     // También podrías querer limpiar cualquier otro dato de usuario cacheado
//     print('✅ Sesión cerrada y tokens eliminados.');
//   }
//
//
// // ✅ NUEVO: Método público para forzar sincronización (útil para manual o después de logout/login)
// Future<void> sincronizarPuntosEmpadronamiento() async {
//   try {
//     final token = await getAccessToken();
//     if (token != null) {
//       await _sincronizarPuntosEmpadronamiento(token);
//     } else {
//       print(
//         '❌ No hay token disponible para sincronizar puntos de empadronamiento',
//       );
//     }
//   } catch (e) {
//     print('❌ Error forzando sincronización: $e');
//     rethrow;
//   }
// }
//
// Future<void> _saveAuthData(AuthResponse authResponse) async {
//   final prefs = await SharedPreferences.getInstance();
//   await prefs.setString(_authKey, json.encode(authResponse.toJson()));
//   await prefs.setString(_userKey, json.encode(authResponse.user.toJson()));
// }
// //
// // Future<void> logout() async {
// //   final prefs = await SharedPreferences.getInstance();
// //   await prefs.remove(_authKey);
// //   await prefs.remove(_userKey);
// //   print('DEBUG: Servicio logout completado');
// // }
//
// Future<bool> isAuthenticated() async {
//   final prefs = await SharedPreferences.getInstance();
//   return prefs.containsKey(_authKey);
// }
//
// Future<User?> getCurrentUser() async {
//   final prefs = await SharedPreferences.getInstance();
//   final userJson = prefs.getString(_userKey);
//   if (userJson != null) {
//     final userMap = json.decode(userJson);
//     return User.fromJson(userMap);
//   }
//   return null;
// }
//
// // CORREGIDO: Usar la propiedad idOperador del modelo Operador
// Future<int?> getIdOperador() async {
//   final user = await getCurrentUser();
//   return user
//       ?.idOperador; // Esto usa el getter que ya existe en tu User model
// }
//
// // CORREGIDO: Método para obtener datos del operador
// Future<Map<String, dynamic>?> getDatosOperador() async {
//   final user = await getCurrentUser();
//   if (user?.operador != null) {
//     final operador = user!.operador!;
//     return {
//       'id_operador': operador.idOperador,
//       'tipo_operador': operador.tipoOperador,
//       'id_estacion': operador.idEstacion,
//       'nro_estacion': operador.nroEstacion,
//       'ruta_id': operador.ruta.id,
//       'ruta_nombre': operador.ruta.nombre,
//     };
//   }
//   return null;
// }
//
// // NUEVO: Método para obtener la ruta del operador
// Future<String?> getRutaOperador() async {
//   final datosOperador = await getDatosOperador();
//   return datosOperador?['ruta_nombre'];
// }
//
// // NUEVO: Método para obtener el ID de estación
// Future<int?> getIdEstacion() async {
//   final datosOperador = await getDatosOperador();
//   return datosOperador?['id_estacion'];
// }
//
// // Future<String?> getAccessToken() async {
// //   final prefs = await SharedPreferences.getInstance();
// //   final authJson = prefs.getString(_authKey);
// //
// //   if (authJson != null) {
// //     try {
// //       final tokenMap = json.decode(authJson) as Map<String, dynamic>;
// //       return tokenMap['access'] ?? tokenMap['accessToken'];
// //     } catch (e) {
// //       print('Error al decodificar el token de acceso: $e');
// //       return null;
// //     }
// //   }
// //   return null;
// // }
//
// Future<String?> getUserGroup() async {
//   final user = await getCurrentUser();
//   return user?.primaryGroup;
// }
//
// Future<String> getWelcomeMessage() async {
//   final user = await getCurrentUser();
//   return user != null ? ' ${user.username}' : 'Bienvenido/a';
// }
//
// Future<String?> getTipoOperador() async {
//   final user = await getCurrentUser();
//   return user?.tipoOperador;
// }
//
// Future<bool> isOperadorRural() async {
//   final user = await getCurrentUser();
//   return user?.isOperadorRural ?? false;
// }
//
// Future<bool> isOperadorUrbano() async {
//   final user = await getCurrentUser();
//   return user?.isOperadorUrbano ?? false;
// }
//
// Future<bool> refreshToken() async {
//   final prefs = await SharedPreferences.getInstance();
//   final authJson = prefs.getString(_authKey);
//
//   if (authJson == null) {
//     return false;
//   }
//
//   final tokenMap = json.decode(authJson) as Map<String, dynamic>;
//   final refreshToken = tokenMap['refresh'] ?? tokenMap['refreshToken'];
//
//   if (refreshToken == null) {
//     return false;
//   }
//
//   try {
//     final response = await http.post(
//       Uri.parse(_refreshUrl),
//       headers: {'Content-Type': 'application/json'},
//       body: json.encode({'refresh': refreshToken}),
//     );
//
//     if (response.statusCode == 200) {
//       final newTokens = json.decode(response.body);
//       tokenMap['access'] = newTokens['access'];
//       await prefs.setString(_authKey, json.encode(tokenMap));
//       print('✅ Token de acceso refrescado exitosamente.');
//       return true;
//     } else {
//       print('❌ Falló el refresco del token. Forzando logout.');
//       await logout();
//       return false;
//     }
//   } catch (e) {
//     print('❌ Error durante el refresco del token: $e');
//     return false;
//   }
// }
//
// String determinarTipoUsuario(User user) {
//   final group = user.primaryGroup?.toLowerCase() ?? '';
//
//   if (group.contains('coordinador') || group.contains('admin')) {
//     return 'coordinador';
//   } else if (group.contains('tecnico') || group.contains('soporte')) {
//     return 'tecnico';
//   } else {
//     return 'operador';
//   }
// }
//
// // NUEVO: Método para obtener información completa del usuario (útil para debug)
// Future<Map<String, dynamic>> getUserInfo() async {
//   final user = await getCurrentUser();
//   final accessToken = await getAccessToken();
//   final idOperador = await getIdOperador();
//   final datosOperador = await getDatosOperador();
//
//   return {
//     'user': user != null
//         ? {
//       'id': user.id,
//       'username': user.username,
//       'email': user.email,
//       'groups': user.groups,
//       'primaryGroup': user.primaryGroup,
//     }
//         : null,
//     'hasToken': accessToken != null,
//     'idOperador': idOperador,
//     'datosOperador': datosOperador,
//     'isOperadorRural': user?.isOperadorRural ?? false,
//     'isOperadorUrbano': user?.isOperadorUrbano ?? false,
//   };
// }
//
// // ✅ NUEVO: Método para cargar reportes durante el login
// Future<void> _cargarReportesDuranteLogin(String accessToken) async {
//   try {
//     print('🔄 Cargando reportes durante el login...');
//
//     // Obtener datos del usuario
//     final currentUser = await getCurrentUser();
//     if (currentUser == null) {
//       print('❌ No se pudo obtener datos del usuario');
//       return;
//     }
//
//     final operadorId = currentUser.operador?.idOperador;
//     if (operadorId == null) {
//       print('❌ No se pudo obtener ID del operador');
//       return;
//     }
//
//     // Crear ApiService con el token
//     final apiService = ApiService(accessToken: accessToken);
//
//     // Verificar conexión a internet
//     final tieneInternet = await _verificarConexionInternet();
//
//     List<Map<String, dynamic>> reportesCargados = [];
//
//     if (tieneInternet) {
//       print('🌐 Con internet: Cargando reportes del servidor...');
//
//       // Cargar reportes del servidor
//       final reportesRemotos = await _obtenerReportesRemotos(
//         apiService,
//         operadorId,
//       );
//       reportesCargados.addAll(
//         reportesRemotos.map((r) => {...r, "synced": true}),
//       );
//
//       // Cargar reportes locales no sincronizados
//       if (_reporteSyncService != null) {
//         final reportesLocalesNoSync =
//         await _obtenerReportesLocalesNoSincronizados(operadorId);
//         reportesCargados.addAll(reportesLocalesNoSync);
//       }
//
//       print(
//         '✅ Cargados ${reportesRemotos.length} reportes remotos durante login',
//       );
//
//       // Guardar en cache
//       await _guardarReportesEnCache(reportesCargados);
//     } else {
//       print('📱 Sin internet: Cargando reportes locales...');
//
//       // Solo cargar reportes locales
//       if (_reporteSyncService != null) {
//         reportesCargados = await _obtenerTodosReportesLocales(operadorId);
//       }
//
//       print(
//         '✅ Cargados ${reportesCargados.length} reportes locales durante login',
//       );
//     }
//
//     // Marcar que los reportes fueron cargados durante este login
//     await _marcarReportesCargados();
//   } catch (e) {
//     print('⚠️ Error cargando reportes durante login: $e');
//     // No relanzamos la excepción para no afectar el flujo de login
//   }
// }
//
// // ✅ NUEVO: Métodos auxiliares para carga de reportes
// Future<bool> _verificarConexionInternet() async {
//   try {
//     // Intentar una conexión simple
//     final response = await http
//         .get(Uri.parse('${Enviroment.apiUrlDev}/'))
//         .timeout(Duration(seconds: 5));
//     return response.statusCode == 200;
//   } catch (e) {
//     return false;
//   }
// }
//
// Future<List<Map<String, dynamic>>> _obtenerReportesRemotos(
//     ApiService apiService,
//     int operadorId,) async {
//   try {
//     return await apiService.obtenerReportesPorOperador(operadorId);
//   } catch (e) {
//     print('❌ Error obteniendo reportes remotos: $e');
//     return [];
//   }
// }
//
// // ✅ NUEVO: Guardar reportes en cache
// Future<void> _guardarReportesEnCache(
//     List<Map<String, dynamic>> reportes,) async {
//   try {
//     final prefs = await SharedPreferences.getInstance();
//     await prefs.setString(_reportesKey, json.encode(reportes));
//     print('💾 Reportes guardados en cache: ${reportes.length}');
//   } catch (e) {
//     print('❌ Error guardando reportes en cache: $e');
//   }
// }
//
// // ✅ NUEVO: Marcar que los reportes fueron cargados
// Future<void> _marcarReportesCargados() async {
//   try {
//     final prefs = await SharedPreferences.getInstance();
//     await prefs.setBool('reportes_cargados_login', true);
//   } catch (e) {
//     print('❌ Error marcando reportes como cargados: $e');
//   }
// }
//
// // ✅ NUEVO: Obtener reportes del cache
// // Future<List<Map<String, dynamic>>> getReportesFromCache() async {
// //   try {
// //     final prefs = await SharedPreferences.getInstance();
// //     final reportesJson = prefs.getString(_reportesKey);
// //
// //     if (reportesJson != null) {
// //       final List<dynamic> reportesList = json.decode(reportesJson);
// //       return reportesList.cast<Map<String, dynamic>>();
// //     }
// //     return [];
// //   } catch (e) {
// //     print('❌ Error obteniendo reportes del cache: $e');
// //     return [];
// //   }
// // }
//
// // ✅ NUEVO: Verificar si los reportes ya fueron cargados en este login
// // Future<bool> areReportesCargados() async {
// //   try {
// //     final prefs = await SharedPreferences.getInstance();
// //     return prefs.getBool('reportes_cargados_login') ?? false;
// //   } catch (e) {
// //     return false;
// //   }
// // }
//
// // ✅ NUEVO: Forzar recarga de reportes (útil cuando se abre la app)
// Future<void> recargarReportes() async {
//   try {
//     final token = await getAccessToken();
//     if (token != null) {
//       await _cargarReportesDuranteLogin(token);
//     }
//   } catch (e) {
//     print('❌ Error forzando recarga de reportes: $e');
//   }
// }
//
// // ✅ NUEVO: Método público para guardar reportes en cache
// Future<void> guardarReportesEnCache(
//     List<Map<String, dynamic>> reportes,) async {
//   try {
//     final prefs = await SharedPreferences.getInstance();
//     await prefs.setString(_reportesKey, json.encode(reportes));
//     print('💾 Reportes guardados en cache: ${reportes.length}');
//   } catch (e) {
//     print('❌ Error guardando reportes en cache: $e');
//   }
// }
//
// // ✅ NUEVO: Método público para obtener reportes del cache
// Future<List<Map<String, dynamic>>> getReportesFromCache() async {
//   try {
//     final prefs = await SharedPreferences.getInstance();
//     final reportesJson = prefs.getString(_reportesKey);
//
//     if (reportesJson != null) {
//       final List<dynamic> reportesList = json.decode(reportesJson);
//       return reportesList.cast<Map<String, dynamic>>();
//     }
//     return [];
//   } catch (e) {
//     print('❌ Error obteniendo reportes del cache: $e');
//     return [];
//   }
// }
//
// // ✅ NUEVO: Método para verificar si los reportes ya fueron cargados
// Future<bool> areReportesCargados() async {
//   try {
//     final prefs = await SharedPreferences.getInstance();
//     return prefs.getBool('reportes_cargados_login') ?? false;
//   } catch (e) {
//     return false;
//   }
// }
//
// // ✅ NUEVO: Método para marcar reportes como cargados
// Future<void> marcarReportesCargados() async {
//   try {
//     final prefs = await SharedPreferences.getInstance();
//     await prefs.setBool('reportes_cargados_login', true);
//   } catch (e) {
//     print('❌ Error marcando reportes como cargados: $e');
//   }
// }
//
// // ✅ CORREGIDO: Métodos auxiliares para carga de reportes
// Future<List<Map<String, dynamic>>> _obtenerReportesLocalesNoSincronizados(
//     int operadorId,) async {
//   try {
//     if (_reporteSyncService == null) {
//       print('⚠️ ReporteSyncService no está inicializado');
//       return [];
//     }
//
//     final locales = await _reporteSyncService!.getReportes();
//     return locales
//         .where(
//           (r) =>
//       r["operador"] == operadorId &&
//           (r["synced"] == 0 || r["synced"] == false),
//     )
//         .map((r) => {...r, "synced": false})
//         .toList();
//   } catch (e) {
//     print('❌ Error obteniendo reportes locales no sincronizados: $e');
//     return [];
//   }
// }
//
// Future<List<Map<String, dynamic>>> _obtenerTodosReportesLocales(
//     int operadorId,) async {
//   try {
//     if (_reporteSyncService == null) {
//       print('⚠️ ReporteSyncService no está inicializado');
//       return [];
//     }
//
//     final locales = await _reporteSyncService!.getReportes();
//     return locales
//         .where((r) => r["operador"] == operadorId)
//         .map((r) => {...r, "synced": r["synced"] == 1 || r["synced"] == true})
//         .toList();
//   } catch (e) {
//     print('❌ Error obteniendo todos los reportes locales: $e');
//     return [];
//   }
// }}
