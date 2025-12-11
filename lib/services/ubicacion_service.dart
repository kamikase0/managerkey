import 'dart:async';
import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:http/http.dart' as http;
import 'package:manager_key/config/enviroment.dart';
import 'package:manager_key/services/auth_service.dart';
import 'package:manager_key/services/connectivity_service.dart';
import 'package:manager_key/services/database_service.dart';
import 'package:manager_key/services/location_service.dart';

import '../models/ubicacion_model.dart';

class UbicacionService {
  late LocationService _locationService;
  late ConnectivityService _connectivityService;
  late DatabaseService _databaseService;
  late AuthService _authService;

  Timer? _locationTimer;
  bool _isInitialized = false;

  UbicacionService() {
    _authService = AuthService();
  }

  void initialize({
    required LocationService locationService,
    required ConnectivityService connectivityService,
    required DatabaseService databaseService,
  }) {
    _locationService = locationService;
    _connectivityService = connectivityService;
    _databaseService = databaseService;
    _isInitialized = true;
    print('DEBUG: UbicacionService inicializado');
  }

  /// Obtener usuario actual desde SharedPreferences
  Future<String> _obtenerUsuarioActual() async {
    try {
      final authService = AuthService();
      final usuario = await authService.getUserInfo();
      return usuario['username'] ?? 'operador';
    } catch (e) {
      print('⚠️ Error obteniendo usuario: $e');
      return 'operador';
    }
  }

  /// Obtener operador ID actual desde SharedPreferences
  Future<int> _obtenerOperadorId() async {
    try {
      final authService = AuthService();
      final usuario = await authService.getUserInfo();
      return usuario['idOperador'] ?? 0;
    } catch (e) {
      print('⚠️ Error obteniendo ID operador: $e');
      return 1;
    }
  }

  /// Registrar ubicación actual
  Future<void> registrarUbicacion() async {
    if (!_isInitialized) {
      print('⚠️ UbicacionService no inicializado');
      return;
    }

    try {
      print('DEBUG: 📍 INICIANDO REGISTRO DE UBICACIÓN');
      print('DEBUG: 🔍 Solicitando ubicación actual...');

      // ✅ CORRECCIÓN: Verificar si la ubicación es null
      final ubicacion = await _locationService.getCurrentLocation();

      if (ubicacion == null) {
        print('❌ Error: No se pudo obtener la ubicación (es nula)');
        return;
      }

      final operadorId = await _obtenerOperadorId();
      final usuario = await _obtenerUsuarioActual();

      print('DEBUG: 🌍 Ubicación obtenida: Lat ${ubicacion.latitude}, Lng ${ubicacion.longitude}');
      print('DEBUG: 🕐 Hora de captura: ${DateTime.now()}');

      // Crear modelo de ubicación
      final ubicacionModel = UbicacionModel(
        userId: operadorId,
        latitud: ubicacion.latitude,
        longitud: ubicacion.longitude,
        timestamp: DateTime.now(),
        tipoUsuario: usuario,
      );

      print('📍 Ubicación Model Debug:');
      print('  - ID: ${ubicacionModel.id}');
      print('  - User ID: ${ubicacionModel.userId}');
      print('  - Latitud: ${ubicacionModel.latitud}');
      print('  - Longitud: ${ubicacionModel.longitud}');
      print('  - Timestamp: ${ubicacionModel.timestamp}');
      print('  - Tipo Usuario: ${ubicacionModel.tipoUsuario}');
      print('  - Sincronizado: ${ubicacionModel.sincronizado}');

      print('DEBUG: ✅ Ubicación obtenida: ${ubicacion.latitude}, ${ubicacion.longitude}');

      // Verificar conexión
      final tieneInternet = await _connectivityService.hasInternetConnection();
      print('DEBUG: 🌐 Estado conexión: ${tieneInternet ? "CONECTADO" : "SIN CONEXIÓN"}');

      if (tieneInternet) {
        // Intentar enviar directamente a API
        await _sincronizarYEnviarUbicacion(ubicacionModel);
      } else {
        // Guardar localmente si no hay internet
        await _databaseService.guardarUbicacionLocal(ubicacionModel);
        print('💾 Ubicación guardada en base de datos local');
      }

      // Mostrar estadísticas
      await _mostrarEstadisticas();
    } catch (e) {
      print('❌ Error registrando ubicación: $e');
    }
  }

