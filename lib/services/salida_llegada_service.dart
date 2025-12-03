import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:http/http.dart' as http;
import 'package:manager_key/config/enviroment.dart';
import '../models/registro_despliegue_model.dart';
import 'database_service.dart';
import 'auth_service.dart';

/// Servicio integrado para manejar Salida y Llegada con sincronización inteligente
class SalidaLlegadaService {
  final DatabaseService _databaseService = DatabaseService();
  final AuthService _authService = AuthService();

  /// ===================================================================
  /// MÉTODOS PÚBLICOS PRINCIPALES
  /// ===================================================================

  /// Método específico para registrar SALIDA
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

      // Datos para la base de datos local
      final datosLocal = _mapearParaLocal({
        'latitud': latitud ?? '0.0',
        'longitud': longitud ?? '0.0',
        'descripcion_reporte': null,
        'estado': 'DESPLIEGUE',
        'observaciones': observaciones,
        'incidencias': 'Ubicación ${latitud != null ? 'capturada' : 'no capturada'}',
        'fecha_hora': fechaHora,
        'operador_id': idOperador,
        'puntoEmpadronamientoId': puntoEmpadronamientoId,
        'centro_empadronamiento_id': puntoEmpadronamientoId,
      });

      // 1. Guardar en base de datos local
      final db = await DatabaseService().database;
      final idLocal = await db.insert('registros_despliegue', datosLocal);

      print('✅ Registro guardado localmente con ID: $idLocal');

      // Datos para el servidor
      final datosServidor = {
        'fecha_hora': fechaHoraFormateada,
        'operador_id': idOperador,
        'estado': 'DESPLIEGUE',
        'latitud': latitud ?? '0.0',
        'longitud': longitud ?? '0.0',
        'observaciones': observaciones,
        'sincronizar': true,
        'descripcion_reporte': null,
        'incidencias': 'Ubicación ${latitud != null ? 'capturada' : 'no capturada'}',
        'centro_empadronamiento_id': puntoEmpadronamientoId,
      };

      bool sincronizado = false;
      String mensajeSincronizacion = '';

      // En registrarSalidaConEmpadronamiento, antes de insertar:
      print('🔍 DEBUG - Datos a insertar en BD:');
      print('  - Operador ID: $idOperador');
      print('  - Punto Empadronamiento ID: $puntoEmpadronamientoId');
      print('  - DatosLocal keys: ${datosLocal.keys.toList()}');

// Verificar si tiene campos camelCase
      if (datosLocal.containsKey('operadorId')) {
        print('⚠️ ADVERTENCIA: datosLocal contiene operadorId (camelCase)');
        // Remover campo camelCase
        datosLocal.remove('operadorId');
        datosLocal['operador_id'] = idOperador;
      }

      if (datosLocal.containsKey('centroEmpadronamiento')) {
        print('⚠️ ADVERTENCIA: datosLocal contiene centroEmpadronamiento (camelCase)');
        datosLocal.remove('centroEmpadronamiento');
        datosLocal['centro_empadronamiento_id'] = puntoEmpadronamientoId;
      }

      print('✅ Datos corregidos: ${datosLocal.keys.toList()}');

      // 2. Intentar sincronizar con servidor si hay conexión
      if (sincronizarConServidor) {
        try {
          final connectivityResult = await Connectivity().checkConnectivity();
          if (connectivityResult != ConnectivityResult.none) {
            print('🌐 Intentando sincronizar con servidor...');

            final token = await _authService.getAccessToken();

            if (token != null) {
              final response = await _enviarRegistroAlServidorDirecto(datosServidor, token);

              if (response['success']) {
                sincronizado = true;
                mensajeSincronizacion = 'Sincronizado con servidor';

                // Actualizar registro local con ID del servidor
                final idServidor = response['id_servidor'];
                await db.update(
                  'registros_despliegue',
                  {
                    'sincronizado': 1,
                    'id_servidor': idServidor,
                    'fecha_sincronizacion': DateTime.now().toIso8601String(),
                  },
                  where: 'id = ?',
                  whereArgs: [idLocal],
                );

                print('✅ Registro sincronizado con servidor. ID Servidor: $idServidor');
              } else {
                mensajeSincronizacion = 'Error del servidor: ${response['error']}';
              }
            } else {
              mensajeSincronizacion = 'Token no disponible';
            }
          } else {
            mensajeSincronizacion = 'Sin conexión a internet - Guardado localmente';
          }
        } catch (e) {
          print('⚠️ Error en sincronización: $e');
          mensajeSincronizacion = 'Error de sincronización: ${e.toString()}';

          // Incrementar intentos
          final currentIntents = (await db.query(
            'registros_despliegue',
            columns: ['intentos'],
            where: 'id = ?',
            whereArgs: [idLocal],
          ))
              .first['intentos'] as int? ??
              0;

          await db.update(
            'registros_despliegue',
            {
              'intentos': currentIntents + 1,
              'ultimo_intento': DateTime.now().toIso8601String(),
            },
            where: 'id = ?',
            whereArgs: [idLocal],
          );
        }
      }

