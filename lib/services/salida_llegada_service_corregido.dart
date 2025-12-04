import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:http/http.dart' as http;
import 'package:manager_key/config/enviroment.dart';
import 'database_service.dart';
import 'auth_service.dart';

/// Servicio optimizado para manejar Salida y Llegada con sincronización inteligente
class SalidaLlegadaService {
  final DatabaseService _databaseService = DatabaseService();
  final AuthService _authService = AuthService();

  /// ===================================================================
  /// CASO 1: CON INTERNET - Enviar directamente al servidor
  /// ===================================================================
  Future<Map<String, dynamic>> registrarSalidaConEmpadronamiento({
    required String observaciones,
    required int idOperador,
    bool sincronizarConServidor = true,
    required int puntoEmpadronamientoId,
    String? latitud,
    String? longitud,
  }) async {
    try {
      final ahora = DateTime.now();
      final fechaHora = ahora.toIso8601String();
      final fechaHoraFormateada = ahora.toIso8601String().replaceFirst('T', ' ').split('.')[0];

      // ✅ DATOS PARA EL SERVIDOR (camelCase para API)
      final datosServidor = {
        'fechaHora': fechaHoraFormateada,
        'operadorId': idOperador,
        'estado': 'DESPLIEGUE',
        'latitud': latitud ?? '0.0',
        'longitud': longitud ?? '0.0',
        'observaciones': observaciones,
        'sincronizar': 1, // ✅ 1 para API
        'descripcionReporte': null,
        'incidencias': 'Ubicación ${latitud != null ? 'capturada' : 'no capturada'}',
        'centroEmpadronamiento': puntoEmpadronamientoId,
      };

      bool sincronizado = false;
      String mensajeSincronizacion = '';
      Map<String, dynamic>? datosLocal;

      // ✅ VERIFICAR CONEXIÓN A INTERNET
      final connectivityResult = await Connectivity().checkConnectivity();
      final tieneInternet = connectivityResult != ConnectivityResult.none;

      // ✅ CASO 1: CON INTERNET - Enviar directamente al servidor
      if (tieneInternet && sincronizarConServidor) {
        try {
          print('🌐 Intentando enviar directamente al servidor...');
          final token = await _authService.getAccessToken();

          if (token != null && token.isNotEmpty) {
            // Enviar al servidor
            final response = await _enviarRegistroAlServidor(datosServidor, token);

            if (response['success']) {
              sincronizado = true;
              mensajeSincronizacion = '✅ Enviado y sincronizado con servidor';

              // ✅ Guardar también localmente con ID del servidor
              datosLocal = _crearDatosLocal(
                datosServidor: datosServidor,
                fechaHora: fechaHora,
                idServidor: response['id_servidor'],
                sincronizado: true,
                puntoEmpadronamientoId: puntoEmpadronamientoId,
              );

              final idLocal = await _databaseService.insertRegistroConCorreccion(datosLocal!);
              print('📱 También guardado localmente con ID: $idLocal');

              return {
                'exitoso': true,
                'mensaje': '✅ Despliegue registrado y sincronizado exitosamente',
                'idLocal': idLocal,
                'sincronizado': true,
                'modo': 'ONLINE',
              };
            }
          }
        } catch (e) {
          print('⚠️ Error en envío directo: $e - Continuando con guardado local');
        }
      }

      // ✅ CASO 2: SIN INTERNET O FALLÓ ENVÍO - Guardar localmente
      datosLocal = _crearDatosLocal(
        datosServidor: datosServidor,
        fechaHora: fechaHora,
        idServidor: null,
        sincronizado: false,
        puntoEmpadronamientoId: puntoEmpadronamientoId,
      );

      final idLocal = await _databaseService.insertRegistroConCorreccion(datosLocal!);

      if (idLocal == -1) {
        throw Exception('Error al guardar en la base de datos local');
      }

      print('✅ Registro guardado localmente con ID: $idLocal');

      if (tieneInternet) {
        mensajeSincronizacion = sincronizado
            ? '✅ Sincronizado con servidor'
            : '⚠️ Guardado localmente (error en envío)';
      } else {
        mensajeSincronizacion = '📱 Guardado localmente (sin internet)';
      }

      return {
        'exitoso': true,
        'mensaje': 'Despliegue registrado. $mensajeSincronizacion',
        'idLocal': idLocal,
        'sincronizado': sincronizado,
        'modo': tieneInternet ? 'ONLINE_FAILED' : 'OFFLINE',
        'datosServidor': datosServidor,
      };
    } catch (e) {
      print('❌ Error al registrar salida: $e');
      return {
        'exitoso': false,
        'mensaje': 'Error al registrar: ${e.toString()}',
        'sincronizado': false,
        'modo': 'ERROR',
      };
    }
  }

