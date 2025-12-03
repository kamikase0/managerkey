import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:http/http.dart' as http;
import '../config/enviroment.dart';
import '../services/api_service.dart';
import '../services/database_service.dart';
import '../models/registro_despliegue_model.dart';
import 'auth_service.dart';

class SyncService {
  static final SyncService _instance = SyncService._internal();
  static bool _isSyncing = false;
  static DateTime? _lastSyncAttempt;

  // Instancia de Connectivity
  final Connectivity _connectivity = Connectivity();

  factory SyncService() {
    return _instance;
  }

  SyncService._internal();

  /// Verificar si hay conexión a internet
  /// Compatible con todas las versiones de connectivity_plus
  Future<bool> verificarConexion() async {
    try {
      final result = await _connectivity.checkConnectivity();

      // PARA connectivity_plus 5.0.0+ (devuelve ConnectivityResult enum)
      if (result is ConnectivityResult) {
        return result == ConnectivityResult.mobile ||
            result == ConnectivityResult.wifi ||
            result == ConnectivityResult.ethernet ||
            result == ConnectivityResult.vpn;
      }

      // PARA versiones anteriores (mantener por compatibilidad)
      return result == ConnectivityResult.mobile ||
          result == ConnectivityResult.wifi;
    } catch (e) {
      print('Error verificando conexión: $e');
      return false;
    }
  }

  /// Método original (mantener para compatibilidad)
  Future<void> sincronizarRegistrosPendientes() async {
    if (_isSyncing) {
      print('⏳ Sincronización ya en progreso...');
      return;
    }

    _isSyncing = true;
    try {
      final tieneInternet = await verificarConexion();
      if (!tieneInternet) {
        print('❌ Sin conexión a internet');
        return;
      }

      final db = DatabaseService();
      final registrosPendientes = await db.obtenerNoSincronizados();

      if (registrosPendientes.isEmpty) {
        print('✅ No hay registros pendientes');
        return;
      }

      print('📤 Sincronizando ${registrosPendientes.length} registros...');

      // Obtener el token una sola vez
      final accessToken = await _obtenerAccessToken();
      if (accessToken.isEmpty) {
        print('❌ No se pudo obtener access token');
        return;
      }

      final apiService = ApiService(accessToken: accessToken);

      for (var registro in registrosPendientes) {
        try {
          final registroMap = registro.toApiMap();
          final enviado = await apiService.enviarRegistroDespliegue(registroMap);

          if (enviado) {
            await db.marcarComoSincronizado(registro.id!);
            print('✅ Registro ${registro.id} sincronizado');
          } else {
            print('⚠️ Error al enviar registro ${registro.id}');
          }
        } catch (e) {
          print('❌ Error en registro ${registro.id}: $e');
        }
      }

      _lastSyncAttempt = DateTime.now();
    } finally {
      _isSyncing = false;
    }
  }

  /// ✅ Método para sincronizar registro específico
  // Future<Map<String, dynamic>> sincronizarRegistro(RegistroDespliegue registro) async {
  //   try {
  //     // 1. Obtener token de autenticación
  //     final authService = AuthService();
  //     final token = await authService.getAccessToken();
  //
  //     if (token == null || token.isEmpty) {
  //       return {'success': false, 'message': 'No hay token de autenticación'};
  //     }
  //
  //     // 2. Preparar datos para la API
  //     final Map<String, dynamic> datosApi = registro.toJsonForApi();
  //
  //     // 3. Enviar al servidor
  //     final url = '${Enviroment.apiUrlDev}registrosdespliegue/';
  //     print('📤 Sincronizando registro a: $url');
  //
  //     final response = await http.post(
  //       Uri.parse(url),
  //       headers: {
  //         'Content-Type': 'application/json',
  //         'Authorization': 'Bearer $token',
  //       },
  //       body: jsonEncode(datosApi),
  //     ).timeout(const Duration(seconds: 30));
  //
  //     print('📥 Respuesta del servidor: ${response.statusCode}');
  //
  //     // 4. Procesar respuesta
  //     if (response.statusCode == 200 || response.statusCode == 201) {
  //       final responseData = jsonDecode(response.body);
  //       print('✅ Registro sincronizado exitosamente: ${responseData['id']}');
  //
  //       return {
  //         'success': true,
  //         'message': 'Registro sincronizado exitosamente',
  //         'server_id': responseData['id'],
  //       };
  //     } else {
  //       print('❌ Error del servidor: ${response.body}');
  //       return {
  //         'success': false,
  //         'message': 'Error del servidor: ${response.statusCode}',
  //       };
  //     }
  //   } catch (e) {
  //     print('❌ Error en sincronizarRegistro: $e');
  //     return {
  //       'success': false,
  //       'message': 'Error de conexión: ${e.toString()}',
  //     };
  //   }
  // }

