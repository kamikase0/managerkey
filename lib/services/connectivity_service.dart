// services/connectivity_service.dart
import 'dart:async';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';

class ConnectivityService {
  static final ConnectivityService _instance = ConnectivityService._internal();

  factory ConnectivityService() => _instance;

  ConnectivityService._internal();

  final Connectivity _connectivity = Connectivity();

  Future<bool> hasInternetConnection() async {
    try {
      final connectivityResult = await _connectivity.checkConnectivity();
      print('🔍 Connectivity result: $connectivityResult');

      if (connectivityResult == ConnectivityResult.none) {
        print('📱 No hay conexión de red detectada');
        return false;
      }

      // Verificar si realmente podemos alcanzar un servidor
      print('🌐 Verificando conexión a internet real...');
      final result = await InternetAddress.lookup('google.com')
          .timeout(const Duration(seconds: 5));

      final hasConnection = result.isNotEmpty && result[0].rawAddress.isNotEmpty;
      print('✅ Conexión a internet: $hasConnection');
      return hasConnection;

    } on SocketException catch (_) {
      print('❌ SocketException: No se pudo conectar a internet');
      return false;
    } on TimeoutException catch (_) {
      print('⏰ Timeout: La verificación de conexión tardó demasiado');
      return false;
    } catch (e) {
      print('🚨 Error inesperado en verificación de conexión: $e');
      return false;
    }
  }

  Stream<ConnectivityResult> get connectivityStream {
    return _connectivity.onConnectivityChanged;
  }
}