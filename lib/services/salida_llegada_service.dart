import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:http/http.dart' as http;
import 'package:manager_key/config/enviroment.dart';
import 'database_service.dart';
import 'auth_service.dart';

///
/// Servicio optimizado para manejar Salida y Llegada con una lógica "Online-First".
/// 1. Si hay internet, envía el registro directamente al servidor.
/// 2. Si no hay internet (o el envío falla), guarda el registro en la base de datos local.
///
class SalidaLlegadaService {
  final DatabaseService _databaseService = DatabaseService();
  final AuthService _authService = AuthService();

  /// ===================================================================
  /// MÉTODOS PÚBLICOS
  /// ===================================================================

  /// Registra una SALIDA de ruta.
  Future<Map<String, dynamic>> registrarSalidaConEmpadronamiento({
    required String observaciones,
    required int idOperador,
    required int puntoEmpadronamientoId,
    String? latitud,
    String? longitud,
  }) {
    // Llama al método unificado con el estado 'DESPLIEGUE'
    return _registrarMovimiento(
      estado: 'DESPLIEGUE',
      observaciones: observaciones,
      idOperador: idOperador,
      puntoEmpadronamientoId: puntoEmpadronamientoId,
      latitud: latitud,
      longitud: longitud,
    );
  }

  /// Registra una LLEGADA de ruta.
  Future<Map<String, dynamic>> registrarLlegadaConEmpadronamiento({
    required String observaciones,
    required int idOperador,
    required int puntoEmpadronamientoId,
    String? latitud,
    String? longitud,
    required bool sincronizarConServidor,
  }) {
    // Llama al método unificado con el estado 'LLEGADA'
    return _registrarMovimiento(
      estado: 'LLEGADA',
      observaciones: observaciones,
      idOperador: idOperador,
      puntoEmpadronamientoId: puntoEmpadronamientoId,
      latitud: latitud,
      longitud: longitud,
    );
  }

  /// ===================================================================
  /// LÓGICA CENTRAL UNIFICADA
  /// ===================================================================

  ///
  /// Método privado que centraliza el registro de cualquier movimiento (Salida o Llegada).
  /// Sigue una estrategia "Online-First".
  ///
  Future<Map<String, dynamic>> _registrarMovimiento({
    required String estado,
    required String observaciones,
    required int idOperador,
    required int puntoEmpadronamientoId,
    String? latitud,
    String? longitud,
  }) async {
    try {
      final ahora = DateTime.now();
      final fechaHoraIso = ahora.toIso8601String();
      final fechaHoraFormateada = fechaHoraIso.replaceFirst('T', ' ').split('.')[0];
      final latitudSegura = latitud ?? '0.0';
      final longitudSegura = longitud ?? '0.0';

      // 1. VERIFICAR CONECTIVIDAD
      final connectivityResult = await Connectivity().checkConnectivity();
      final tieneInternet = connectivityResult != ConnectivityResult.none;

      // 2. CASO ONLINE: Si hay internet, intentar enviar directamente al servidor.
      if (tieneInternet) {
        print('🌐 Modo ONLINE. Intentando enviar registro de $estado...');
        try {
          final token = await _authService.getAccessToken();
          if (token != null && token.isNotEmpty) {
            // Prepara los datos para la API en el formato que espera el backend
            final datosParaApi = {
              'fecha_hora': fechaHoraFormateada,
              'operador_id': idOperador,
              'estado': estado,
              'latitud': latitudSegura,
              'longitud': longitudSegura,
              'observaciones': observaciones,
              'sincronizar': true,
              'descripcion_reporte': null,
              'incidencias': 'Ubicación ${latitud != null ? "capturada" : "no capturada"}',
              'centro_empadronamiento_id': puntoEmpadronamientoId,
            };

            final response = await _enviarRegistroAlServidor(datosParaApi, token);

            if (response['success']) {
              print('✅ Éxito: $estado registrado y sincronizado directamente.');
              return {
                'exitoso': true,
                'mensaje': 'Registro de $estado enviado y sincronizado correctamente.',
                'sincronizado': true,
              };
            }
          }
        } catch (e) {
          print('⚠️ Falló el envío directo de $estado. Se guardará localmente. Error: $e');
          // Si el envío falla, el código continúa y ejecuta el bloque de guardado local
        }
      }

      // 3. CASO OFFLINE (o si el envío online falló): Guardar en la base de datos local.
      print('📱 Modo OFFLINE. Guardando registro de $estado localmente...');

      // ✅ CORRECCIÓN: Usar el getter 'database' en lugar de acceder directamente
      final db = await _databaseService.database;

      // Prepara los datos para la base de datos local (snake_case)
      final datosParaDbLocal = {
        'fecha_hora': fechaHoraFormateada,
        'operador_id': idOperador,
        'estado': estado,
        'latitud': latitudSegura,
        'longitud': longitudSegura,
        'observaciones': observaciones,
        'sincronizar': 1,
        'descripcion_reporte': null,
        'incidencias': 'Ubicación ${latitud != null ? "capturada" : "no capturada"}',
        'centro_empadronamiento_id': puntoEmpadronamientoId,
        'sincronizado': 0,
        'fecha_sincronizacion': null,
        'id_servidor': null,
        'fecha_creacion_local': fechaHoraIso,
        'intentos': 0,
        'ultimo_intento': null,
      };

      final idLocal = await db.insert('registros_despliegue', datosParaDbLocal);

      if (idLocal == -1) {
        throw Exception('Error Crítico: No se pudo guardar el registro en la base de datos local.');
      }

      print('✅ Registro de $estado guardado en DB local con ID: $idLocal.');
      return {
        'exitoso': true,
        'mensaje': 'Registro de $estado guardado localmente. Se sincronizará cuando haya conexión.',
        'sincronizado': false,
      };

    } catch (e) {
      print('❌ Error fatal en _registrarMovimiento: $e');
      return {
        'exitoso': false,
        'mensaje': 'Ocurrió un error inesperado al registrar el movimiento: ${e.toString()}',
        'sincronizado': false,
      };
    }
  }