  /// ✅ Método para sincronizar todos los registros pendientes
  Future<Map<String, dynamic>> sincronizarTodosRegistrosPendientes() async {
    try {
      final dbService = DatabaseService();
      final registrosPendientes = await dbService.obtenerRegistrosDesplieguePendientes();

      print('📊 Registros pendientes para sincronizar: ${registrosPendientes.length}');

      if (registrosPendientes.isEmpty) {
        return {
          'success': true,
          'message': 'No hay registros pendientes para sincronizar',
          'sincronizados': 0,
        };
      }

      int sincronizadosExitosos = 0;
      int sincronizadosFallidos = 0;

      // Verificar conexión primero
      final tieneConexion = await verificarConexion();
      if (!tieneConexion) {
        return {
          'success': false,
          'message': 'No hay conexión a internet',
          'sincronizados': 0,
        };
      }

      // Sincronizar cada registro
      for (var registro in registrosPendientes) {
        try {
          final resultado = await sincronizarRegistro(registro);

          if (resultado['success'] == true) {
            // Marcar como sincronizado en la base local
            await dbService.marcarComoSincronizado(registro.id!);
            sincronizadosExitosos++;

            print('✅ Registro ${registro.id} sincronizado exitosamente');
          } else {
            sincronizadosFallidos++;
            print('❌ Falló sincronización del registro ${registro.id}');
          }
        } catch (e) {
          sincronizadosFallidos++;
          print('❌ Error sincronizando registro ${registro.id}: $e');
        }
      }

      return {
        'success': sincronizadosFallidos == 0,
        'message': sincronizadosFallidos == 0
            ? '✅ Todos los registros sincronizados exitosamente'
            : '⚠️ Sincronización parcial: $sincronizadosExitosos exitosos, $sincronizadosFallidos fallidos',
        'sincronizados': sincronizadosExitosos,
        'fallidos': sincronizadosFallidos,
      };

    } catch (e) {
      print('❌ Error en sincronizarTodosRegistrosPendientes: $e');
      return {
        'success': false,
        'message': 'Error general: ${e.toString()}',
        'sincronizados': 0,
      };
    }
  }

  /// ✅ Método específico para llegadas pendientes
  Future<Map<String, dynamic>> sincronizarLlegadasPendientes() async {
    try {
      final dbService = DatabaseService();
      final llegadasPendientes = await dbService.obtenerLlegadasPendientes();

      print('📊 Llegadas pendientes para sincronizar: ${llegadasPendientes.length}');

      if (llegadasPendientes.isEmpty) {
        return {
          'success': true,
          'message': 'No hay llegadas pendientes para sincronizar',
          'sincronizadas': 0,
        };
      }

      int sincronizadasExitosas = 0;
      int sincronizadasFallidas = 0;

      // Verificar conexión primero
      final tieneConexion = await verificarConexion();
      if (!tieneConexion) {
        return {
          'success': false,
          'message': 'No hay conexión a internet',
          'sincronizadas': 0,
        };
      }

      // Sincronizar cada llegada
      for (var llegada in llegadasPendientes) {
        try {
          final resultado = await sincronizarRegistro(llegada);

          if (resultado['success'] == true) {
            await dbService.marcarComoSincronizado(llegada.id!);
            sincronizadasExitosas++;
            print('✅ Llegada ${llegada.id} sincronizada exitosamente');
          } else {
            sincronizadasFallidas++;
            print('❌ Falló sincronización de la llegada ${llegada.id}');
          }
        } catch (e) {
          sincronizadasFallidas++;
          print('❌ Error sincronizando llegada ${llegada.id}: $e');
        }
      }

      return {
        'success': sincronizadasFallidas == 0,
        'message': sincronizadasFallidas == 0
            ? '✅ Todas las llegadas sincronizadas exitosamente'
            : '⚠️ Sincronización parcial de llegadas: $sincronizadasExitosas exitosas, $sincronizadasFallidas fallidas',
        'sincronizadas': sincronizadasExitosas,
        'fallidas': sincronizadasFallidas,
      };

    } catch (e) {
      print('❌ Error en sincronizarLlegadasPendientes: $e');
      return {
        'success': false,
        'message': 'Error general: ${e.toString()}',
        'sincronizadas': 0,
      };
    }
  }

