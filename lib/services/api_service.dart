// import 'dart:convert';
// import 'package:http/http.dart' as http;
// import '../models/registro_despliegue_model.dart';
//
// class ApiService {
//   static const String baseUrl = 'http://34.176.50.193:8000/api/registrosdespliegue/';
//
//   Future<bool> enviarRegistroDespliegue(RegistroDespliegue registro) async {
//     try {
//       final response = await http.post(
//         Uri.parse(baseUrl),
//         headers: {
//           'Content-Type': 'application/json',
//           'Accept': 'application/json',
//         },
//         body: jsonEncode(registro.toJson()),
//       );
//
//       return response.statusCode == 201 || response.statusCode == 200;
//     } catch (e) {
//       print('Error al enviar registro: $e');
//       return false;
//     }
//   }
// }

import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/registro_despliegue_model.dart';

class ApiService {
  static const String baseUrl = 'http://34.176.50.193:8000/api';
  static const String registrosEndpoint = '$baseUrl/registrosdespliegue/';

  /// Enviar un registro de despliegue al servidor
  Future<bool> enviarRegistroDespliegue(RegistroDespliegue registro) async {
    try {
      final url = Uri.parse(registrosEndpoint);

      // Convertir el registro a JSON con los nombres de campos correctos
      final body = jsonEncode(registro.toJson());

      print('Enviando POST a: $url');
      print('Body: $body');

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
        const Duration(seconds: 30),
        onTimeout: () => http.Response('Timeout', 408),
      );

      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 201 || response.statusCode == 200) {
        return true;
      } else if (response.statusCode == 400) {
        print('Error de validación: ${response.body}');
        return false;
      } else {
        print('Error del servidor: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      print('Excepción al enviar registro: $e');
      return false;
    }
  }

  /// Obtener registros del servidor
  Future<List<RegistroDespliegue>> obtenerRegistros() async {
    try {
      final url = Uri.parse(registrosEndpoint);

      final response = await http.get(
        url,
        headers: {
          'Accept': 'application/json',
        },
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () => http.Response('Timeout', 408),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data
            .map((json) => RegistroDespliegue.fromJson(json))
            .toList();
      } else {
        print('Error al obtener registros: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('Excepción al obtener registros: $e');
      return [];
    }
  }

  /// Actualizar un registro en el servidor
  Future<bool> actualizarRegistroDespliegue(
      RegistroDespliegue registro) async {
    try {
      if (registro.id == null) {
        print('Error: El registro no tiene ID');
        return false;
      }

      final url = Uri.parse('$registrosEndpoint${registro.id}/');

      final body = jsonEncode(registro.toJson());

      print('Enviando PUT a: $url');
      print('Body: $body');

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
        const Duration(seconds: 30),
        onTimeout: () => http.Response('Timeout', 408),
      );

      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        return true;
      } else {
        print('Error al actualizar: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      print('Excepción al actualizar registro: $e');
      return false;
    }
  }
}