  /// ===================================================================
  /// CASO 3: Sincronización manual desde botón
  /// ===================================================================
  Future<Map<String, dynamic>> sincronizarRegistrosPendientes() async {
    try {
      print('🔄 Iniciando sincronización manual de registros pendientes...');

      // Verificar conexión
      final connectivityResult = await Connectivity().checkConnectivity();
      final tieneInternet = connectivityResult != ConnectivityResult.none;

      if (!tieneInternet) {
        return {
          'success': false,
          'message': '❌ No hay conexión a internet',
          'sincronizados': 0,
          'total': 0,
        };
      }

      // Obtener registros pendientes
      final registrosPendientes = await _databaseService.obtenerRegistrosPendientes();

      if (registrosPendientes.isEmpty) {
        return {
          'success': true,
          'message': '✅ No hay registros pendientes por sincronizar',
          'sincronizados': 0,
          'total': 0,
        };
      }

      print('📤 Sincronizando ${registrosPendientes.length} registros pendientes...');

      final token = await _authService.getAccessToken();
      if (token == null || token.isEmpty) {
        return {
          'success': false,
          'message': '❌ Token de autenticación no disponible',
          'sincronizados': 0,
          'total': registrosPendientes.length,
        };
      }

      int sincronizados = 0;
      int fallidos = 0;

      for (final registro in registrosPendientes) {
        try {
          // ✅ CORRECCIÓN: Crear el mapa para la API explícitamente para asegurar los campos.
          final datosApi = {
            'fechaHora': registro.fechaHora.replaceFirst('T', ' ').split('.')[0],
            'operadorId': registro.operadorId,
            'estado': registro.estado,
            'latitud': registro.latitud,
            'longitud': registro.longitud,
            'observaciones': registro.observaciones ?? '',
            'sincronizar': 1,
            'incidencias': registro.incidencias ?? 'Ubicación capturada',
            'centroEmpadronamiento': registro.centroEmpadronamientoId,
          };

          // Enviar al servidor
          final response = await _enviarRegistroAlServidor(datosApi, token);

          if (response['success']) {
            // Marcar como sincronizado
            await _databaseService.marcarComoSincronizado(
              registro.id!,
              idServidor: response['id_servidor'],
            );
            sincronizados++;
            print('✅ Registro ${registro.id} sincronizado');
          } else {
            fallidos++;
            print('❌ Error sincronizando registro ${registro.id}');

            // Incrementar intentos fallidos
            await _databaseService.incrementarIntentosFallidos(registro.id!);
          }
        } catch (e) {
          fallidos++;
          print('❌ Error sincronizando registro ${registro.id}: $e');
          await _databaseService.incrementarIntentosFallidos(registro.id!);
        }

        // Pequeña pausa para no saturar el servidor
        await Future.delayed(const Duration(milliseconds: 100));
      }

      return {
        'success': sincronizados > 0,
        'message': sincronizados == registrosPendientes.length
            ? '✅ Todos los registros sincronizados exitosamente'
            : '⚠️ Sincronización parcial: $sincronizados exitosos, $fallidos fallidos',
        'sincronizados': sincronizados,
        'fallidos': fallidos,
        'total': registrosPendientes.length,
      };
    } catch (e) {
      print('❌ Error en sincronización masiva: $e');
      return {
        'success': false,
        'message': '❌ Error en sincronización: ${e.toString()}',
        'sincronizados': 0,
        'total': 0,
      };
    }
  }