  /// Sincronizar ubicación y enviar a API
  Future<void> _sincronizarYEnviarUbicacion(UbicacionModel ubicacion) async {
    try {
      final token = await AuthService().getAccessToken();
      if (token == null || token.isEmpty) {
        // Guardar localmente si no hay token
        await _databaseService.guardarUbicacionLocal(ubicacion);
        print('⚠️ Token no disponible, ubicación guardada localmente');
        return;
      }

      // ✅ CORRECCIÓN: JSON EN EL FORMATO CORRECTO
      final datosApi = {
        'latitud': ubicacion.latitud.toString(),
        'longitud': ubicacion.longitud.toString(),
        'fecha': ubicacion.timestamp.toIso8601String(),
        'operador': ubicacion.userId,
        'user': ubicacion.tipoUsuario,
      };

      print('DEBUG: 📤 Enviando ubicación actual a API...');
      print('DEBUG: 📨 Enviando a API: ${Enviroment.apiUrlDev}ubicaciones-operador/');
      print('DEBUG: 🕐 HORA REAL CAPTURA: ${ubicacion.timestamp}');
      print('DEBUG: 🕐 HORA ACTUAL ENVÍO: ${DateTime.now()}');
      print('DEBUG: ⏱️  DIFERENCIA: ${DateTime.now().difference(ubicacion.timestamp).inSeconds} segundos');
      print('DEBUG: 📦 JSON a enviar: ${jsonEncode(datosApi)}');
      print('DEBUG: 🔑 Token: ${token.substring(0, 20)}...');

      final response = await http.post(
        Uri.parse('${Enviroment.apiUrlDev}ubicaciones-operador/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(datosApi),
      ).timeout(const Duration(seconds: 15));

      print('DEBUG: 📡 Respuesta API - Status: ${response.statusCode}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        print('✅ Ubicación enviada exitosamente a API');
        print('DEBUG: 📝 Body: ${response.body}');
      } else {
        print('DEBUG: ❌ Error API: ${response.statusCode}');
        print('DEBUG: 📝 Body: ${response.body}');
        // Guardar localmente si hay error
        await _databaseService.guardarUbicacionLocal(ubicacion);
        print('💾 Ubicación guardada localmente por error en API');
      }
    } catch (e) {
      print('ERROR enviando a API, guardando ubicación actual localmente: $e');
      // Guardar localmente en caso de error
      await _databaseService.guardarUbicacionLocal(ubicacion);
      print('✅ Ubicación guardada localmente con ID');
    }
  }

  /// Sincronizar ubicaciones pendientes desde BD local
  Future<void> sincronizarUbicacionesPendientes() async {
    try {
      final tieneInternet = await _connectivityService.hasInternetConnection();
      if (!tieneInternet) {
        print('⚠️ Sin conexión, no se pueden sincronizar ubicaciones pendientes');
        return;
      }

      final token = await AuthService().getAccessToken();
      if (token == null || token.isEmpty) {
        print('⚠️ Token no disponible para sincronización');
        return;
      }

      print('🔄 Sincronizando ubicaciones pendientes desde BD local...');
      final ubicacionesPendientes = await _databaseService.obtenerUbicacionesPendientes();

      if (ubicacionesPendientes.isEmpty) {
        print('✅ No hay ubicaciones pendientes');
        return;
      }

      print('🔄 Sincronizando ${ubicacionesPendientes.length} ubicaciones pendientes');

      int sincronizadas = 0;
      int fallidas = 0;

      for (final ubicacion in ubicacionesPendientes) {
        try {
          // ✅ CORRECCIÓN: JSON EN EL FORMATO CORRECTO
          final datosApi = {
            'latitud': ubicacion.latitud.toString(),
            'longitud': ubicacion.longitud.toString(),
            'fecha': ubicacion.timestamp.toIso8601String(),
            'operador': ubicacion.userId,
            'user': ubicacion.tipoUsuario,
          };

          print('DEBUG: 🔄 Sincronizando ubicación ID: ${ubicacion.id}');
          print('DEBUG: 🕐 Hora original captura: ${ubicacion.timestamp}');
          print('DEBUG: ⏱️  Tiempo desde captura: ${DateTime.now().difference(ubicacion.timestamp).inMinutes} minutos');
          print('DEBUG: 📨 Enviando a API: ${Enviroment.apiUrlDev}ubicaciones-operador/');
          print('DEBUG: 🕐 HORA REAL CAPTURA: ${ubicacion.timestamp}');
          print('DEBUG: 🕐 HORA ACTUAL ENVÍO: ${DateTime.now()}');
          print('DEBUG: ⏱️  DIFERENCIA: ${DateTime.now().difference(ubicacion.timestamp).inSeconds} segundos');
          print('DEBUG: 📦 JSON a enviar: ${jsonEncode(datosApi)}');
          print('DEBUG: 🔑 Token: ${token.substring(0, 20)}...');

          final response = await http.post(
            Uri.parse('${Enviroment.apiUrlDev}ubicaciones-operador/'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode(datosApi),
          ).timeout(const Duration(seconds: 15));

          print('DEBUG: 📡 Respuesta API - Status: ${response.statusCode}');

          if (response.statusCode == 200 || response.statusCode == 201) {
            await _databaseService.marcarUbicacionSincronizada(ubicacion.id!);
            sincronizadas++;
            print('✅ Ubicación ${ubicacion.id} sincronizada');
          } else {
            fallidas++;
            print('DEBUG: ❌ Error API: ${response.statusCode}');
            print('DEBUG: 📝 Body: ${response.body}');
          }
        } catch (e) {
          fallidas++;
          print('ERROR sincronizando ubicación ${ubicacion.id}: $e');
        }
      }

      print('DEBUG: ✅ Sincronización completada - $sincronizadas ubicaciones procesadas');
      print('📊 Resultado: $sincronizadas sincronizadas, $fallidas fallidas');
    } catch (e) {
      print('❌ Error en sincronización de ubicaciones pendientes: $e');
    }
  }

  /// Iniciar captura automática de ubicaciones
  void iniciarCapturaAutomatica({Duration intervalo = const Duration(minutes: 15)}) {
    if (_locationTimer != null) {
      print('⚠️ Captura automática ya está activa');
      return;
    }

    print('🚀 Iniciando captura automática de ubicaciones cada ${intervalo.inMinutes} minutos');

    _locationTimer = Timer.periodic(intervalo, (_) async {
      print('DEBUG: ⏰ TIMER EJECUTADO - Registrando ubicación automática');
      await registrarUbicacion();
      await sincronizarUbicacionesPendientes();
    });
  }

  /// Detener captura automática
  void detenerCapturaAutomatica() {
    _locationTimer?.cancel();
    _locationTimer = null;
    print('⏹️ Captura automática detenida');
  }

  /// Mostrar estadísticas de ubicaciones
  Future<void> _mostrarEstadisticas() async {
    try {
      final stats = await _databaseService.obtenerEstadisticasUbicaciones();
      print('DEBUG: 📊 ESTADÍSTICAS DE UBICACIONES');
      print('DEBUG: 📊 Total: ${stats['total']}');
      print('DEBUG: 📊 Pendientes: ${stats['pendientes']}');
      print('DEBUG: 📊 Más antigua: ${stats['mas_antigua']}');

      // Mostrar últimas ubicaciones pendientes
      final ubicacionesPendientes = await _databaseService.obtenerUbicacionesPendientes();
      if (ubicacionesPendientes.isNotEmpty) {
        print('DEBUG: 📊 Ubicaciones pendientes:');
        final ultimas = ubicacionesPendientes.take(15);
        for (final ub in ultimas) {
          final minutosDesdeCaptura = DateTime.now().difference(ub.timestamp).inMinutes;
          print('DEBUG: 📊 - ID: ${ub.id}, Captura: ${ub.timestamp}, Minutos desde captura: $minutosDesdeCaptura');
        }
      }
    } catch (e) {
      print('⚠️ Error obteniendo estadísticas: $e');
    }
  }

  /// Obtener ubicaciones pendientes
  Future<List<UbicacionModel>> obtenerUbicacionesPendientes() {
    return _databaseService.obtenerUbicacionesPendientes();
  }

  void dispose() {
    detenerCapturaAutomatica();
  }
}