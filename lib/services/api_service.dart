// lib/services/api_service.dart (CORREGIDO)
import 'dart:async';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import '../config/enviroment.dart';
import '../models/registro_despliegue_model.dart';
import 'auth_service.dart';

typedef ApiRequest = Future<http.Response> Function(String token);

class ApiService {
  final AuthService? _authService;
  final String? _accessToken;

  // ✅ SOPORTE PARA DOS MODOS: Con AuthService (completo) o solo con token (simple)
  ApiService({AuthService? authService, String? accessToken})
      : _authService = authService,
        _accessToken = accessToken {
    if (authService == null && accessToken == null) {
      throw ArgumentError('Se debe proporcionar authService o accessToken');
    }
  }

  static final String _baseUrl = Enviroment.apiUrl;
  static final String _registrosEndpoint = 'registrosdespliegue/';
  static final String _reportesEndpoint = 'reportesdiarios/';

  String get registrosEndpoint => '$_baseUrl$_registrosEndpoint';
  String get reportesEndpoint => '$_baseUrl$_reportesEndpoint';

  // ✅ GETTER PARA ACCESO TOKEN
  String? get accessToken => _accessToken;

  // ✅ GETTER PARA ACCESO TOKEN SEGURO
  Future<String?> _getAccessToken() async {
    if (_accessToken != null) return _accessToken;
    return await _authService?.getAccessToken();
  }

  /// ====================================================================
  /// 🧠 INTERCEPTOR / WRAPPER DE PETICIONES (MODO COMPLETO)
  /// ====================================================================
  Future<http.Response> _makeAuthenticatedRequest(ApiRequest request) async {
    try {
      // ✅ Si tenemos accessToken directo, usarlo sin refresh
      if (_accessToken != null) {
        return await request(_accessToken!);
      }

      // ✅ Modo completo con AuthService
      String? accessToken = await _authService!.getAccessToken();
      if (accessToken == null) {
        print('❌ No hay token de acceso. Forzando logout.');
        await _authService!.logout();
        return http.Response(jsonEncode({'error': 'No-authenticated'}), 401);
      }

      var response = await request(accessToken);

      if (response.statusCode == 401) {
        print('⚠️ Token expirado (401). Intentando refrescar...');
        final bool refreshed = await _authService!.refreshToken();

        if (refreshed) {
          print('✅ Token refrescado. Reintentando la petición original...');
          String? newAccessToken = await _authService!.getAccessToken();
          if (newAccessToken != null) {
            response = await request(newAccessToken);
          }
        } else {
          print('❌ El refresco del token falló. El usuario debe re-autenticarse.');
        }
      }

      return response;
    } catch (e) {
      print('❌ Error en _makeAuthenticatedRequest: $e');
      return http.Response(jsonEncode({'error': 'Connection failed: $e'}), 500);
    }
  }

  /// =============================
  /// 📊 Obtener Reportes Diarios - MÉTODO MEJORADO
  /// =============================
  Future<List<Map<String, dynamic>>> obtenerReportesDiarios() async {
    final url = Uri.parse(reportesEndpoint);

    try {
      final response = await _makeAuthenticatedRequest((token) {
        print('🔔 Solicitando reportes diarios desde: $url');
        return http.get(
          url,
          headers: {
            'Accept': 'application/json',
            'Authorization': 'Bearer $token',
          },
        ).timeout(const Duration(seconds: 20));
      });

      print('✅ Response status final: ${response.statusCode}');
      print('📥 Response body sample: ${response.body.length > 100 ? response.body.substring(0, 100) + '...' : response.body}');

      if (response.statusCode == 200) {
        try {
          final decodedBody = utf8.decode(response.bodyBytes);
          final dynamic data = jsonDecode(decodedBody);

          // ✅ MANEJO DE DIFERENTES FORMATOS DE RESPUESTA
          if (data is List) {
            return data.map((item) {
              if (item is Map<String, dynamic>) {
                return item;
              } else if (item is Map) {
                return Map<String, dynamic>.from(item);
              } else {
                return <String, dynamic>{'raw_data': item};
              }
            }).toList();
          } else if (data is Map) {
            // Si la API devuelve un objeto con una propiedad que contiene la lista
            final mapData = Map<String, dynamic>.from(data);
            for (var key in mapData.keys) {
              if (mapData[key] is List) {
                return (mapData[key] as List).map((item) {
                  if (item is Map<String, dynamic>) {
                    return item;
                  } else if (item is Map) {
                    return Map<String, dynamic>.from(item);
                  } else {
                    return <String, dynamic>{'raw_data': item};
                  }
                }).toList();
              }
            }
            // Si no encuentra una lista, devolver el mapa como único elemento
            return [mapData];
          } else {
            print('⚠️ Formato de respuesta inesperado: ${data.runtimeType}');
            return [];
          }
        } catch (e) {
          print('❌ Error decodificando JSON: $e');
          return [];
        }
      } else {
        print('⚠️ Error al obtener reportes diarios: ${response.statusCode}');
        print('📄 Response body: ${response.body}');
        return [];
      }
    } catch (e) {
      print('❌ Excepción al obtener reportes diarios: $e');
      return [];
    }
  }