  /// ===================================================================
  /// MÉTODOS AUXILIARES
  /// ===================================================================

  /// Crear datos para base de datos local (snake_case)
// En MÉTODOS AUXILIARES

  /// Crear datos para base de datos local (snake_case)
  Map<String, dynamic> _crearDatosLocal({
    required Map<String, dynamic> datosServidor,
    required String fechaHora,
    required int? idServidor,
    required bool sincronizado,
    required int puntoEmpadronamientoId, // <--- AÑADIR ESTE PARÁMETRO
  }) {
    final operadorId = datosServidor['operador'] ?? datosServidor['operadorId'];
    final fechaParaGuardar = datosServidor['fechaHora'] as String;

    return {
      'fecha_hora': fechaParaGuardar,
      'operador_id': operadorId,
      'estado': datosServidor['estado'],
      'latitud': datosServidor['latitud'],
      'longitud': datosServidor['longitud'],
      'observaciones': datosServidor['observaciones'],
      'sincronizar': 1,
      'descripcion_reporte': datosServidor['descripcionReporte'],
      'incidencias': datosServidor['incidencias'],
      // ✅ CORRECCIÓN DEFINITIVA: Usar el parámetro directamente
      'centro_empadronamiento_id': puntoEmpadronamientoId,
      'sincronizado': sincronizado ? 1 : 0,
      'fecha_sincronizacion': sincronizado ? DateTime.now().toIso8601String() : null,
      'id_servidor': idServidor,
      'fecha_creacion_local': fechaHora,
      'intentos': 0,
      'ultimo_intento': null,
      'created_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    };
  }


  /// Enviar registro al servidor
  Future<Map<String, dynamic>> _enviarRegistroAlServidor(
      Map<String, dynamic> datos, String token) async {
    try {
      Map<String, dynamic> datosCorregidos = Map<String, dynamic>.from(datos);

      if (datosCorregidos.containsKey('operadorId')) {
        datosCorregidos['operador'] = datosCorregidos['operadorId'];
        datosCorregidos.remove('operadorId');
      }

      if (datosCorregidos.containsKey('centroEmpadronamiento')) {
        datosCorregidos['centro_empadronamiento'] = datosCorregidos.remove('centroEmpadronamiento');
      }

      if (datosCorregidos.containsKey('fechaHora')) {
        datosCorregidos['fecha_hora'] = datosCorregidos['fechaHora'];
        datosCorregidos.remove('fechaHora');
      }

      final url = Uri.parse('${Enviroment.apiUrlDev}registrosdespliegue/');
      print('📤 Enviando a API: $url');
      print('📦 Datos corregidos para envío: ${jsonEncode(datosCorregidos)}');

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(datosCorregidos),
      ).timeout(const Duration(seconds: 30));

      print('📥 Respuesta API - Status: ${response.statusCode}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = jsonDecode(response.body);
        final idServidor = responseData['id'] ?? responseData['registrodespliegue_id'];

        print('✅ Enviado exitosamente. ID Servidor: $idServidor');
        print('📥 Respuesta completa: ${response.body}');

        return {
          'success': true,
          'id_servidor': idServidor,
        };
      } else {
        print('❌ Error API ${response.statusCode}: ${response.body}');
        return {
          'success': false,
          'error': 'Error de API: ${response.statusCode}',
          'body': response.body,
        };
      }
    } catch (e) {
      print('❌ Error en _enviarRegistroAlServidor: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// Obtener estadísticas de sincronización
  Future<Map<String, dynamic>> obtenerEstadisticasSincronizacion() async {
    try {
      return await _databaseService.obtenerEstadisticasDespliegue();
    } catch (e) {
      print('❌ Error obteniendo estadísticas: $e');
      return {
        'total': 0,
        'sincronizados': 0,
        'pendientes': 0,
        'fallidos': 0,
        'porcentaje': 0,
      };
    }
  }

  // En lib/services/salida_llegada_service_corregido.dart

  /// ===================================================================
  /// REGISTRAR LLEGADA (Online/Offline)
  /// ===================================================================
  // En lib/services/salida_llegada_service.dart

// ... (después del método registrarSalidaConEmpadronamiento)

  /// ===================================================================
  /// REGISTRAR LLEGADA (Online/Offline)
  /// ===================================================================
  Future<Map<String, dynamic>> registrarLlegadaConEmpadronamiento({
    required String observaciones,
    required int idOperador,
    bool sincronizarConServidor = true,
    required int puntoEmpadronamientoId,
    String? latitud,
    String? longitud,
  }) async {
    try {
      final ahora = DateTime.now();
      final fechaHora = ahora.toIso8601String();
      final fechaHoraFormateada = ahora.toIso8601String().replaceFirst('T', ' ').split('.')[0];

      // ✅ DATOS PARA EL SERVIDOR (con estado 'LLEGADA')
      final datosServidor = {
        'fechaHora': fechaHoraFormateada,
        'operadorId': idOperador,
        'estado': 'LLEGADA', // <--- CAMBIO CLAVE AQUÍ
        'latitud': latitud ?? '0.0',
        'longitud': longitud ?? '0.0',
        'observaciones': observaciones,
        'sincronizar': 1,
        'descripcionReporte': null,
        'incidencias': 'Llegada - Ubicación ${latitud != null ? 'capturada' : 'no capturada'}',
        'centroEmpadronamiento': puntoEmpadronamientoId,
      };

      // La lógica de aquí en adelante es idéntica a la de registrarSalida.
      // Reutilizamos toda la infraestructura de conexión y guardado.

      final connectivityResult = await Connectivity().checkConnectivity();
      final tieneInternet = connectivityResult != ConnectivityResult.none;

      // CASO 1: CON INTERNET - Enviar directamente al servidor
      if (tieneInternet && sincronizarConServidor) {
        try {
          print('🌐 Intentando enviar LLEGADA directamente al servidor...');
          final token = await _authService.getAccessToken();

          if (token != null && token.isNotEmpty) {
            final response = await _enviarRegistroAlServidor(datosServidor, token);

            if (response['success']) {
              final datosLocal = _crearDatosLocal(
                datosServidor: datosServidor,
                fechaHora: fechaHora,
                idServidor: response['id_servidor'],
                sincronizado: true,
                puntoEmpadronamientoId: puntoEmpadronamientoId,
              );
              final idLocal = await _databaseService.insertRegistroConCorreccion(datosLocal);
              print('📱 Llegada también guardada localmente con ID: $idLocal');

              return {
                'exitoso': true,
                'mensaje': '✅ Llegada registrada y sincronizada exitosamente',
                'idLocal': idLocal,
                'sincronizado': true,
                'modo': 'ONLINE',
              };
            }
          }
        } catch (e) {
          print('⚠️ Error en envío directo de LLEGADA: $e - Continuando con guardado local');
        }
      }

      // CASO 2: SIN INTERNET O FALLÓ ENVÍO - Guardar localmente
      final datosLocal = _crearDatosLocal(
        datosServidor: datosServidor,
        fechaHora: fechaHora,
        idServidor: null,
        sincronizado: false,
        puntoEmpadronamientoId: puntoEmpadronamientoId,
      );

      final idLocal = await _databaseService.insertRegistroConCorreccion(datosLocal);

      if (idLocal == -1) {
        throw Exception('Error al guardar LLEGADA en la base de datos local');
      }

      print('✅ Llegada guardada localmente con ID: $idLocal');

      String mensajeSincronizacion = tieneInternet
          ? '⚠️ Guardado localmente (error en envío)'
          : '📱 Guardado localmente (sin internet)';

      return {
        'exitoso': true,
        'mensaje': 'Llegada registrada. $mensajeSincronizacion',
        'idLocal': idLocal,
        'sincronizado': false,
        'modo': tieneInternet ? 'ONLINE_FAILED' : 'OFFLINE',
      };
    } catch (e) {
      print('❌ Error al registrar llegada: $e');
      return {
        'exitoso': false,
        'mensaje': 'Error al registrar llegada: ${e.toString()}',
        'sincronizado': false,
        'modo': 'ERROR',
      };
    }
  }


}
