// lib/services/api_service.dart (CORREGIDO)
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../config/enviroment.dart';
import '../models/registro_despliegue_model.dart';

class ApiService {
  final String accessToken;
  static final String _baseUrl = Enviroment.apiUrl;
  static final String _registrosEndpoint = 'registrosdespliegue/';
  static final String _reportesEndpoint = 'reportesdiarios/';

  String get registrosEndpoint => '$_baseUrl$_registrosEndpoint';
  String get reportesEndpoint => '$_baseUrl$_reportesEndpoint';

  ApiService({required this.accessToken});

  //Obtener Reportes Diarios
  //Obtener Reportes Diarios
  Future<List<Map<String, dynamic>>> obtenerReportesDiarios() async {
    final url = Uri.parse(reportesEndpoint);

    try{
      print('🔔 Obteniendo reportes desde: $url');
      final response = await http
          .get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
      )
          .timeout(
        const Duration(seconds: 20),
        onTimeout: () => http.Response('Timeout',408),
      );
      print('✅ Response status: ${response.statusCode}');

      if(response.statusCode == 200){
        final List<dynamic> data = jsonDecode(response.body);
        final reportes = data.map((json){
          return Map<String, dynamic>.from(json as Map);
        }).toList();

        print(' Reportes obtenidos: ${reportes.length}');
        return reportes;
      }else{
        print('⚠️ Error al obtener reportes: ${response.statusCode}');
        return [];
      }
    }catch(e){
      print('❌ Excepción al obtener reportes: $e');
      return [];
    }
  }
  /// =============================
  /// 📊 Enviar Reporte Diario
  /// =============================
  Future<Map<String, dynamic>> enviarReporteDiario(Map<String, dynamic> reporte) async {
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
  /// 📤 Enviar un registro al servidor (CORREGIDO)
  /// =============================
  // Future<Map<String, dynamic>> enviarRegistroDespliegue(Map<String, dynamic> data) async {
  //   try {
  //     final url = Uri.parse(registrosEndpoint);
  //
  //     print('🔔 Enviando registro de despliegue a: $url');
  //
  //     final response = await http.post(
  //       url,
  //       headers: {
  //         'Content-Type': 'application/json',
  //         'Authorization': 'Bearer $accessToken',
  //       },
  //       body: jsonEncode(data),
  //     );
  //
  //     print('✅ Response status: ${response.statusCode}');
  //     print('📥 Response body: ${response.body}');
  //
  //     if (response.statusCode == 200 || response.statusCode == 201) {
  //       return {
  //         'success': true,
  //         'message': 'Registro de despliegue enviado exitosamente',
  //         'data': jsonDecode(response.body),
  //       };
  //     } else {
  //       return {
  //         'success': false,
  //         'message': 'Error ${response.statusCode}: ${response.body}',
  //       };
  //     }
  //   } catch (e) {
  //     return {
  //       'success': false,
  //       'message': 'Error de conexión: $e',
  //     };
  //   }
  // }

  Future<bool> enviarRegistroDespliegue(Map<String, dynamic> data) async {
    try {
      final url = Uri.parse(registrosEndpoint);

      print('🔔 Enviando registro de despliegue a: $url');

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: jsonEncode(data),
      );

      print('✅ Response status: ${response.statusCode}');
      print('📥 Response body: ${response.body}');

      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      print('❌ Error de conexión al enviar registro: $e');
      return false;
    }
  }

  /// =============================
  /// 📥 Obtener todos los registros del servidor (CORREGIDO)
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
          'Authorization': 'Bearer $accessToken', // Añadido Authorization
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
  /// ✏️ Actualizar un registro existente (CORREGIDO)
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
          'Authorization': 'Bearer $accessToken', // Añadido Authorization
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