  /// ===================================================================
  /// MÉTODOS DE SOPORTE Y SINCRONIZACIÓN
  /// ===================================================================

  /// Envía un registro al servidor.
  Future<Map<String, dynamic>> _enviarRegistroAlServidor(Map<String, dynamic> datos, String token) async {
    try {
      final url = Uri.parse('${Enviroment.apiUrlDev}registrodespliegue/');
      print('📤 Enviando a API: $url con datos: ${jsonEncode(datos)}');

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(datos),
      ).timeout(const Duration(seconds: 20));

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = jsonDecode(response.body);
        final idServidor = responseData['id'] ?? responseData['registrodespliegue_id'];
        return {'success': true, 'id_servidor': idServidor};
      } else {
        print('❌ Error de API ${response.statusCode}: ${response.body}');
        return {'success': false, 'error': 'Error de API: ${response.statusCode}'};
      }
    } catch (e) {
      print('❌ Error de red en _enviarRegistroAlServidor: $e');
      throw Exception('Error de red o timeout: $e');
    }
  }

  /// Sincroniza todos los registros pendientes guardados en la base de datos local.
  Future<Map<String, dynamic>> sincronizarRegistrosPendientes() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult == ConnectivityResult.none) {
      return {'success': false, 'message': 'No hay conexión a internet para sincronizar.'};
    }

    try {
      // ✅ CORRECCIÓN: Usar el getter 'database'
      final db = await _databaseService.database;

      final registrosPendientes = await db.query(
        'registros_despliegue',
        where: 'sincronizado = 0 AND intentos < 5',
        orderBy: 'fecha_creacion_local ASC',
      );

      if (registrosPendientes.isEmpty) {
        return {'success': true, 'message': '✅ No hay registros pendientes por sincronizar.'};
      }

      print('🔄 Sincronizando ${registrosPendientes.length} registros pendientes...');
      final token = await _authService.getAccessToken();
      if (token == null || token.isEmpty) {
        return {'success': false, 'message': 'Token de autenticación no disponible.'};
      }

      int sincronizados = 0;
      int fallidos = 0;

      for (final registro in registrosPendientes) {
        try {
          final datosParaApi = Map<String, dynamic>.from(registro);
          datosParaApi.remove('id');
          datosParaApi.remove('sincronizado');
          datosParaApi.remove('intentos');

          final response = await _enviarRegistroAlServidor(datosParaApi, token);

          if (response['success']) {
            await db.update(
              'registros_despliegue',
              {'sincronizado': 1, 'id_servidor': response['id_servidor']},
              where: 'id = ?',
              whereArgs: [registro['id']],
            );
            sincronizados++;
          } else {
            fallidos++;
            await db.rawUpdate(
              'UPDATE registros_despliegue SET intentos = intentos + 1 WHERE id = ?',
              [registro['id']],
            );
          }
        } catch (e) {
          fallidos++;
          await db.rawUpdate(
            'UPDATE registros_despliegue SET intentos = intentos + 1 WHERE id = ?',
            [registro['id']],
          );
          print('❌ Error sincronizando registro ${registro['id']}: $e');
        }
      }

      return {
        'success': fallidos == 0,
        'message': 'Sincronización completada: $sincronizados exitosos, $fallidos fallidos.',
      };
    } catch (e) {
      print('❌ Error fatal en sincronización masiva: $e');
      return {'success': false, 'message': 'Error en el proceso de sincronización: ${e.toString()}'};
    }
  }

  /// Obtiene estadísticas de sincronización desde la base de datos local.
  Future<Map<String, dynamic>> obtenerEstadisticasSincronizacion() async {
    try {
      // ✅ CORRECCIÓN: Usar el getter 'database'
      final db = await _databaseService.database;

      final total = (await db.rawQuery('SELECT COUNT(*) FROM registros_despliegue')).first.values.first as int? ?? 0;
      final sincronizados = (await db.rawQuery('SELECT COUNT(*) FROM registros_despliegue WHERE sincronizado = 1')).first.values.first as int? ?? 0;
      final pendientes = total - sincronizados;
      final porcentaje = total > 0 ? (sincronizados * 100 / total).round() : 0;

      return {
        'total': total,
        'sincronizados': sincronizados,
        'pendientes': pendientes,
        'porcentaje': porcentaje,
      };
    } catch (e) {
      print('❌ Error obteniendo estadísticas: $e');
      return {'total': 0, 'sincronizados': 0, 'pendientes': 0, 'porcentaje': 0};
    }
  }
}