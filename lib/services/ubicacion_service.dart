import 'dart:async';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/ubicacion_model.dart';
import 'location_service.dart';
import 'connectivity_service.dart';
import 'database_service.dart';
import 'auth_service.dart';
import '../config/enviroment.dart';

class UbicacionService {
  static final UbicacionService _instance = UbicacionService._internal();
  factory UbicacionService() => _instance;
  UbicacionService._internal();

  LocationService? _locationService;
  ConnectivityService? _connectivityService;
  DatabaseService? _databaseService;


  Timer? _timer;
  int? _currentIdOperador; // CAMBIADO: Ahora guardamos el id_operador
  String? _currentUserType;

  static const String _apiUrl = '${Enviroment.apiUrlGeo}ubicaciones-operador/';

  void initialize({
    required LocationService locationService,
    required ConnectivityService connectivityService,
    required DatabaseService databaseService,
  }) {
    _locationService = locationService;
    _connectivityService = connectivityService;
    _databaseService = databaseService;
    print('DEBUG: UbicacionService inicializado');
  }

  // MODIFICADO: Ahora recibe idOperador directamente
  void iniciarServicioUbicacion(int? idOperador, String userType, String accessToken) {
    _currentIdOperador = idOperador;
    _currentUserType = userType;


    if(idOperador == null ){
      print('ERROR: ID Operador es null, no se puede iniciar el servicio');
      return;
    }

    _currentIdOperador = idOperador;
    _currentUserType = userType;

    print('DEBUG: 🚀 INICIANDO SERVICIO DE UBICACIÓN');
    print('DEBUG: ID Operador: $idOperador, Tipo: $userType');


    // Registrar ubicación inmediatamente
    _registrarUbicacion(accessToken);

    // Programar registro cada minutos
    _timer = Timer.periodic(const Duration(minutes: 15), (timer) {
      print('DEBUG: ⏰ TIMER EJECUTADO - Registrando ubicación automática');
      _registrarUbicacion(accessToken);
    });

    print('DEBUG: Servicio de ubicación iniciado para $userType - ID Operador: $idOperador');
  }

  void detenerServicioUbicacion() {
    _timer?.cancel();
    _timer = null;
    _currentIdOperador = null;
    _currentUserType = null;
    print('DEBUG: Servicio de ubicación detenido');
  }

  // En tu método _registrarUbicacion, agrega:
  Future<void> _registrarUbicacion(String accessToken) async {
    try {
      print('DEBUG: 📍 INICIANDO REGISTRO DE UBICACIÓN');
      final ubicacion = await _obtenerUbicacionActual();
      if (ubicacion != null) {
        print('DEBUG: ✅ Ubicación obtenida: ${ubicacion.latitud}, ${ubicacion.longitud}');
        await _guardarUbicacion(ubicacion, accessToken);
        print('DEBUG: 📍 Ubicación registrada - ${ubicacion.timestamp}');

        // VERIFICAR estado después del registro
        await verificarEstadoUbicaciones();
      } else {
        print('DEBUG: ❌ No se pudo obtener la ubicación');
      }
    } catch (e) {
      print('ERROR al registrar ubicación: $e');
    }
  }

  Future<void> _guardarUbicacion(UbicacionModel ubicacion, String accessToken) async {
    if (_connectivityService == null || _databaseService == null) {
      throw Exception('Servicios no inicializados');
    }

    final tieneInternet = await _connectivityService!.hasInternetConnection();
    print('DEBUG: 🌐 Estado conexión: ${tieneInternet ? "CONECTADO" : "SIN INTERNET"}');

    if (tieneInternet) {
      try {
        // Intentar enviar a la API
        print('DEBUG: 📤 Enviando ubicación a API...');
        await _enviarUbicacionApi(ubicacion, accessToken);
        print('DEBUG: ✅ Ubicación enviada exitosamente a API');
      } catch (e) {
        // Si falla la API, guardar localmente
        print('ERROR enviando a API, guardando localmente: $e');
        await _guardarUbicacionLocal(ubicacion);
      }
    } else {
      // Sin internet, guardar localmente
      await _guardarUbicacionLocal(ubicacion);
      print('DEBUG: 💾 Ubicación guardada localmente (sin internet)');
    }
  }