  /// =============================
  /// 📊 Enviar Reporte Diario - MÉTODO MEJORADO
  /// =============================
  Future<Map<String, dynamic>> enviarReporteDiario(Map<String, dynamic> reporte) async {
    final url = Uri.parse(reportesEndpoint);

    // ✅ LIMPIAR DATOS ANTES DE ENVIAR
    final cleanedReporte = Map<String, dynamic>.from(reporte)
      ..removeWhere((key, value) => value == null);

    final body = jsonEncode(cleanedReporte);

    try {
      final response = await _makeAuthenticatedRequest((token) {
        print('🔔 Enviando POST → $url');
        print('🧾 Body: $body');
        return http.post(
          url,
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: body,
        ).timeout(const Duration(seconds: 20));
      });

      print('✅ Response status final: ${response.statusCode}');
      print('📥 Response body: ${response.body}');

      if (response.statusCode == 201 || response.statusCode == 200) {
        try {
          final responseData = jsonDecode(utf8.decode(response.bodyBytes));
          return {
            'success': true,
            'message': 'Reporte enviado exitosamente',
            'data': responseData,
          };
        } catch (e) {
          return {
            'success': true,
            'message': 'Reporte enviado exitosamente (respuesta no JSON)',
            'data': {'raw_response': response.body},
          };
        }
      } else {
        final errorBody = utf8.decode(response.bodyBytes);
        return {
          'success': false,
          'message': 'Error al enviar reporte: ${response.statusCode}',
          'error': errorBody,
          'statusCode': response.statusCode,
        };
      }
    } catch (e) {
      print('❌ Excepción al enviar reporte: $e');
      return {
        'success': false,
        'message': 'Error de conexión: $e'
      };
    }
  }

