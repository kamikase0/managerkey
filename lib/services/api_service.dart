// lib/services/api_service.dart (ACTUALIZADO)
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../config/enviroment.dart';
import '../models/registro_despliegue_model.dart';

class ApiService {
  static final String _baseUrl = Enviroment.apiUrl;
  static final String _registrosEndpoint = 'registrosdespliegue/';
  static final String _reportesEndpoint = 'reportesdiarios/';

  String get registrosEndpoint => '$_baseUrl$_registrosEndpoint';
  String get reportesEndpoint => '$_baseUrl$_reportesEndpoint';

  /// =============================
  /// 📊 Enviar Reporte Diario
  /// =============================
  Future<Map<String, dynamic>> enviarReporteDiario(
      Map<String, dynamic> reporte, {
        required String accessToken,
      }) async {
    final url = Uri.parse(reportesEndpoint);

    try {
      final body = jsonEncode(reporte);

      print('🔔 Enviando POST → $url');
      print('🧾 Body: $body');

      final response = await http
          .post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: body,
      )
          .timeout(
        const Duration(seconds: 20),
        onTimeout: () => http.Response('Timeout', 408),
      );

      print('✅ Response status: ${response.statusCode}');
      print('📥 Response body: ${response.body}');

      if (response.statusCode == 201 || response.statusCode == 200) {
        return {
          'success': true,
          'message': 'Reporte enviado exitosamente',
          'data': jsonDecode(response.body),
        };
      } else {
        return {
          'success': false,
          'message': 'Error al enviar reporte: ${response.statusCode}',
          'error': response.body,
        };
      }
    } catch (e) {
      print('❌ Excepción al enviar reporte: $e');
      return {
        'success': false,
        'message': 'Error de conexión: $e',
      };
    }
  }

  /// =============================
  /// 📤 Enviar un registro al servidor (EXISTENTE)
  /// =============================
  Future<bool> enviarRegistroDespliegue(RegistroDespliegue registro) async {
    final url = Uri.parse(registrosEndpoint);

    try {
      final body = jsonEncode(registro.toJson());

      print('🔔 Enviando POST → $url');
      print('🧾 Body: $body');

      final response = await http
          .post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: body,
      )
          .timeout(
        const Duration(seconds: 20),
        onTimeout: () => http.Response('Timeout', 408),
      );

      print('✅ Response status: ${response.statusCode}');
      print('📥 Response body: ${response.body}');

      if (response.statusCode == 201 || response.statusCode == 200) {
        return true;
      } else {
        print('⚠️ Error al enviar (${response.statusCode}): ${response.body}');
        return false;
      }
    } catch (e) {
      print('❌ Excepción al enviar registro: $e');
      return false;
    }
  }

  /// =============================
  /// 📥 Obtener todos los registros del servidor (EXISTENTE)
  /// =============================
  Future<List<RegistroDespliegue>> obtenerRegistros() async {
    final url = Uri.parse(registrosEndpoint);

    try {
      print('🔔 Solicitando registros desde: $url');

      final response = await http
          .get(
        url,
        headers: {
          'Accept': 'application/json',
        },
      )
          .timeout(
        const Duration(seconds: 20),
        onTimeout: () => http.Response('Timeout', 408),
      );

      print('Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data
            .map((json) => RegistroDespliegue.fromJson(json))
            .toList();
      } else {
        print('⚠️ Error al obtener registros: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('❌ Excepción al obtener registros: $e');
      return [];
    }
  }

  /// =============================
  /// ✏️ Actualizar un registro existente (EXISTENTE)
  /// =============================
  Future<bool> actualizarRegistroDespliegue(RegistroDespliegue registro) async {
    if (registro.id == null) {
      print('⚠️ Error: El registro no tiene ID para actualizar');
      return false;
    }

    final url = Uri.parse('$registrosEndpoint${registro.id}/');

    try {
      final body = jsonEncode(registro.toJson());

      print('🔔 Enviando PUT → $url');
      print('🧾 Body: $body');

      final response = await http
          .put(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: body,
      )
          .timeout(
        const Duration(seconds: 20),
        onTimeout: () => http.Response('Timeout', 408),
      );

      print('✅ Response status: ${response.statusCode}');
      print('📥 Response body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        return true;
      } else {
        print('⚠️ Error al actualizar (${response.statusCode}): ${response.body}');
        return false;
      }
    } catch (e) {
      print('❌ Excepción al actualizar registro: $e');
      return false;
    }
  }
}