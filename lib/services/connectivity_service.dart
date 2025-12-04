import 'package:connectivity_plus/connectivity_plus.dart';

/// Servicio que maneja la conectividad de red
class ConnectivityService {
  final Connectivity _connectivity = Connectivity();

  /// Stream de cambios de conectividad
  Stream<ConnectivityResult> get connectivityStream {
    return _connectivity.onConnectivityChanged;
  }

  /// Verificar conexión actual
  Future<bool> hasInternetConnection() async {
    try {
      final result = await _connectivity.checkConnectivity();
      return result != ConnectivityResult.none;
    } catch (e) {
      print('❌ Error verificando conectividad: $e');
      return false;
    }
  }

  /// Inicializar el servicio (opcional, puede dejarse vacío)
  void initialize() {
    print('✅ ConnectivityService inicializado');
  }

  /// Obtener estado actual de conectividad
  Future<ConnectivityResult> getConnectivityStatus() async {
    try {
      return await _connectivity.checkConnectivity();
    } catch (e) {
      print('❌ Error obteniendo estado de conectividad: $e');
      return ConnectivityResult.none;
    }
  }
}


// // services/connectivity_service.dart
// import 'dart:async';
// import 'dart:io';
// import 'package:connectivity_plus/connectivity_plus.dart';
//
// class ConnectivityService {
//   static final ConnectivityService _instance = ConnectivityService._internal();
//
//   factory ConnectivityService() => _instance;
//
//   ConnectivityService._internal();
//
//   final Connectivity _connectivity = Connectivity();
//
//   // Future<bool> hasInternetConnection() async {
//   //   try {
//   //     final connectivityResult = await _connectivity.checkConnectivity();
//   //     print('🔍 Connectivity result: $connectivityResult');
//   //
//   //     if (connectivityResult == ConnectivityResult.none) {
//   //       print('📱 No hay conexión de red detectada');
//   //       return false;
//   //     }
//   //
//   //     // Verificar si realmente podemos alcanzar un servidor
//   //     print('🌐 Verificando conexión a internet real...');
//   //     final result = await InternetAddress.lookup('google.com')
//   //         .timeout(const Duration(seconds: 5));
//   //
//   //     final hasConnection = result.isNotEmpty && result[0].rawAddress.isNotEmpty;
//   //     print('✅ Conexión a internet: $hasConnection');
//   //     return hasConnection;
//   //
//   //   } on SocketException catch (_) {
//   //     print('❌ SocketException: No se pudo conectar a internet');
//   //     return false;
//   //   } on TimeoutException catch (_) {
//   //     print('⏰ Timeout: La verificación de conexión tardó demasiado');
//   //     return false;
//   //   } catch (e) {
//   //     print('🚨 Error inesperado en verificación de conexión: $e');
//   //     return false;
//   //   }
//   // }
//
//   Future<bool> hasInternetConnection() async {
//     try {
//       final connectivityResult = await _connectivity.checkConnectivity();
//       print('🔍 Connectivity result: $connectivityResult');
//
//       if (connectivityResult == ConnectivityResult.none) {
//         print('📱 No hay conexión de red detectada');
//         return false;
//       }
//
//       // Verificar si realmente podemos alcanzar un servidor
//       print('🌐 Verificando conexión a internet real...');
//       final result = await InternetAddress.lookup('google.com')
//           .timeout(const Duration(seconds: 5));
//
//       final hasConnection = result.isNotEmpty && result[0].rawAddress.isNotEmpty;
//       print('✅ Conexión a internet: $hasConnection');
//       return hasConnection;
//
//     } on SocketException catch (_) {
//       print('❌ SocketException: No se pudo conectar a internet');
//       return false;
//     } on TimeoutException catch (_) {
//       print('⏰ Timeout: La verificación de conexión tardó demasiado');
//       return false;
//     } catch (e) {
//       print('🚨 Error inesperado en verificación de conexión: $e');
//       return false;
//     }
//   }
//
//   Stream<ConnectivityResult> get connectivityStream {
//     return _connectivity.onConnectivityChanged;
//   }
// }