  /// =============================
  /// 📤 Enviar Registro Despliegue - MÉTODO MEJORADO
  /// =============================
  Future<bool> enviarRegistroDespliegue(Map<String, dynamic> data) async {
    final url = Uri.parse(registrosEndpoint);

    // ✅ LIMPIAR DATOS ANTES DE ENVIAR
    final cleanedData = Map<String, dynamic>.from(data)
      ..removeWhere((key, value) => value == null);

    final body = jsonEncode(cleanedData);

    try {
      final response = await _makeAuthenticatedRequest((token) {
        print('🔔 Enviando registro de despliegue a: $url');
        print('🧾 Datos: $body');
        return http.post(
          url,
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: body,
        ).timeout(const Duration(seconds: 20));
      });

      print('✅ Response status final: ${response.statusCode}');
      print('📥 Response body: ${response.body}');

      // ✅ MÁS FLEXIBLE EN LAS RESPUESTAS EXITOSAS
      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (e) {
      print('❌ Error de conexión al enviar registro: $e');
      return false;
    }
  }

  /// =============================
  /// 📥 Obtener Registros Despliegue - MÉTODO MEJORADO
  /// =============================
  Future<List<RegistroDespliegue>> obtenerRegistros() async {
    final url = Uri.parse(registrosEndpoint);

    try {
      final response = await _makeAuthenticatedRequest((token) {
        print('🔔 Solicitando registros desde: $url');
        return http.get(
          url,
          headers: {
            'Accept': 'application/json',
            'Authorization': 'Bearer $token',
          },
        ).timeout(const Duration(seconds: 20));
      });

      print('Response status final: ${response.statusCode}');

      if (response.statusCode == 200) {
        try {
          final List<dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
          return data.map((json) {
            try {
              return RegistroDespliegue.fromJson(json);
            } catch (e) {
              print('❌ Error mapeando registro: $e');
              // Devolver un registro vacío o manejar el error según necesites
              return RegistroDespliegue(
                destino: 'Error',
                latitud: '0',
                longitud: '0',
                estado: 'ERROR',
                sincronizar: false,
                observaciones: 'Error parsing data',
                incidencias: '',
                fechaHora: DateTime.now().toIso8601String(),
                operadorId: 0,
              );
            }
          }).toList();
        } catch (e) {
          print('❌ Error decodificando JSON de registros: $e');
          return [];
        }
      } else {
        print('⚠️ Error al obtener registros: ${response.statusCode}');
        print('📄 Response body: ${response.body}');
        return [];
      }
    } catch (e) {
      print('❌ Excepción al obtener registros: $e');
      return [];
    }
  }

  /// =============================
  /// 🆕 MÉTODO PARA VERIFICAR CONEXIÓN MEJORADO
  /// =============================
  Future<bool> checkConnection() async {
    try {
      final url = Uri.parse('$_baseUrl/');
      final response = await http.get(url).timeout(const Duration(seconds: 10));
      return response.statusCode == 200;
    } catch (e) {
      print('❌ Error verificando conexión: $e');
      return false;
    }
  }

  /// =============================
  /// 🆕 MÉTODO PARA OBTENER REPORTES POR OPERADOR
  /// =============================
  Future<List<Map<String, dynamic>>> obtenerReportesPorOperador(int operadorId) async {
    try {
      final todosReportes = await obtenerReportesDiarios();
      return todosReportes.where((reporte) {
        final reporteOperadorId = reporte['operador'];
        return reporteOperadorId == operadorId;
      }).toList();
    } catch (e) {
      print('❌ Error obteniendo reportes por operador: $e');
      return [];
    }
  }

  /// =============================
  /// 📥 Obtener todos los registros de despliegue del servidor - CORREGIDO
  /// GET http://34.176.50.193:8001/api/registrosdespliegue/
  /// =============================
  Future<List<Map<String, dynamic>>> obtenerRegistrosDespliegue() async {
    try {
      final token = await _getAccessToken();
      if (token == null) {
        throw Exception('No hay token de autenticación disponible');
      }

      final url = Uri.parse('http://34.176.50.193:8001/api/registrosdespliegue/');

      print('📡 GET $url');

      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw Exception('Timeout al obtener registros'),
      );

      print('📊 Status: ${response.statusCode}');
      print('📋 Response body length: ${response.body.length}');

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);

        // Si la respuesta es un objeto con lista dentro
        if (jsonResponse is Map && jsonResponse.containsKey('results')) {
          final results = jsonResponse['results'] as List;
          return results.cast<Map<String, dynamic>>();
        }

        // Si la respuesta es una lista directa
        if (jsonResponse is List) {
          return jsonResponse.cast<Map<String, dynamic>>();
        }

        print('⚠️ Formato de respuesta inesperado');
        return [];
      } else if (response.statusCode == 401) {
        print('❌ Token expirado o inválido');
        throw Exception('Token expirado. Por favor, vuelva a iniciar sesión');
      } else if (response.statusCode == 403) {
        print('❌ Acceso prohibido');
        throw Exception('No tienes permiso para acceder a estos registros');
      } else {
        print('❌ Error HTTP ${response.statusCode}: ${response.body}');
        throw Exception('Error al obtener registros: ${response.statusCode}');
      }
    } on SocketException {
      print('❌ Error de conexión');
      throw Exception('Error de conexión. Verifica tu conexión a internet');
    } on TimeoutException {
      print('❌ Timeout');
      throw Exception('La solicitud tardó demasiado. Intenta de nuevo');
    } catch (e) {
      print('❌ Error inesperado: $e');
      rethrow;
    }
  }

  /// =============================
  /// 📥 Obtener registros de despliegue de un operador específico - CORREGIDO
  /// GET http://34.176.50.193:8001/api/registrosdespliegue/?operador=ID
  /// =============================
  Future<List<Map<String, dynamic>>> obtenerRegistrosDespliegueDelOperador(int idOperador) async {
    try {
      final token = await _getAccessToken();
      if (token == null) {
        throw Exception('No hay token de autenticación disponible');
      }

      final url = Uri.parse('http://34.176.50.193:8001/api/registrosdespliegue/?operador=$idOperador');

      print('📡 GET $url');

      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw Exception('Timeout al obtener registros'),
      );

      print('📊 Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);

        if (jsonResponse is Map && jsonResponse.containsKey('results')) {
          final results = jsonResponse['results'] as List;
          return results.cast<Map<String, dynamic>>();
        }

        if (jsonResponse is List) {
          return jsonResponse.cast<Map<String, dynamic>>();
        }

        print('⚠️ Formato de respuesta inesperado');
        return [];
      } else if (response.statusCode == 401) {
        print('❌ Token expirado');
        throw Exception('Token expirado. Por favor, vuelva a iniciar sesión');
      } else if (response.statusCode == 403) {
        print('❌ Acceso prohibido');
        throw Exception('No tienes permiso para acceder a estos registros');
      } else {
        print('❌ Error HTTP ${response.statusCode}');
        throw Exception('Error al obtener registros: ${response.statusCode}');
      }
    } on SocketException {
      print('❌ Error de conexión');
      throw Exception('Error de conexión. Verifica tu conexión a internet');
    } on TimeoutException {
      print('❌ Timeout');
      throw Exception('La solicitud tardó demasiado. Intenta de nuevo');
    } catch (e) {
      print('❌ Error: $e');
      rethrow;
    }
  }
}