  Future<void> _guardarUbicacionLocal(UbicacionModel ubicacion) async {
    try {
      await _databaseService!.guardarUbicacionLocal(ubicacion);
      print('DEBUG: 💾 Ubicación guardada en base de datos local');

      // Verificar que se guardó
      final pendientes = await _databaseService!.obtenerUbicacionesPendientes();
      print('DEBUG: 📊 Ubicaciones pendientes: ${pendientes.length}');
    } catch (e) {
      print('ERROR guardando ubicación local: $e');
      if (e.toString().contains('UNIQUE constraint')) {
        print('Intentando guardar sin ID...');
        final ubicacionSinId = UbicacionModel(
          userId: ubicacion.userId,
          latitud: ubicacion.latitud,
          longitud: ubicacion.longitud,
          timestamp: ubicacion.timestamp,
          tipoUsuario: ubicacion.tipoUsuario,
        );
        await _databaseService!.guardarUbicacionLocal(ubicacionSinId);
      }
    }
  }

  // NUEVO: Método para probar el servicio manualmente
  Future<void> probarRegistroManual(String accessToken) async {
    print('DEBUG: 🧪 INICIANDO PRUEBA MANUAL');
    await _registrarUbicacion(accessToken);
  }

  Future<Map<String, dynamic>> obtenerEstadisticas() async {
    final ubicacionesPendientes = _databaseService != null
        ? await _databaseService!.obtenerUbicacionesPendientes()
        : [];

    return {
      'servicioActivo': _timer != null,
      'idOperador': _currentIdOperador,
      'userType': _currentUserType,
      'ubicacionesPendientes': ubicacionesPendientes.length,
      'proximaEjecucion': _timer != null ? 'Cada 2 minutos' : 'Inactivo',
      'serviciosInicializados': _locationService != null &&
          _connectivityService != null &&
          _databaseService != null,
      'timestamp': DateTime.now().toIso8601String(),
    };
  }

  // MODIFICA tu UbicacionService - REEMPLAZA estos métodos:

  Future<UbicacionModel?> _obtenerUbicacionActual() async {
    try {
      if (_locationService == null || _currentIdOperador == null) {
        throw Exception('Servicios no inicializados o id_operador no disponible');
      }

      print('DEBUG: 🔍 Solicitando ubicación actual...');

      // CAPTURAR LA HORA ANTES de obtener la ubicación
      final horaCaptura = DateTime.now();
      final position = await _locationService!.getCurrentLocation();

      if (position == null) {
        print('ERROR: No se pudo obtener la ubicación');
        return null;
      }

      print('DEBUG: 🌍 Ubicación obtenida: Lat ${position.latitude}, Lng ${position.longitude}');
      print('DEBUG: 🕐 Hora de captura: $horaCaptura');

      // USAR el factory method que preserva la hora exacta de captura
      final ubicacion = UbicacionModel.fromPosition(
        userId: _currentIdOperador!,
        latitud: position.latitude,
        longitud: position.longitude,
        tipoUsuario: _currentUserType!,
        timestamp: horaCaptura, // ✅ Pasar la hora exacta de captura
      );

      // Log para verificar
      ubicacion.logUbicacion();

      return ubicacion;
    } catch (e) {
      print('ERROR obteniendo ubicación: $e');
      return null;
    }
  }