  /// ✅ Método específico para salidas pendientes
  Future<Map<String, dynamic>> sincronizarSalidasPendientes() async {
    try {
      final dbService = DatabaseService();
      final salidasPendientes = await dbService.obtenerSalidasPendientes();

      print('📊 Salidas pendientes para sincronizar: ${salidasPendientes.length}');

      if (salidasPendientes.isEmpty) {
        return {
          'success': true,
          'message': 'No hay salidas pendientes para sincronizar',
          'sincronizadas': 0,
        };
      }

      int sincronizadasExitosas = 0;
      int sincronizadasFallidas = 0;

      // Verificar conexión primero
      final tieneConexion = await verificarConexion();
      if (!tieneConexion) {
        return {
          'success': false,
          'message': 'No hay conexión a internet',
          'sincronizadas': 0,
        };
      }

      // Sincronizar cada salida
      for (var salida in salidasPendientes) {
        try {
          final resultado = await sincronizarRegistro(salida);

          if (resultado['success'] == true) {
            await dbService.marcarComoSincronizado(salida.id!);
            sincronizadasExitosas++;
            print('✅ Salida ${salida.id} sincronizada exitosamente');
          } else {
            sincronizadasFallidas++;
            print('❌ Falló sincronización de la salida ${salida.id}');
          }
        } catch (e) {
          sincronizadasFallidas++;
          print('❌ Error sincronizando salida ${salida.id}: $e');
        }
      }

      return {
        'success': sincronizadasFallidas == 0,
        'message': sincronizadasFallidas == 0
            ? '✅ Todas las salidas sincronizadas exitosamente'
            : '⚠️ Sincronización parcial de salidas: $sincronizadasExitosas exitosas, $sincronizadasFallidas fallidas',
        'sincronizadas': sincronizadasExitosas,
        'fallidas': sincronizadasFallidas,
      };

    } catch (e) {
      print('❌ Error en sincronizarSalidasPendientes: $e');
      return {
        'success': false,
        'message': 'Error general: ${e.toString()}',
        'sincronizadas': 0,
      };
    }
  }

  /// ✅ Método para obtener estadísticas de sincronización
  Future<Map<String, dynamic>> obtenerEstadisticasSincronizacion() async {
    try {
      final dbService = DatabaseService();
      final registrosPendientes = await dbService.obtenerRegistrosDesplieguePendientes();
      final registrosSincronizados = await dbService.obtenerRegistrosDespliegueSincronizados();

      final total = registrosPendientes.length + registrosSincronizados.length;
      final pendientes = registrosPendientes.length;
      final sincronizados = registrosSincronizados.length;
      final porcentaje = total > 0 ? (sincronizados / total * 100).round() : 0;

      return {
        'total': total,
        'pendientes': pendientes,
        'sincronizados': sincronizados,
        'porcentaje': porcentaje,
      };
    } catch (e) {
      print('❌ Error obteniendo estadísticas: $e');
      return {
        'total': 0,
        'pendientes': 0,
        'sincronizados': 0,
        'porcentaje': 0,
      };
    }
  }

  /// ✅ Obtener accessToken desde AuthService
  Future<String> _obtenerAccessToken() async {
    try {
      final authService = AuthService();
      final token = await authService.getAccessToken();
      return token ?? '';
    } catch (e) {
      print('Error obteniendo access token: $e');
      return '';
    }
  }

  // En SyncService.dart - Modifica el método sincronizarRegistro
  // En SyncService.dart - Modifica el método sincronizarRegistro

  Future<Map<String, dynamic>> sincronizarRegistro(RegistroDespliegue registro) async {
    try {
      // 1. Obtener token de autenticación
      final authService = AuthService();
      final token = await authService.getAccessToken();

      if (token == null || token.isEmpty) {
        return {'success': false, 'message': 'No hay token de autenticación'};
      }

      // ✅ CORRECCIÓN: Usar toApiMap() en lugar de toJsonForApi()
      final Map<String, dynamic> datosApi = registro.toApiMap();

      // 3. Enviar al servidor
      final url = '${Enviroment.apiUrlDev}registrosdespliegue/';
      print('📤 Sincronizando registro a: $url');

      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(datosApi), // ✅ Ya es un Map, lo convertimos a JSON
      ).timeout(const Duration(seconds: 30));

      print('📥 Respuesta del servidor: ${response.statusCode}');

      // 4. Procesar respuesta
      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = jsonDecode(response.body);
        print('✅ Registro sincronizado exitosamente: ${responseData['id']}');

        return {
          'success': true,
          'message': 'Registro sincronizado exitosamente',
          'server_id': responseData['id'],
        };
      } else {
        print('❌ Error del servidor: ${response.body}');
        return {
          'success': false,
          'message': 'Error del servidor: ${response.statusCode}',
        };
      }
    } catch (e) {
      print('❌ Error en sincronizarRegistro: $e');
      return {
        'success': false,
        'message': 'Error de conexión: ${e.toString()}',
      };
    }
  }

  /// Obtener última fecha de intento de sincronización
  DateTime? getLastSyncAttempt() => _lastSyncAttempt;

  /// Verificar si está sincronizando
  bool isSyncing() => _isSyncing;
}