      return {
        'exitoso': true,
        'mensaje': 'Despliegue registrado exitosamente. $mensajeSincronizacion',
        'idLocal': idLocal,
        'sincronizado': sincronizado,
        'datosServidor': datosServidor,
      };
    } catch (e) {
      print('❌ Error al registrar salida: $e');
      return {
        'exitoso': false,
        'mensaje': 'Error al registrar: ${e.toString()}',
        'sincronizado': false,
      };
    }
  }

  /// Método específico para registrar LLEGADA
  Future<Map<String, dynamic>> registrarLlegadaConEmpadronamiento({
    required String observaciones,
    required int idOperador,
    required int puntoEmpadronamientoId,
    String? latitud,
    String? longitud,
    required bool sincronizarConServidor,
  }) async {
    return _registrarDespliegue(
      estado: 'LLEGADA',
      observaciones: observaciones,
      idOperador: idOperador,
      puntoEmpadronamientoId: puntoEmpadronamientoId,
      latitud: latitud,
      longitud: longitud,
      sincronizarConServidor: sincronizarConServidor,
    );
  }

  /// Método privado unificado para registrar Salida y Llegada
  Future<Map<String, dynamic>> _registrarDespliegue({
    required String estado,
    required String observaciones,
    required int idOperador,
    required int puntoEmpadronamientoId,
    String? latitud,
    String? longitud,
    bool sincronizarConServidor = true,
  }) async {
    try {
      print('🚀 Preparando registro de $estado...');

      // ✅ CORRECCIÓN: Usar variables correctamente definidas
      final latitudString = latitud ?? '0.0';
      final longitudString = longitud ?? '0.0';
      final incidencias = 'Ubicación ${latitud != null ? 'capturada' : 'no capturada'}';

      // 1. Crear el objeto del registro usando el factory createNew
      final registro = RegistroDespliegue.createNew(
        fechaHora: DateTime.now().toIso8601String(),
        operadorId: idOperador, // ✅ Usar idOperador en lugar de operadorId
        estado: estado,
        latitud: latitudString,
        longitud: longitudString,
        observaciones: observaciones,
        incidencias: incidencias,
        centroEmpadronamiento: puntoEmpadronamientoId, // ✅ Usar puntoEmpadronamientoId
      );

      print('📋 Registro creado: ${registro.toMap()}');

      // 2. Guardar en la base de datos local
      final localId = await _databaseService.insertRegistroDespliegue(registro);
      if (localId == -1) {
        throw Exception('Error al insertar en la base de datos local');
      }
      print('✅ Registro de $estado guardado localmente con ID: $localId');

      // 3. Intentar sincronizar si hay conexión
      if (sincronizarConServidor) {
        final connectivityResult = await Connectivity().checkConnectivity();
        if (connectivityResult != ConnectivityResult.none) {
          final token = await _authService.getAccessToken();
          if (token != null && token.isNotEmpty) {
            final datosParaAPI = {
              'fecha_hora': registro.fechaHora,
              'operador_id': registro.operadorId,
              'estado': registro.estado,
              'latitud': registro.latitud,
              'longitud': registro.longitud,
              'observaciones': registro.observaciones ?? '',
              'sincronizar': true,
              'descripcion_reporte': registro.descripcionReporte,
              'incidencias': registro.incidencias,
              'centro_empadronamiento_id': registro.centroEmpadronamiento,
            };

            final response = await _enviarRegistroAlServidorDirecto(datosParaAPI, token);
            if (response['success']) {
              await _databaseService.marcarComoSincronizado(localId, idServidor: response['id_servidor']);
              return {
                'exitoso': true,
                'mensaje': '✅ $estado registrado y sincronizado.',
                'id_local': localId,
                'sincronizado': true,
              };
            }
          }
        }
      }

      // 4. Si no hay internet o falló el envío
      return {
        'exitoso': true,
        'mensaje': '💾 $estado guardado localmente. Se sincronizará cuando haya conexión.',
        'id_local': localId,
        'sincronizado': false,
      };
    } catch (e) {
      print('❌ Error al registrar $estado: $e');
      return {
        'exitoso': false,
        'mensaje': 'Error al registrar $estado: ${e.toString()}',
        'id_local': null,
        'sincronizado': false,
      };
    }
  }

  /// Envía un registro al servidor usando http directamente
  Future<Map<String, dynamic>> _enviarRegistroAlServidorDirecto(
      Map<String, dynamic> datos, String token) async {
    try {
      // ✅ CORRECCIÓN: Usar la URL correcta según tu endpoint
      final url = Uri.parse('${Enviroment.apiUrlDev}operaciones/registrodespliegue/');

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(datos),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = jsonDecode(response.body);
        final idServidor = responseData['id'] ?? responseData['registrodespliegue_id'];
        return {'success': true, 'id_servidor': idServidor};
      } else {
        print('Error de API ${response.statusCode}: ${response.body}');
        return {'success': false, 'error': 'Error de API: ${response.statusCode}'};
      }
    } catch (e) {
      print('❌ Error en _enviarRegistroAlServidorDirecto: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Mapea datos locales a formato para servidor
  Map<String, dynamic> _mapearParaServidor(Map<String, dynamic> registroLocal) {
    return {
      'fecha_hora': registroLocal['fecha_hora'],
      'operador_id': registroLocal['operadorId'] ?? registroLocal['operador_id'],
      'estado': registroLocal['estado'],
      'latitud': registroLocal['latitud'],
      'longitud': registroLocal['longitud'],
      'observaciones': registroLocal['observaciones'],
      'sincronizar': registroLocal['sincronizar'] == 1 ? true : false,
      'descripcion_reporte': registroLocal['descripcion_reporte'],
      'incidencias': registroLocal['incidencias'],
      'centro_empadronamiento_id':
      registroLocal['centroEmpadronamiento'] ?? registroLocal['centro_empadronamiento_id'],
    };
  }

  /// Mapea datos para base de datos local
  // Map<String, dynamic> _mapearParaLocal(Map<String, dynamic> datosNuevos,
  //     {bool paraSincronizar = false}) {
  //   final ahora = DateTime.now().toIso8601String();
  //
  //   return {
  //     'latitud': datosNuevos['latitud']?.toString() ?? '0.0',
  //     'longitud': datosNuevos['longitud']?.toString() ?? '0.0',
  //     'descripcion_reporte': datosNuevos['descripcion_reporte'],
  //     'estado': datosNuevos['estado'] ?? 'DESPLIEGUE',
  //     'sincronizar': paraSincronizar ? 1 : 0,
  //     'observaciones': datosNuevos['observaciones'] ?? '',
  //     'incidencias': datosNuevos['incidencias'] ?? '',
  //     'fecha_hora': datosNuevos['fecha_hora'] ?? ahora,
  //     'operadorId': datosNuevos['operador_id'] ?? datosNuevos['idOperador'],
  //     'sincronizado': 0,
  //     'centroEmpadronamiento': datosNuevos['centro_empadronamiento_id'] ??
  //         datosNuevos['puntoEmpadronamientoId'],
  //     'fecha_sincronizacion': null,
  //     'id_servidor': null,
  //     'fecha_creacion_local': ahora,
  //     'intentos': 0,
  //     'ultimo_intento': null,
  //     'operador_id': datosNuevos['operador_id'] ?? datosNuevos['idOperador'],
  //     'centro_empadronamiento_id': datosNuevos['centro_empadronamiento_id'] ??
  //         datosNuevos['puntoEmpadronamientoId'],
  //   };
  // }

  Map<String, dynamic> _mapearParaLocal(Map<String, dynamic> datosNuevos,
      {bool paraSincronizar = false}) {
    final ahora = DateTime.now().toIso8601String();

    // ✅ CORRECCIÓN: Usar solo snake_case y eliminar campos camelCase
    return {
      'latitud': datosNuevos['latitud']?.toString() ?? '0.0',
      'longitud': datosNuevos['longitud']?.toString() ?? '0.0',
      'descripcion_reporte': datosNuevos['descripcion_reporte'],
      'estado': datosNuevos['estado'] ?? 'DESPLIEGUE',
      'sincronizar': paraSincronizar ? 1 : 0,
      'observaciones': datosNuevos['observaciones'] ?? '',
      'incidencias': datosNuevos['incidencias'] ?? '',
      'fecha_hora': datosNuevos['fecha_hora'] ?? ahora,
      // ✅ Solo operador_id (snake_case)
      'operador_id': datosNuevos['operador_id'] ?? datosNuevos['idOperador'],
      'sincronizado': 0,
      // ✅ Solo centro_empadronamiento_id (snake_case)
      'centro_empadronamiento_id': datosNuevos['centro_empadronamiento_id'] ??
          datosNuevos['puntoEmpadronamientoId'],
      'fecha_sincronizacion': null,
      'id_servidor': null,
      'fecha_creacion_local': ahora,
      'intentos': 0,
      'ultimo_intento': null,
      // ❌ NO incluir estos campos camelCase
      // 'operadorId': datosNuevos['operador_id'] ?? datosNuevos['idOperador'],
      // 'centroEmpadronamiento': datosNuevos['centro_empadronamiento_id'] ??
      //     datosNuevos['puntoEmpadronamientoId'],
    };
  }

  /// Obtener estadísticas de sincronización
  Future<Map<String, dynamic>> obtenerEstadisticasSincronizacion() async {
    try {
      final db = await DatabaseService().database;

      // Obtener total de registros
      final totalResult = await db.rawQuery('SELECT COUNT(*) as total FROM registros_despliegue');
      final total = totalResult.first['total'] as int? ?? 0;

      // Obtener registros sincronizados
      final sincronizadosResult = await db
          .rawQuery('SELECT COUNT(*) as sincronizados FROM registros_despliegue WHERE sincronizado = 1');
      final sincronizados = sincronizadosResult.first['sincronizados'] as int? ?? 0;

      // Calcular pendientes
      final pendientes = total - sincronizados;

      // Calcular porcentaje
      final porcentaje = total > 0 ? (sincronizados * 100 / total).round() : 0;

      return {
        'total': total,
        'sincronizados': sincronizados,
        'pendientes': pendientes,
        'porcentaje': porcentaje,
      };
    } catch (e) {
      print('❌ Error obteniendo estadísticas: $e');
      return {
        'total': 0,
        'sincronizados': 0,
        'pendientes': 0,
        'porcentaje': 0,
      };
    }
  }

  /// Sincroniza registros pendientes
  Future<Map<String, dynamic>> sincronizarRegistrosPendientes() async {
    try {
      final db = await DatabaseService().database;

      // Obtener registros pendientes de sincronización
      final registrosPendientes = await db.query(
        'registros_despliegue',
        where: 'sincronizado = 0 AND intentos < 3',
        orderBy: 'fecha_creacion_local ASC',
      );

      if (registrosPendientes.isEmpty) {
        return {
          'success': true,
          'message': 'No hay registros pendientes por sincronizar',
          'sincronizados': 0,
          'total': 0,
        };
      }

      print('🔄 Sincronizando ${registrosPendientes.length} registros pendientes...');

      final token = await _authService.getAccessToken();

      if (token == null) {
        return {
          'success': false,
          'message': 'Token de autenticación no disponible',
          'sincronizados': 0,
          'total': registrosPendientes.length,
        };
      }

      int sincronizados = 0;
      int fallidos = 0;

      for (final registro in registrosPendientes) {
        try {
          // Mapear datos locales a formato del servidor
          final datosServidor = _mapearParaServidor(registro);

          // Enviar al servidor
          final response = await _enviarRegistroAlServidorDirecto(datosServidor, token);

          if (response['success']) {
            // Actualizar registro local como sincronizado
            await db.update(
              'registros_despliegue',
              {
                'sincronizado': 1,
                'id_servidor': response['id_servidor'],
                'fecha_sincronizacion': DateTime.now().toIso8601String(),
                'intentos': 0,
              },
              where: 'id = ?',
              whereArgs: [registro['id']],
            );

            sincronizados++;
            print('✅ Registro ${registro['id']} sincronizado');
          } else {
            fallidos++;
            print('❌ Error sincronizando registro ${registro['id']}: ${response['error']}');

            // Incrementar intentos fallidos
            final intentosActuales = (await db.query(
              'registros_despliegue',
              columns: ['intentos'],
              where: 'id = ?',
              whereArgs: [registro['id']],
            ))
                .first['intentos'] as int? ??
                0;

            await db.update(
              'registros_despliegue',
              {
                'intentos': intentosActuales + 1,
                'ultimo_intento': DateTime.now().toIso8601String(),
              },
              where: 'id = ?',
              whereArgs: [registro['id']],
            );
          }
        } catch (e) {
          fallidos++;
          print('❌ Error sincronizando registro ${registro['id']}: $e');

          // Incrementar intentos fallidos
          final intentosActuales = (await db.query(
            'registros_despliegue',
            columns: ['intentos'],
            where: 'id = ?',
            whereArgs: [registro['id']],
          ))
              .first['intentos'] as int? ??
              0;

          await db.update(
            'registros_despliegue',
            {
              'intentos': intentosActuales + 1,
              'ultimo_intento': DateTime.now().toIso8601String(),
            },
            where: 'id = ?',
            whereArgs: [registro['id']],
          );
        }

        // Pequeña pausa para no saturar el servidor
        await Future.delayed(const Duration(milliseconds: 100));
      }

      return {
        'success': true,
        'message': 'Sincronización completada: $sincronizados registros sincronizados, $fallidos fallidos',
        'sincronizados': sincronizados,
        'fallidos': fallidos,
        'total': registrosPendientes.length,
      };
    } catch (e) {
      print('❌ Error en sincronización masiva: $e');
      return {
        'success': false,
        'message': 'Error en sincronización: ${e.toString()}',
        'sincronizados': 0,
        'total': 0,
      };
    }
  }
}