  Future<void> _enviarUbicacionApi(UbicacionModel ubicacion, String accessToken) async {
    try {
      final apiData = ubicacion.toApiJson(); // ✅ Este usa timestamp de captura

      // VERIFICACIÓN CRÍTICA: Mostrar ambas horas
      print('DEBUG: 📨 Enviando a API: $_apiUrl');
      print('DEBUG: 🕐 HORA REAL CAPTURA: ${ubicacion.timestamp}');
      print('DEBUG: 🕐 HORA ACTUAL ENVÍO: ${DateTime.now()}');
      print('DEBUG: ⏱️  DIFERENCIA: ${DateTime.now().difference(ubicacion.timestamp).inSeconds} segundos');
      print('DEBUG: 📦 JSON a enviar: $apiData');
      print('DEBUG: 🔑 Token: ${accessToken.substring(0, 20)}...');

      final response = await http.post(
        Uri.parse(_apiUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: json.encode(apiData),
      ).timeout(const Duration(seconds: 10));

      print('DEBUG: 📡 Respuesta API - Status: ${response.statusCode}');

      if (response.statusCode == 201 || response.statusCode == 200) {
        print('DEBUG: ✅ Ubicación enviada a API exitosamente');
        print('DEBUG: 📝 Respuesta: ${response.body}');

        // Verificar que la fecha se guardó correctamente en el servidor
        try {
          final responseData = json.decode(response.body);
          final fechaServidor = responseData['fecha'];
          print('DEBUG: ✅ Fecha en servidor: $fechaServidor');
        } catch (e) {
          print('DEBUG: ⚠️ No se pudo verificar fecha en respuesta del servidor');
        }

        // Si se envió exitosamente, marcar como sincronizada
        if (ubicacion.id != null) {
          await _databaseService!.marcarUbicacionSincronizada(ubicacion.id!);
        }
      } else {
        print('DEBUG: ❌ Error API: ${response.statusCode}');
        print('DEBUG: 📝 Body: ${response.body}');

        if (response.statusCode == 404) {
          throw Exception('Endpoint no encontrado (404). Verifica la URL: $_apiUrl');
        } else {
          throw Exception('Error API: ${response.statusCode} - ${response.body}');
        }
      }
    } catch (e) {
      print('ERROR enviando ubicación a API: $e');
      rethrow;
    }
  }

// NUEVO: Método mejorado para sincronización
  Future<void> _sincronizarUbicacionesPendientes(String accessToken) async {
    try {
      if (_databaseService == null) {
        throw Exception('DatabaseService no inicializado');
      }

      final ubicacionesPendientes = await _databaseService!.obtenerUbicacionesPendientes();
      print('DEBUG: 🔄 Sincronizando ${ubicacionesPendientes.length} ubicaciones pendientes');

      for (final ubicacion in ubicacionesPendientes) {
        try {
          // VERIFICAR que cada ubicación mantiene su hora original
          print('DEBUG: 🔄 Sincronizando ubicación ID: ${ubicacion.id}');
          print('DEBUG: 🕐 Hora original captura: ${ubicacion.timestamp}');
          print('DEBUG: ⏱️  Tiempo desde captura: ${DateTime.now().difference(ubicacion.timestamp).inMinutes} minutos');

          await _enviarUbicacionApi(ubicacion, accessToken);
          await _databaseService!.marcarUbicacionSincronizada(ubicacion.id!);
          print('DEBUG: ✅ Ubicación ${ubicacion.id} sincronizada exitosamente');
        } catch (e) {
          print('ERROR sincronizando ubicación ${ubicacion.id}: $e');
          // Continuar con la siguiente en lugar de detener todo
          continue;
        }
      }

      if (ubicacionesPendientes.isNotEmpty) {
        print('DEBUG: ✅ Sincronización completada - ${ubicacionesPendientes.length} ubicaciones procesadas');
      }
    } catch (e) {
      print('ERROR en sincronización general: $e');
    }
  }

  // AGREGA este método a tu UbicacionService para debugging
  Future<void> verificarEstadoUbicaciones() async {
    try {
      if (_databaseService == null) return;

      final stats = await _databaseService!.obtenerEstadisticasUbicaciones();
      final ubicacionesPendientes = await _databaseService!.obtenerUbicacionesPendientes();

      print('DEBUG: 📊 ESTADÍSTICAS DE UBICACIONES');
      print('DEBUG: 📊 Total: ${stats['total']}');
      print('DEBUG: 📊 Pendientes: ${stats['pendientes']}');
      print('DEBUG: 📊 Más antigua: ${stats['mas_antigua']}');

      if (ubicacionesPendientes.isNotEmpty) {
        print('DEBUG: 📊 Ubicaciones pendientes:');
        for (final ubicacion in ubicacionesPendientes.take(3)) { // Mostrar solo las 3 primeras
          final diferencia = DateTime.now().difference(ubicacion.timestamp).inMinutes;
          print('DEBUG: 📊 - ID: ${ubicacion.id}, Captura: ${ubicacion.timestamp}, Minutos desde captura: $diferencia');
        }
      }
    } catch (e) {
      print('ERROR verificando estado: $e');
    }
  }
}