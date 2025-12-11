import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:manager_key/services/reporte_sync_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/enviroment.dart';
import '../database/database_helper.dart';
import '../models/auth_response.dart';
import '../models/reporte_diario_historial.dart';
import '../models/reporte_diario_local.dart';
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

  // Inject ReporteSyncService
  void setReporteSyncService(ReporteSyncService syncService) {
    _reporteSyncService = syncService;
  }

  // Método para sincronizar puntos de empadronamiento
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

  /// LOGOUT COMPLETO Y CORRECTO
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

  // VERIFICAR DATOS RESIDUALES (para debugging)
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

  // RESTO DE MÉTODOS
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

  Future<void> saveOperadorData(int idOperador, int idEstacion) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('id_operador', idOperador);
    await prefs.setInt('id_estacion', idEstacion);
  }

  Future<Map<String, dynamic>?> getDatosOperador() async {
    final prefs = await SharedPreferences.getInstance();
    final idOperador = prefs.getInt('id_operador');
    final idEstacion = prefs.getInt('id_estacion');

    if (idOperador != null && idEstacion != null) {
      return {
        'id_operador': idOperador,
        'id_estacion': idEstacion,
      };
    }
    return null;
  }

  // Método para cargar reportes durante login (CORREGIDO)
  Future<void> cargarReportesDuranteLogin() async {
    try {
      final token = await getAccessToken();
      final idOperador = await getIdOperador();

      if (token == null || idOperador == null) {
        print('❌ No hay token o ID de operador');
        return;
      }

      final tieneConexion = await _verificarConexionInternet();

      if (tieneConexion) {
        // Caso 1: Con internet - cargar desde servidor y guardar en local
        print('🌐 Con internet - cargando reportes desde servidor');

        final apiService = ApiService(accessToken: token);
        final reportes = await apiService.obtenerReportesPorOperador(idOperador);

        if (reportes.isNotEmpty) {
          await _guardarReportesEnBaseDatosLocal(reportes);
          print('✅ ${reportes.length} reportes cargados del servidor');
        }
      } else {
        // Caso 2: Sin internet - usar solo base de datos local
        print('📱 Sin internet - usando reportes locales');
      }

      await marcarReportesCargados();

    } catch (e) {
      print('❌ Error cargando reportes durante login: $e');
    }
  }

  // Método auxiliar para guardar reportes en base de datos local (CORREGIDO)
  Future<void> _guardarReportesEnBaseDatosLocal(List<Map<String, dynamic>> reportes) async {
    try {
      final DatabaseHelper dbHelper = DatabaseHelper();

      for (var reporte in reportes) {
        // Primero convertir el JSON a ReporteDiarioHistorial
        final reporteHistorial = ReporteDiarioHistorial.fromJson(reporte);

        // Luego crear ReporteDiarioLocal usando un método auxiliar
        final reporteLocal = _convertirHistorialALocal(reporteHistorial);

        // Insertar en la base de datos
        await dbHelper.insertReporte(reporteLocal);
      }

      print('💾 Reportes guardados en base de datos local');
    } catch (e) {
      print('❌ Error guardando reportes en local: $e');
    }
  }

  // Método auxiliar para convertir ReporteDiarioHistorial a ReporteDiarioLocal
  ReporteDiarioLocal _convertirHistorialALocal(ReporteDiarioHistorial historial) {
    return ReporteDiarioLocal(
      id: historial.id,
      idServer: historial.idServer,
      contadorInicialR: historial.contadorInicialR,
      contadorFinalR: historial.contadorFinalR,
      saltosenR: historial.saltosenR,
      contadorR: historial.contadorR,
      contadorInicialC: historial.contadorInicialC,
      contadorFinalC: historial.contadorFinalC,
      saltosenC: historial.saltosenC,
      contadorC: historial.contadorC,
      fechaReporte: historial.fechaReporte,
      observaciones: historial.observaciones,
      incidencias: historial.incidencias,
      estado: _convertirEstadoSincronizacion(historial.estadoSincronizacion),
      idOperador: historial.idOperador,
      estacionId: historial.idEstacion,
      fechaCreacion: historial.fechaCreacion,
      fechaSincronizacion: historial.fechaSincronizacion,
      observacionC: historial.observacionC,
      observacionR: historial.observacionR,
      centroEmpadronamiento: historial.centroEmpadronamiento,
    );
  }

  // Método auxiliar para convertir EstadoSincronizacion a string
  String _convertirEstadoSincronizacion(EstadoSincronizacion estado) {
    switch (estado) {
      case EstadoSincronizacion.sincronizado:
        return 'sincronizado';
      case EstadoSincronizacion.pendiente:
        return 'pendiente';
      case EstadoSincronizacion.fallido:
        return 'fallido';
      default:
        return 'pendiente';
    }
  }

  // Método para obtener Map desde ReporteDiarioHistorial (si necesitas el toLocalMap)
  Map<String, dynamic> _historialToMap(ReporteDiarioHistorial historial) {
    return {
      'id': historial.id,
      'id_server': historial.idServer,
      'contador_inicial_r': historial.contadorInicialR,
      'contador_final_r': historial.contadorFinalR,
      'saltosen_r': historial.saltosenR,
      'contador_r': historial.contadorR,
      'contador_inicial_c': historial.contadorInicialC,
      'contador_final_c': historial.contadorFinalC,
      'saltosen_c': historial.saltosenC,
      'contador_c': historial.contadorC,
      'fecha_reporte': historial.fechaReporte,
      'observaciones': historial.observaciones,
      'incidencias': historial.incidencias,
      'estado': _convertirEstadoSincronizacion(historial.estadoSincronizacion),
      'id_operador': historial.idOperador,
      'estacion_id': historial.idEstacion,
      'fecha_creacion': historial.fechaCreacion.toIso8601String(),
      'fecha_sincronizacion': historial.fechaSincronizacion?.toIso8601String(),
      'observacion_c': historial.observacionC,
      'observacion_r': historial.observacionR,
      'centro_empadronamiento': historial.centroEmpadronamiento,
    };
  }

  // Método loginWithEmail para incluir la carga de reportes:
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

      // Cargar reportes durante el login
      await cargarReportesDuranteLogin();

      return authResponse;
    } else {
      throw Exception('Error de autenticación: ${response.body}');
    }
  }

  // lib/services/auth_service.dart

  /// Método principal para iniciar sesión
  Future<Map<String, dynamic>> login(String username, String password) async {
    final url = Uri.parse(_baseUrl);

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'username': username, 'password': password}),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final authResponse = AuthResponse.fromJson(data);
        final accessToken = authResponse.access;
        final refreshToken = authResponse.refresh;

        // 1. Guardar tokens y datos de usuario
        await saveTokens(access: accessToken, refresh: refreshToken);
        await _saveAuthData(authResponse);

        print('✅ Login exitoso para el usuario: ${authResponse.user.username}');

        // 2. Sincronizar puntos de empadronamiento DESPUÉS de un login exitoso
        await _sincronizarPuntosEmpadronamiento(accessToken);

        // 3. Cargar reportes del historial (si es necesario)
        await cargarReportesDuranteLogin();

        return {'success': true, 'message': 'Login exitoso'};
      } else {
        print('❌ Error de autenticación: ${response.statusCode} - ${response.body}');
        return {
          'success': false,
          'message': 'Usuario o contraseña incorrectos.'
        };
      }
    } catch (e) {
      print('❌ Error de conexión durante el login: $e');
      // Aquí se podría implementar una lógica de login offline si se deseara
      return {
        'success': false,
        'message': 'Error de conexión. Verifique su acceso a internet.'
      };
    }
  }

}